package ranks

import "errors"

var (
	ErrRankNotFound = errors.New("rank not found")
	ErrInvalidSeals = errors.New("invalid seals count")
)
