package economy

import "errors"

var (
	ErrInvalidAmount = errors.New("invalid_amount")
	ErrInvalidCurrency = errors.New("invalid_currency")
	ErrWalletNotFound = errors.New("wallet_not_found")
	ErrInsufficientFunds = errors.New("insufficient_funds")
	ErrSameUser = errors.New("same_user")
	ErrCooldown = errors.New("cooldown_active")
	ErrMonthlyCap = errors.New("monthly_cap_reached")
)