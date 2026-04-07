package main

import (
	"context"
	"fmt"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/settings"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		panic(err)
	}
	db, err := sqlx.Connect("postgres", cfg.DBURL)
	if err != nil {
		panic(err)
	}

	repo := settings.NewRepository(db)
	res, err := repo.ListBlockedUsers(context.Background(), "a6683593-a59a-45f4-9ea3-da45ee97e88d", nil, 20)
	if err != nil {
		fmt.Printf("ERROR: %v\n", err)
	} else {
		fmt.Printf("SUCCESS: %+v\n", res)
	}
}