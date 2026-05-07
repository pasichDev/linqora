package auth

// Message type identifiers for authorization flows.
const (
	MessageTypeAuthResponse      = "auth_response"
	MessageTypeAuthPending       = "auth_pending"
	MessageTypeAuthChallenge     = "auth_challenge"
	MessageTypeAuthChallengeResp = "auth_challenge_response"
)

// Authorization status codes used in server responses.
const (
	AuthStatusNotAuthorized = 001

	// Challenge-response codes (3xx)
	AuthStatusChallengeInvalid = 300

	// Success codes (1xx)
	AuthStatusAuthorized = 100 // Device is already recognized
	AuthStatusApproved   = 101 // Manual authorization was granted

	// Informational codes (2xx)
	AuthStatusPending = 200 // Waiting for user interaction on host

	// Client-side error codes (4xx)
	AuthStatusRejected        = 400 // Manual authorization was denied
	AuthStatusInvalidFormat   = 401 // Request data is malformed
	AuthStatusMissingDeviceID = 402 // Device ID field is empty

	// Server-side error codes (5xx)
	AuthStatusTimeout            = 500 // Authorization expired before approval
	AuthStatusRequestFailed      = 501 // Internal failure during request processing
	AuthStatusUnsupportedVersion = 502 // Client version is incompatible with host
)

// Human-readable descriptions for authorization status codes.
var authMessages = map[int]string{
	AuthStatusChallengeInvalid:   "Challenge verification failed",
	AuthStatusNotAuthorized:      "Device not authorized",
	AuthStatusAuthorized:         "Device authorized",
	AuthStatusApproved:           "Authorization approved",
	AuthStatusRejected:           "Authorization rejected",
	AuthStatusPending:            "Waiting for authorization",
	AuthStatusTimeout:            "Authorization timeout",
	AuthStatusInvalidFormat:      "Invalid authorization data format",
	AuthStatusMissingDeviceID:    "Device ID is missing",
	AuthStatusRequestFailed:      "Authorization request failed",
	AuthStatusUnsupportedVersion: "Client version is outdated and not supported",
}

// GetAuthMessage retrieves the descriptive message associated with a status code.
func GetAuthMessage(code int) string {
	if msg, ok := authMessages[code]; ok {
		return msg
	}
	return "Unknown authorization error"
}
