package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"runtime"
	"sync"
	"time"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/handler"
	"LinqoraHost/internal/metrics"

	"github.com/gorilla/websocket"
)

// WSServer WebSocket сервер
type WSServer struct {
	config       *config.ServerConfig
	httpServer   *http.Server
	roomManager  *RoomManager
	clients      map[*Client]bool
	clientsMutex sync.Mutex
	upgrader     websocket.Upgrader
}

// NewWSServer створює новий WebSocket сервер
func NewWSServer(config *config.ServerConfig) *WSServer {
	return &WSServer{
		config:      config,
		roomManager: NewRoomManager(),
		clients:     make(map[*Client]bool),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true }, // Дозволяє підключатися з будь-якого походження
		},
	}
}

// Start запускає WebSocket сервер
func (s *WSServer) Start(ctx context.Context) error {
	mux := http.NewServeMux()

	// Обробник WebSocket з'єднання
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		s.handleWSConnection(w, r)
	})

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", s.config.Port),
		Handler: mux,
	}

	// Запускаємо HTTP сервер у goroutine
	go func() {
		log.Printf("WebSocket server started at :%d", s.config.Port)
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("WebSocket server failed: %v", err)
		}
	}()

	// Очікуємо на завершення контексту
	<-ctx.Done()
	return s.Shutdown()
}

// Shutdown зупиняє WebSocket сервер
func (s *WSServer) Shutdown() error {
	// Створюємо контекст з таймаутом для зупинки сервера
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Зупиняємо HTTP сервер
	if err := s.httpServer.Shutdown(ctx); err != nil {
		return err
	}

	// Закриваємо всі WebSocket з'єднання
	s.clientsMutex.Lock()
	for client := range s.clients {
		client.Conn.Close()
	}
	s.clientsMutex.Unlock()

	return nil
}

// handleWSConnection обробляє нове WebSocket з'єднання
func (s *WSServer) handleWSConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket connection attempt from", r.RemoteAddr)
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	client := NewClient(conn, r.RemoteAddr, s.roomManager)

	s.clientsMutex.Lock()
	s.clients[client] = true
	s.clientsMutex.Unlock()

	// Запускаємо горутини для обробки повідомлень
	go client.StartWritePump()
	go client.StartReadPump(s.config.ValidDeviceIDs, s.handleClientMessage)
}

// removeClient видаляє клієнта з сервера
func (s *WSServer) removeClient(client *Client) {
	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()

	delete(s.clients, client)
}

// handleClientMessage обробляє повідомлення від клієнта
func (s *WSServer) handleClientMessage(client *Client, msg *ClientMessage) {
	switch msg.Type {
	case "auth":
		s.handleAuthMessage(client, msg)
	case "join_room":
		s.handleJoinRoomMessage(client, msg)
	case "leave_room":
		s.handleLeaveRoomMessage(client, msg)
	case "cursor_command":
		s.handleCursorCommandMessage(client, msg)
	//case "cursor_command":

	default:
		log.Printf("Unknown message type: %s", msg.Type)
	}
}

// handleAuthMessage обробляє повідомлення аутентифікації
func (s *WSServer) handleAuthMessage(client *Client, msg *ClientMessage) {
	var authData AuthData
	if err := json.Unmarshal(msg.Data, &authData); err != nil {
		log.Printf("Error unmarshaling auth data: %v", err)
		return
	}

	client.SetDeviceName(authData.DeviceName)
	client.IP = authData.IP

	// Отримуємо характеристики системи
	ramTotal, _ := metrics.GetRamTotal()

	// Отримуємо інформацію про пристрій
	deviceInfo := metrics.GetDeviceInfo()

	// Формуємо відповідь з характеристиками системи
	systemInfo := AuthInfomation{
		OS:                 deviceInfo.OS,
		Hostname:           deviceInfo.Hostname,
		CpuModel:           runtime.NumCPU(),
		VirtualMemoryTotal: ramTotal,
	}

	response := AuthResponse{
		Type:           "auth_response",
		Success:        true,
		AuthInfomation: systemInfo,
	}

	responseJSON, _ := json.Marshal(response)
	client.SendMessage(responseJSON)

	// Додаємо клієнта до кімнати аутентифікації
	s.roomManager.AddClientToRoom("auth", client)

	log.Printf("Client %s authenticated successfully", client.DeviceName)
}

// handleJoinRoomMessage обробляє повідомлення приєднання до кімнати
func (s *WSServer) handleJoinRoomMessage(client *Client, msg *ClientMessage) {
	s.roomManager.AddClientToRoom(msg.Room, client)
}

// handleLeaveRoomMessage обробляє повідомлення виходу з кімнати
func (s *WSServer) handleLeaveRoomMessage(client *Client, msg *ClientMessage) {
	s.roomManager.RemoveClientFromRoom(msg.Room, client)
}

// handleCursorCommandMessage обробляє команди керування курсором
func (s *WSServer) handleCursorCommandMessage(client *Client, msg *ClientMessage) {
	var data map[string]interface{}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		log.Printf("Error unmarshaling cursor command: %v", err)
		return
	}

	x, ok1 := data["x"].(float64)
	y, ok2 := data["y"].(float64)
	action, ok3 := data["action"].(float64)

	if !ok1 || !ok2 || !ok3 {
		log.Printf("Invalid cursor command format from %s", client.DeviceName)
		return
	}

	// Увеличиваем чувствительность и округляем
	intX := int(x * 3) // Увеличили множитель
	intY := int(y * 3)
	intAction := int(action)

	// Игнорируем слишком маленькие движения при перемещении
	if intAction == 0 && abs(intX) < 2 && abs(intY) < 2 {
		return
	}

	handler.HandleMouseCommand(intX, intY, intAction)
}
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

// BroadcastMetrics відправляє метрики всім клієнтам у кімнаті metrics
func (s *WSServer) BroadcastMetrics(metricsData []byte) {
	message := MetricsMessage{
		Type: "metrics",
		Data: json.RawMessage(metricsData),
	}

	messageJSON, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling metrics message: %v", err)
		return
	}

	s.roomManager.BroadcastToRoom("metrics", messageJSON, nil)
}

// GetRoomManager повертає менеджер кімнат
func (s *WSServer) GetRoomManager() *RoomManager {
	return s.roomManager
}
