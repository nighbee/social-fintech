package mapmodule

import "errors"

var (
	ErrInvalidCoordinates = errors.New("invalid coordinates")
	ErrInvalidReward      = errors.New("invalid reward")
	ErrInvalidTitle       = errors.New("invalid title")
)
