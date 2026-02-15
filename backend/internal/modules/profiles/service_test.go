package profiles

import "testing"

func TestSplitDisplayName(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		first, last string
	}{
		{name: "empty", input: "", first: "", last: ""},
		{name: "single", input: "Alice", first: "Alice", last: ""},
		{name: "two", input: "Alice Wonderland", first: "Alice", last: "Wonderland"},
		{name: "multi", input: "Alice B Wonderland", first: "Alice", last: "B Wonderland"},
		{name: "spaces", input: "  Alice   Wonderland  ", first: "Alice", last: "Wonderland"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			first, last := splitDisplayName(tt.input)
			if first != tt.first || last != tt.last {
				t.Fatalf("splitDisplayName(%q) = (%q, %q), want (%q, %q)", tt.input, first, last, tt.first, tt.last)
			}
		})
	}
}

func TestIsAllowedImageType(t *testing.T) {
	tests := []struct {
		ct   string
		want bool
	}{
		{ct: "image/jpeg", want: true},
		{ct: "image/png", want: true},
		{ct: "image/webp", want: true},
		{ct: "image/gif", want: false},
		{ct: "application/octet-stream", want: false},
		{ct: "", want: false},
	}

	for _, tt := range tests {
		if got := isAllowedImageType(tt.ct); got != tt.want {
			t.Fatalf("isAllowedImageType(%q) = %v, want %v", tt.ct, got, tt.want)
		}
	}
}

func TestExtFromContentType(t *testing.T) {
	tests := []struct {
		ct   string
		want string
	}{
		{ct: "image/jpeg", want: ".jpg"},
		{ct: "image/png", want: ".png"},
		{ct: "image/webp", want: ".webp"},
		{ct: "image/gif", want: ""},
		{ct: "", want: ""},
	}

	for _, tt := range tests {
		if got := extFromContentType(tt.ct); got != tt.want {
			t.Fatalf("extFromContentType(%q) = %q, want %q", tt.ct, got, tt.want)
		}
	}
}
