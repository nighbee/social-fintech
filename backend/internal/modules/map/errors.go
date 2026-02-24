package mapmodule

import "errors"

var (
	ErrInvalidCoordinates = errors.New("invalid coordinates")
	ErrInvalidReward      = errors.New("invalid reward")
	ErrInvalidTitle       = errors.New("invalid title")
	ErrTaskNotFound       = errors.New("task not found")
	ErrTaskCompleted      = errors.New("task already completed")
	ErrSelfComplete       = errors.New("cannot complete your own task")
)
