// Package email provides the outbound email transport for verification
// codes and support notifications. It exposes a single Sender interface
// with two concrete implementations:
//
//   - SMTPSender: real RFC 821 transport over net/smtp, with optional
//     STARTTLS or implicit TLS. Suitable for Gmail/SendGrid/SES SMTP.
//   - LoggingSender: dev fallback that prints messages to the logger
//     so engineers can grab the verification code without a real inbox.
//
// Both auth.EmailSender and settings.EmailSender adapt this interface
// via thin wrappers in cmd/api/main.go to avoid coupling the modules
// directly to the platform package.
package email

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/smtp"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/platform/logger"
	"go.uber.org/zap"
)

// Sender is the canonical email transport interface used inside the
// platform layer.
type Sender interface {
	Send(ctx context.Context, to, subject, body string) error
}

// Config bundles the runtime SMTP options. Mirrors config.SMTPConfig
// so cmd/api/main.go can map directly without leaking yaml tags.
type Config struct {
	Host           string
	Port           int
	Username       string
	Password       string
	FromAddress    string
	FromName       string
	UseStartTLS    bool
	UseImplicitTLS bool
}

// IsConfigured reports whether the supplied config has the minimum
// fields needed to actually deliver mail. Callers use this to decide
// between SMTPSender and LoggingSender.
func (c Config) IsConfigured() bool {
	return strings.TrimSpace(c.Host) != "" && c.Port != 0 && strings.TrimSpace(c.FromAddress) != ""
}

// NewSender returns the SMTP-backed sender if cfg is fully populated,
// otherwise a LoggingSender. Callers don't have to branch — the right
// transport is picked here based on what the operator configured.
func NewSender(cfg Config) Sender {
	if !cfg.IsConfigured() {
		logger.Get().Warn("email transport not configured; falling back to logging stub")
		return &LoggingSender{}
	}
	return &SMTPSender{cfg: cfg}
}

// LoggingSender writes outbound mail to the application logger instead
// of sending it. Used in dev / CI / when SMTP is intentionally absent.
type LoggingSender struct{}

func (s *LoggingSender) Send(ctx context.Context, to, subject, body string) error {
	logger.Get().Info("email_logged",
		zap.String("to", to),
		zap.String("subject", subject),
		zap.String("body", body),
	)
	return nil
}

// SMTPSender delivers via net/smtp. Connection lifetime is per-message
// — appropriate volumes for verification codes / support notifications
// (low rate, low concurrency). For higher throughput swap in a
// connection pool.
type SMTPSender struct {
	cfg Config
}

// Send connects to the SMTP server and delivers a single message.
// Returns an error on any transport-level failure so callers can choose
// to persist the message and retry later (e.g. settings Contact Us).
func (s *SMTPSender) Send(ctx context.Context, to, subject, body string) error {
	if to == "" {
		return errors.New("email: empty recipient")
	}

	addr := fmt.Sprintf("%s:%d", s.cfg.Host, s.cfg.Port)
	dialer := &net.Dialer{Timeout: 15 * time.Second}

	var conn net.Conn
	var err error

	switch {
	case s.cfg.UseImplicitTLS:
		// SMTPS — server expects TLS from the very first byte (Gmail port 465).
		tlsCfg := &tls.Config{ServerName: s.cfg.Host}
		conn, err = tls.DialWithDialer(dialer, "tcp", addr, tlsCfg)
	default:
		conn, err = dialer.DialContext(ctx, "tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("email: dial %s: %w", addr, err)
	}

	client, err := smtp.NewClient(conn, s.cfg.Host)
	if err != nil {
		_ = conn.Close()
		return fmt.Errorf("email: smtp client: %w", err)
	}
	defer func() { _ = client.Close() }()

	// STARTTLS upgrade for plain-port (587) submissions.
	if s.cfg.UseStartTLS && !s.cfg.UseImplicitTLS {
		tlsCfg := &tls.Config{ServerName: s.cfg.Host}
		if err := client.StartTLS(tlsCfg); err != nil {
			return fmt.Errorf("email: starttls: %w", err)
		}
	}

	if s.cfg.Username != "" {
		auth := smtp.PlainAuth("", s.cfg.Username, s.cfg.Password, s.cfg.Host)
		if err := client.Auth(auth); err != nil {
			return fmt.Errorf("email: auth: %w", err)
		}
	}

	if err := client.Mail(s.cfg.FromAddress); err != nil {
		return fmt.Errorf("email: MAIL FROM: %w", err)
	}
	if err := client.Rcpt(to); err != nil {
		return fmt.Errorf("email: RCPT TO: %w", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("email: DATA: %w", err)
	}
	msg := buildMessage(s.cfg.FromAddress, s.cfg.FromName, to, subject, body)
	if _, err := w.Write([]byte(msg)); err != nil {
		_ = w.Close()
		return fmt.Errorf("email: write body: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("email: close DATA: %w", err)
	}

	if err := client.Quit(); err != nil {
		// QUIT failure is non-fatal — server has already accepted the
		// message; log via the returned error chain so callers can
		// observe but don't double-deliver.
		return fmt.Errorf("email: quit: %w", err)
	}
	return nil
}

func buildMessage(fromAddr, fromName, to, subject, body string) string {
	from := fromAddr
	if strings.TrimSpace(fromName) != "" {
		from = fmt.Sprintf("%s <%s>", fromName, fromAddr)
	}
	headers := []string{
		"From: " + from,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"Content-Transfer-Encoding: 8bit",
	}
	return strings.Join(headers, "\r\n") + "\r\n\r\n" + body
}
