package payment

import "time"

// RevenueCat Product IDs
const (
	ProductStarter   = "starter_pack"
	ProductSupporter = "supporter_pack"
	ProductSponsor   = "sponsor_pack"
	ProductPatron    = "patron_pack"
)

// RevenueCat Event Types
const (
	EventInitialPurchase    = "INITIAL_PURCHASE"
	EventRenewal            = "RENEWAL"
	EventNonRenewingPurchase = "NON_RENEWING_PURCHASE"
	EventExpiration         = "EXPIRATION"
	EventRefund             = "REFUND"
)

// RevenueCatWebhook represents the payload from RevenueCat
// Ref: https://docs.revenuecat.com/docs/webhooks
type RevenueCatWebhook struct {
	Event EventPayload `json:"event"`
}

type EventPayload struct {
	ID                 string    `json:"id"`
	Type               string    `json:"type"`
	AppUserID          string    `json:"app_user_id"`
	ProductID          string    `json:"product_id"`
	EntitlementIDs     []string  `json:"entitlement_ids"`
	Price              float64   `json:"price"`
	Currency           string    `json:"currency"`
	PurchasedAtMs      int64     `json:"purchased_at_ms"`
	ExpirationAtMs     int64     `json:"expiration_at_ms,omitempty"`
	Store              string    `json:"store"`
	Environment        string    `json:"environment"`
	IsRestore          bool      `json:"is_restore"`
}

// GetSealAmount returns the number of Silver Seals for a given product
func GetSealAmount(productID string) int64 {
	switch productID {
	case ProductStarter:
		return 3
	case ProductSupporter:
		return 10
	case ProductSponsor:
		return 30
	case ProductPatron:
		return 120
	default:
		return 0
	}
}

// IsPatronProduct returns true if the product grants Patron status
func IsPatronProduct(productID string) bool {
	return productID == ProductPatron
}
