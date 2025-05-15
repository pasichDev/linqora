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
	// Время ожидания записи в сокет
	writeWait = 10 * time.Second
	// Время ожидания PONG от клиента
	pongWait = 60 * time.Second
	// Интервал отправки PING сообщений
	pingPeriod = (pongWait * 9) / 10
	// Максимальный размер сообщения
	maxMessageSize = 512
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
	closed      bool // Флаг закрытия клиента
	DeviceID    string
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

// Добавьте методы для реализации интерфейса
func (c *Client) GetIP() string {
	return c.IP
}

func (c *Client) GetDeviceID() string {
	return c.DeviceID
}

func (c *Client) GetDeviceName() string {
	return c.DeviceName
}

func (c *Client) SetDeviceID(id string) {
	c.DeviceID = id
}

func (c *Client) SetDeviceName(name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.DeviceName = name
}

// Для ClientMessage
func (m *ClientMessage) GetType() string {
	return m.Type
}

func (m *ClientMessage) GetData() []byte {
	return m.Data
}

func (c *Client) StartReadPump(validDeviceIDs []string, handleMessage func(*ClientMessage), onDisconnect func()) {
	// Устанавливаем лимит на размер сообщения
	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	// Защита от паник
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Panic recovered in ReadPump: %v", r)
		}

		// Вызываем callback для удаления клиента из списка
		if onDisconnect != nil {
			onDisconnect()
		}

		log.Printf("Client %s disconnected", c.DeviceName)
	}()

	for {
		// Чтение сообщения
		messageType, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err,
				websocket.CloseGoingAway, websocket.CloseAbnormalClosure,
				websocket.CloseNoStatusReceived) {
				log.Printf("WebSocket read error: %v", err)
			}
			break // Выход из цикла при любой ошибке чтения
		}

		// Обработка только текстовых сообщений
		if messageType != websocket.TextMessage {
			continue
		}

		// Распаковка и обработка сообщения
		var clientMsg ClientMessage
		if err := json.Unmarshal(message, &clientMsg); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			continue
		}

		// Передача сообщения обработчику с защитой от паники
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
		select {
		case message, ok := <-c.SendChannel:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Канал закрыт, завершаем горутину
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

func (c *Client) SendMessage(message []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Проверка на nil для защиты от использования закрытого клиента
	if c.SendChannel == nil {
		log.Printf("Attempt to send message to closed client %s", c.DeviceName)
		return fmt.Errorf("client channel is nil")
	}

	select {
	case c.SendChannel <- message:
		// Сообщение отправлено успешно
		return nil
	default:
		log.Printf("Failed to send message to client %s - channel full or closed", c.DeviceName)

		// Если канал заполнен, закрываем соединение
		c.Conn.Close()
		return fmt.Errorf("send channel full or closed")
	}
}

// SendError sends an error message to the client
func (c *Client) SendError(message string) error {
	errorMsg := map[string]interface{}{
		"type":    "error",
		"message": message,
	}
	if jsonMsg, err := json.Marshal(errorMsg); err == nil {
		c.SendMessage(jsonMsg)
		return nil
	} else {
		return err // Возвращаем ошибку маршалинга
	}
}

// Добавьте метод Close для безопасного закрытия клиента
func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Закрываем соединение
	c.Conn.Close()

	// Безопасно закрываем канал отправки
	close(c.SendChannel)

	// Логируем отключение
	log.Printf("Client %s closed gracefully", c.DeviceName)
}
