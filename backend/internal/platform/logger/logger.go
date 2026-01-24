package logger

import (
	"github.com/brightbund-backend/internal/config"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Logger *zap.Logger

// Initialize создает и настраивает глобальный логгер
func Initialize(cfg config.LoggingConfig) error {
	var level zapcore.Level
	if err := level.UnmarshalText([]byte(cfg.Level)); err != nil {
		level = zapcore.InfoLevel
	}

	zapConfig := zap.Config{
		Level:            zap.NewAtomicLevelAt(level),
		Development:      false,
		Encoding:         cfg.Encoding,
		OutputPaths:      cfg.OutputPaths,
		ErrorOutputPaths: cfg.ErrorOutputPaths,
		EncoderConfig: zapcore.EncoderConfig{
			TimeKey:        "timestamp",
			LevelKey:       "level",
			NameKey:        "logger",
			CallerKey:      "caller",
			FunctionKey:    zapcore.OmitKey,
			MessageKey:     "message",
			StacktraceKey:  "stacktrace",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeLevel:    zapcore.LowercaseLevelEncoder,
			EncodeTime:     zapcore.ISO8601TimeEncoder,
			EncodeDuration: zapcore.SecondsDurationEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
		},
	}

	var err error
	Logger, err = zapConfig.Build(zap.AddCallerSkip(1))
	if err != nil {
		return err
	}

	return nil
}

// Get возвращает глобальный логгер
func Get() *zap.Logger {
	if Logger == nil {
		Logger, _ = zap.NewProduction()
	}
	return Logger
}

// Info логирует сообщение уровня info
func Info(msg string, fields ...zap.Field) {
	Get().Info(msg, fields...)
}

// Debug логирует сообщение уровня debug
func Debug(msg string, fields ...zap.Field) {
	Get().Debug(msg, fields...)
}

// Warn логирует сообщение уровня warning
func Warn(msg string, fields ...zap.Field) {
	Get().Warn(msg, fields...)
}

// Error логирует сообщение уровня error
func Error(msg string, fields ...zap.Field) {
	Get().Error(msg, fields...)
}

// Fatal логирует сообщение уровня fatal и завершает программу
func Fatal(msg string, fields ...zap.Field) {
	Get().Fatal(msg, fields...)
}

// Sync синхронизирует буфер логгера
func Sync() error {
	if Logger != nil {
		return Logger.Sync()
	}
	return nil
}
