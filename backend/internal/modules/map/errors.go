package mapmodule

import (
	"errors"
	"fmt"
	"time"
)

var (
	// Task validation
	ErrInvalidCoordinates = errors.New("invalid coordinates")
	ErrInvalidReward      = errors.New("reward must be 1, 2, or 3 Silver Seals")
	ErrInvalidTitle       = errors.New("invalid title")
	ErrInvalidWorkers     = errors.New("workers_needed must be between 1 and 20")

	// Task lifecycle
	ErrTaskNotFound   = errors.New("task not found")
	ErrTaskCompleted  = errors.New("task already completed")
	ErrTaskCancelled  = errors.New("task is cancelled")
	ErrTaskFull       = errors.New("task already has enough helpers")
	ErrSelfComplete   = errors.New("cannot complete your own task")
	ErrCooldownActive = errors.New("you must wait 7 days between creating tasks")
	ErrNotActivated   = errors.New("your account is not yet activated for task creation. please complete more activities or wait for the initial trust period")

	// Application lifecycle
	ErrApplicationNotFound = errors.New("application not found")
	ErrAlreadyApplied      = errors.New("you have already applied to this task")
	ErrInvalidCode         = errors.New("verification code is incorrect")
	ErrNotApplicant        = errors.New("you are not the applicant for this application")
	ErrAlreadyVerified     = errors.New("application code already verified")
	ErrNotConfirmable      = errors.New("application must be code_verified before confirmation")
	ErrNotTaskOwner        = errors.New("only the task creator can perform this action")
)

type RestrictedError struct {
	Until time.Time
}

func (e *RestrictedError) Error() string {
	return fmt.Sprintf("account restricted until %s", e.Until.Format(time.RFC3339))
}
