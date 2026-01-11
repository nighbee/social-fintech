package main

import (
	"fmt"
	"log"

	"github.com/gofiber/fiber/v2"
)

func main() {
	app := fiber.New()

	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("running ")
	})

	fmt.Println("Server starting on port 8080...")
	log.Fatal(app.Listen(":8080"))
}
