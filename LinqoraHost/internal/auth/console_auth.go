package auth

import (
	"fmt"
	"sync"
	"time"

	"LinqoraHost/internal/interfaces"
)

var ConsoleMutex sync.Mutex

// Handler of console-based authorization requests
type ConsoleAuthHandler struct {
	authManager   *AuthManager
	authRequests  map[string]interfaces.PendingAuthRequest
	authTimers    map[string]*time.Timer
	requestsMutex sync.Mutex
}

// Create a new ConsoleAuthHandler instance
func NewConsoleAuthHandler(authManager *AuthManager) *ConsoleAuthHandler {
	return &ConsoleAuthHandler{
		authManager:  authManager,
		authRequests: make(map[string]interfaces.PendingAuthRequest),
		authTimers:   make(map[string]*time.Timer),
	}
}

// Handle incoming authorization requests
func (h *ConsoleAuthHandler) ProcessAuthRequests(authChan <-chan interfaces.PendingAuthRequest, stopCh <-chan struct{}) {
	for {
		select {
		case req := <-authChan:
			h.requestsMutex.Lock()
			ConsoleMutex.Lock()
			fmt.Printf("\n\n===> AUTHORIZATION REQUEST <===\n")
			fmt.Printf("Device:  %s\n", req.DeviceName)
			fmt.Printf("ID:      %s\n", req.DeviceID)
			fmt.Printf("IP:      %s\n", req.IP)
			fmt.Printf("Time:    %s\n\n", req.RequestTime.Format("15:04:05"))
			fmt.Printf("Allow connection? (y/n): ")

			// Save the request in the map
			h.authRequests[req.DeviceID] = req

			timer := time.AfterFunc(30*time.Second, func() {
				h.requestsMutex.Lock()
				defer h.requestsMutex.Unlock()

				// Check if the request still exists
				if expiredReq, exists := h.authRequests[req.DeviceID]; exists {
					ConsoleMutex.Lock()
					fmt.Printf("\n\nAuthorization request for device %s (%s) has expired\n",
						expiredReq.DeviceName, expiredReq.DeviceID)
					fmt.Print("> ")
					ConsoleMutex.Unlock()

					// Cancel the request
					h.authManager.RespondToAuthRequest(req.DeviceID, false)

					// Delete the request and timer
					delete(h.authRequests, req.DeviceID)
					delete(h.authTimers, req.DeviceID)
				}
			})

			h.authTimers[req.DeviceID] = timer
			ConsoleMutex.Unlock()
			h.requestsMutex.Unlock()

		case <-stopCh:
			// ASync shutdown: stop all timers and exit
			h.requestsMutex.Lock()
			for _, timer := range h.authTimers {
				if timer != nil {
					timer.Stop()
				}
			}
			h.requestsMutex.Unlock()
			return
		}
	}
}

// Handle the response to an authorization request
func (h *ConsoleAuthHandler) ProcessAuthResponse(command string) bool {
	h.requestsMutex.Lock()
	defer h.requestsMutex.Unlock()

	// Else, if there are no active requests, return false
	if len(h.authRequests) == 0 {
		return false
	}

	// Check if the command is empty
	if command != "y" && command != "n" {
		return false
	}

	// Selecting the latest request
	var latestReq interfaces.PendingAuthRequest
	var latestDeviceID string
	latestTime := time.Time{}

	for id, req := range h.authRequests {
		if latestTime.IsZero() || req.RequestTime.After(latestTime) {
			latestReq = req
			latestDeviceID = id
			latestTime = req.RequestTime
		}
	}

	approved := command == "y"

	// Stop the timer for the latest request
	if timer, exists := h.authTimers[latestDeviceID]; exists && timer != nil {
		timer.Stop()
		delete(h.authTimers, latestDeviceID)
	}

	// Respond to the authorization request
	h.authManager.RespondToAuthRequest(latestDeviceID, approved)

	if approved {
		fmt.Printf("Authorization for device %s approved\n", latestReq.DeviceName)
	} else {
		fmt.Printf("Authorization for device %s rejected\n", latestReq.DeviceName)
	}

	// Delete the request from the map
	delete(h.authRequests, latestDeviceID)
	return true
}

// Check if there are pending authorization requests
func (h *ConsoleAuthHandler) HasPendingRequests() bool {
	h.requestsMutex.Lock()
	defer h.requestsMutex.Unlock()
	return len(h.authRequests) > 0
}
