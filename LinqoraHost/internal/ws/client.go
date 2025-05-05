package ws

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Client представляє WebSocket клієнта
type Client struct {
	Conn        *websocket.Conn
	DeviceCode  string
	DeviceName  string
	IP          string
	Rooms       map[string]bool
	SendChannel chan []byte
	roomManager *RoomManager
	mu          sync.Mutex
}

// NewClient створює нового клієнта
func NewClient(conn *websocket.Conn, ip string, roomManager *RoomManager) *Client {
	return &Client{
		Conn:        conn,
		IP:          ip,
		Rooms:       make(map[string]bool),
		SendChannel: make(chan []byte, 256),
		roomManager: roomManager,
	}
}

// StartReadPump запускає цикл читання повідомлень
func (c *Client) StartReadPump(validDeviceIDs map[string]bool, handleMessage func(*Client, *ClientMessage)) {
	defer func() {
		// Видаляємо клієнта з усіх кімнат
		for roomName := range c.Rooms {
			c.roomManager.RemoveClientFromRoom(roomName, c)
		}

		c.Conn.Close()
		close(c.SendChannel)
		log.Printf("Client %s disconnected", c.DeviceName)
	}()

	// Очікуємо на аутентифікацію протягом 10 секунд
	c.Conn.SetReadDeadline(time.Now().Add(10 * time.Second))

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Error reading message: %v", err)
			}
			break
		}

		// Скидаємо таймаут після успішного читання
		c.Conn.SetReadDeadline(time.Time{})

		var clientMsg ClientMessage
		if err := json.Unmarshal(message, &clientMsg); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			continue
		}

		// Перевірка deviceCode
		if !validDeviceIDs[clientMsg.DeviceCode] {
			log.Printf("Invalid device code from %s", c.IP)
			response := map[string]interface{}{
				"type":    "auth_response",
				"success": false,
				"message": "Invalid device code",
			}
			responseJSON, _ := json.Marshal(response)
			c.SendChannel <- responseJSON
			break // Закриваємо з'єднання
		}

		c.DeviceCode = clientMsg.DeviceCode
		handleMessage(c, &clientMsg)
	}
}

// StartWritePump запускає цикл відправки повідомлень
func (c *Client) StartWritePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case message, ok := <-c.SendChannel:
			c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				// Канал закритий
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			err := c.Conn.WriteMessage(websocket.TextMessage, message)
			if err != nil {
				log.Printf("Error writing message: %v", err)
				return
			}
		case <-ticker.C:
			// Надсилаємо пінг для підтримки з'єднання
			c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// SendMessage відправляє повідомлення клієнту
func (c *Client) SendMessage(message []byte) {
	select {
	case c.SendChannel <- message:
	default:
		log.Printf("Failed to send message to client %s - channel full", c.DeviceName)
	}
}

// SetDeviceName встановлює ім'я пристрою
func (c *Client) SetDeviceName(name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.DeviceName = name
}
