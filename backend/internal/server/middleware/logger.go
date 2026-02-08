package middleware

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"go.uber.org/zap"
)

// Logger middleware для логирования всех HTTP запросов и ответов
func Logger(logger *zap.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		start := time.Now()

		// Логируем входящий запрос
		logger.Info("incoming_request",
			zap.String("method", c.Method()),
			zap.String("path", c.Path()),
			zap.String("ip", c.IP()),
			zap.String("user_agent", c.Get("User-Agent")),
			zap.String("request_id", c.Locals("requestid").(string)),
		)

		// Выполняем запрос
		err := c.Next()

		// Вычисляем время выполнения
		duration := time.Since(start)

		// Логируем ответ
		fields := []zap.Field{
			zap.String("method", c.Method()),
			zap.String("path", c.Path()),
			zap.Int("status", c.Response().StatusCode()),
			zap.Duration("duration", duration),
			zap.String("ip", c.IP()),
			zap.String("request_id", c.Locals("requestid").(string)),
		}

		// Добавляем информацию об ошибке если есть
		if err != nil {
			fields = append(fields, zap.Error(err))
			logger.Error("request_error", fields...)
		} else {
			// Логируем в зависимости от статуса
			status := c.Response().StatusCode()
			if status >= 500 {
				logger.Error("request_completed_with_server_error", fields...)
			} else if status >= 400 {
				logger.Warn("request_completed_with_client_error", fields...)
			} else {
				logger.Info("request_completed", fields...)
			}
		}

		return err
	}
}
