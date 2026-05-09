package updater

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const releaseAPI = "https://api.github.com/repos/pasichDev/linqora/releases/latest"

// Release holds the relevant fields from the GitHub releases API response.
type Release struct {
	TagName string `json:"tag_name"` // e.g. "v0.4.1"
	HTMLURL string `json:"html_url"`
	Body    string `json:"body"` // release notes (markdown)
}

// CheckLatest fetches the latest published release from GitHub.
// Returns an error on network failure or non-200 response.
func CheckLatest() (*Release, error) {
	client := &http.Client{Timeout: 10 * time.Second}

	req, err := http.NewRequest(http.MethodGet, releaseAPI, nil)
	if err != nil {
		return nil, fmt.Errorf("updater: build request: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("updater: request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("updater: GitHub API returned %d", resp.StatusCode)
	}

	var rel Release
	if err := json.NewDecoder(resp.Body).Decode(&rel); err != nil {
		return nil, fmt.Errorf("updater: parse error: %w", err)
	}
	return &rel, nil
}
