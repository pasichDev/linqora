package ws

import (
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/interfaces"
	"encoding/json"
	"testing"
)

type mockConn struct {
	lastMessage []byte
}

func (m *mockConn) WriteMessage(messageType int, data []byte) error {
	m.lastMessage = data
	return nil
}

type MockAuthManager struct{}

func (m *MockAuthManager) RequestAuthorization(deviceName, deviceID, ip string) bool { return true }
func (m *MockAuthManager) RespondToAuthRequest(deviceID string, approved bool)       {}
func (m *MockAuthManager) IsAuthorized(deviceID string) bool                         { return true }
func (m *MockAuthManager) CheckPendingResult(deviceID string) (bool, bool)           { return true, true }
func (m *MockAuthManager) RevokeAuth(deviceID string)                                {}
func (m *MockAuthManager) HandleAuthRequest(client interfaces.WSClient, msg interfaces.WSMessage) {
}
func (m *MockAuthManager) HandleAuthCheck(client interfaces.WSClient) {}
func (m *MockAuthManager) HandleChallengeResponse(client interfaces.WSClient, msg interfaces.WSMessage) {
}

func TestServerRouting(t *testing.T) {
	cfg := config.DefaultConfig()
	server := NewWSServer(cfg, &MockAuthManager{})

	// We don't need a real connection for logic testing
	client := NewClient(nil, "127.0.0.1")

	// Test monitor_list routing
	msg := &ClientMessage{
		Type: "monitor_list",
		Data: json.RawMessage("{}"),
	}

	// Since handleMonitorList calls monitors.GetMonitors, it might fail on CI/CD
	// but we just want to see if it reaches the handler and doesn't panic.
	// In a real test we'd mock the monitors package.

	server.handleClientMessage(client, msg)
}

func TestE2EERouting(t *testing.T) {
	cfg := config.DefaultConfig()
	cfg.EnableE2EE = true
	cfg.SharedSecret = "test-secret"

	server := NewWSServer(cfg, &MockAuthManager{})
	client := NewClient(nil, "127.0.0.1")
	client.SetE2EEKey(DeriveKey(cfg.SharedSecret))

	innerMsg := ClientMessage{
		Type: "ping",
		Data: json.RawMessage("{}"),
	}
	innerData, _ := json.Marshal(innerMsg)
	_ = innerData // Ensure it's used or removed

	// This is trickier because handleClientMessage expects the decrypted message
	// The decryption happens in StartReadPump.
	// So we test the routing logic by ensuring decrypted messages are handled.

	server.handleClientMessage(client, &innerMsg)
}
