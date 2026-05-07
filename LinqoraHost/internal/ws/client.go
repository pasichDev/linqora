package ws

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	// writeWait is the time allowed to write a message to the peer.
	writeWait = 10 * time.Second
	// pongWait is the time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second
	// pingPeriod is the interval to send pings to the peer. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10
	// maxMessageSize is the maximum message size allowed from the peer.
	maxMessageSize = 512
)

// Client represents a connected WebSocket client.
type Client struct {
	Conn         *websocket.Conn
	DeviceCode   string
	DeviceName   string
	IP           string
	Rooms        map[string]bool
	SendChannel  chan []byte
	mu           sync.Mutex
	closed       bool
	DeviceID     string
	lastPingTime time.Time
	limiter      *clientRateLimiter
	e2eeKey      []byte
}

// NewClient creates a new Client instance.
func NewClient(conn *websocket.Conn, ip string) *Client {
	return &Client{
		Conn:         conn,
		IP:           ip,
		Rooms:        make(map[string]bool),
		SendChannel:  make(chan []byte, 256),
		lastPingTime: time.Now(),
		limiter:      newClientRateLimiter(),
	}
}

// GetIP returns the client's IP address.
func (c *Client) GetIP() string {
	return c.IP
}

// GetDeviceID returns the unique device identifier.
func (c *Client) GetDeviceID() string {
	return c.DeviceID
}

// GetDeviceName returns the human-readable device name.
func (c *Client) GetDeviceName() string {
	return c.DeviceName
}

// SetDeviceID updates the device identifier.
func (c *Client) SetDeviceID(id string) {
	c.DeviceID = id
}

// IsClosed reports whether the client connection is closed.
func (c *Client) IsClosed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.closed
}

// SetDeviceName updates the human-readable device name.
func (c *Client) SetDeviceName(name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.DeviceName = name
}

// SetE2EEKey sets the key used for application-layer encryption.
func (c *Client) SetE2EEKey(key []byte) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.e2eeKey = key
}

// GetType returns the message type.
func (m *ClientMessage) GetType() string {
	return m.Type
}

// GetData returns the raw JSON data of the message.
func (m *ClientMessage) GetData() []byte {
	return m.Data
}

// StartReadPump handles incoming messages from the WebSocket connection.
func (c *Client) StartReadPump(handleMessage func(*ClientMessage), onDisconnect func()) {
	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	defer func() {
		if r := recover(); r != nil {
			log.Printf("Panic recovered in ReadPump: %v", r)
		}

		if onDisconnect != nil {
			onDisconnect()
		}

		log.Printf("Client %s disconnected", c.DeviceName)
	}()

	for {
		messageType, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err,
				websocket.CloseGoingAway, websocket.CloseAbnormalClosure,
				websocket.CloseNoStatusReceived) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		if messageType != websocket.TextMessage {
			continue
		}

		var clientMsg ClientMessage
		if err := json.Unmarshal(message, &clientMsg); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			continue
		}

		// Decrypt payload if E2EE is enabled and message type is "encrypted"
		if clientMsg.Type == "encrypted" && c.e2eeKey != nil {
			var cryptoMsg struct {
				Payload string `json:"payload"`
			}
			if err := json.Unmarshal(clientMsg.Data, &cryptoMsg); err == nil {
				decrypted, err := Decrypt(cryptoMsg.Payload, c.e2eeKey)
				if err == nil {
					// Replace original message with decrypted content
					var innerMsg ClientMessage
					if err := json.Unmarshal(decrypted, &innerMsg); err == nil {
						clientMsg = innerMsg
					}
				}
			}
		}

		// Rate limiting protection
		if clientMsg.Type != "ping" && !c.limiter.Allow() {
			log.Printf("Rate limit exceeded for client %s, dropping %q", c.DeviceName, clientMsg.Type)
			c.SendError(clientMsg.Type, "Rate limit exceeded, slow down", 429)
			continue
		}

		// Handle message with panic protection
		func() {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("Panic recovered in message handling: %v", r)
				}
			}()

			handleMessage(&clientMsg)
		}()
	}
}

// StartWritePump handles outgoing messages to the WebSocket connection.
func (c *Client) StartWritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Panic recovered in WritePump: %v", r)
		}

		ticker.Stop()
		log.Printf("WritePump for client %s stopped", c.DeviceName)
	}()

	for {
		if c.IsClosed() {
			return
		}

		select {
		case message, ok := <-c.SendChannel:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				log.Printf("SendChannel closed for client %s, exiting WritePump", c.DeviceName)
				c.Conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(
					websocket.CloseNormalClosure, "channel closed"))
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				log.Printf("Error getting writer for client %s: %v", c.DeviceName, err)
				return
			}

			_, err = w.Write(message)
			if err != nil {
				log.Printf("Error writing message to client %s: %v", c.DeviceName, err)
				return
			}

			if err := w.Close(); err != nil {
				log.Printf("Error closing writer for client %s: %v", c.DeviceName, err)
				return
			}
		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				log.Printf("Error sending ping to client %s: %v", c.DeviceName, err)
				return
			}
		}
	}
}

// sendMessage queues a message for delivery.
func (c *Client) sendMessage(message []byte) error {
	c.mu.Lock()
	e2eeKey := c.e2eeKey
	c.mu.Unlock()

	if e2eeKey != nil {
		encrypted, err := Encrypt(message, e2eeKey)
		if err == nil {
			// Wrap in an encrypted message structure
			envelope := NewSuccessResponse("encrypted", map[string]string{
				"payload": encrypted,
			})
			message, _ = json.Marshal(envelope)
		}
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.closed || c.SendChannel == nil {
		return fmt.Errorf("attempting to send message to closed client: %s", c.DeviceName)
	}

	// Non-blocking send; if the channel is full the client is too slow.
	select {
	case c.SendChannel <- message:
		return nil
	default:
		go c.Close()
		return fmt.Errorf("send channel full for client: %s", c.DeviceName)
	}
}

// UpdateLastPingTime records the time of the most recent ping received.
func (c *Client) UpdateLastPingTime() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.lastPingTime = time.Now()
}

// TimeSinceLastPing returns the duration since the last ping message.
func (c *Client) TimeSinceLastPing() time.Duration {
	c.mu.Lock()
	defer c.mu.Unlock()
	return time.Since(c.lastPingTime)
}

// SendError formats and sends an error response to the client.
func (c *Client) SendError(requestType string, message string, errorCode ...int) error {
	errorResponse := NewErrorResponse(requestType, message, errorCode...)
	if jsonMsg, err := json.Marshal(errorResponse); err == nil {
		return c.sendMessage(jsonMsg)
	} else {
		log.Printf("Error marshaling error message: %v", err)
		return err
	}
}

// SendSuccess formats and sends a success response to the client.
func (c *Client) SendSuccess(responseType string, data interface{}) error {
	successResponse := NewSuccessResponse(responseType, data)
	if jsonMsg, err := json.Marshal(successResponse); err == nil {
		return c.sendMessage(jsonMsg)
	} else {
		log.Printf("Error marshaling success message: %v", err)
		return err
	}
}

// Close safely terminates the client connection and releases resources.
func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.closed {
		return
	}

	c.closed = true

	if c.Conn != nil {
		c.Conn.Close()
	}

	if c.SendChannel != nil {
		close(c.SendChannel)
		c.SendChannel = nil
	}

	log.Printf("Client %s closed gracefully", c.DeviceName)
}

// Lock acquires the client's mutex.
func (c *Client) Lock() {
	c.mu.Lock()
}

// Unlock releases the client's mutex.
func (c *Client) Unlock() {
	c.mu.Unlock()
}
