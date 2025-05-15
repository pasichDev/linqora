package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/media"
	"LinqoraHost/internal/metrics"

	"LinqoraHost/internal/interfaces"

	"github.com/gorilla/websocket"
)

// WSServer WebSocket сервер
type WSServer struct {
	config       *config.ServerConfig
	httpServer   *http.Server
	roomManager  *RoomManager
	broadcaster  *Broadcaster
	clients      map[*Client]bool
	clientsMutex sync.Mutex
	upgrader     websocket.Upgrader
	authManager  interfaces.AuthManagerInterface
}

// NewWSServer створює новий WebSocket сервер
func NewWSServer(config *config.ServerConfig, authManager interfaces.AuthManagerInterface) *WSServer {
	roomManager := NewRoomManager()

	server := &WSServer{
		config:      config,
		roomManager: roomManager,
		clients:     make(map[*Client]bool),
		authManager: authManager,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}

	// Инициализируем broadcaster после создания server
	server.broadcaster = NewBroadcaster(roomManager)

	return server
}

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
	serverErr := make(chan error, 1)
	go func() {
		var err error
		log.Printf("WebSocket server started at :%d", s.config.Port)

		if s.config.EnableTLS {
			// Запускаємо з TLS (WSS)
			err = s.httpServer.ListenAndServeTLS(
				s.config.CertFile,
				s.config.KeyFile,
			)
		} else {
			// Звичайний запуск без TLS (WS)
			err = s.httpServer.ListenAndServe()
		}

		if err != nil && err != http.ErrServerClosed {
			log.Printf("WebSocket server failed: %v", err)
			serverErr <- err
		}
	}()

	select {
	case <-ctx.Done():
		log.Println("Server context cancelled, shutting down...")
		return s.Shutdown()
	case err := <-serverErr:
		return err
	}
}

// Улучшенный метод Shutdown
func (s *WSServer) Shutdown() error {
	log.Println("Shutting down WebSocket server...")

	// Создаем контекст с таймаутом для корректного закрытия
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	// Отправляем сигнал всем клиентам о закрытии
	s.clientsMutex.Lock()
	log.Printf("Closing %d client connections...", len(s.clients))
	for client := range s.clients {
		if err := client.Conn.WriteControl(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.CloseGoingAway, "server shutdown"),
			time.Now().Add(time.Second)); err != nil {
			log.Printf("Error sending close message to client: %v", err)
		}
		client.Conn.Close()
		delete(s.clients, client)
	}
	s.clientsMutex.Unlock()

	// Останавливаем HTTP сервер
	if err := s.httpServer.Shutdown(ctx); err != nil {
		log.Printf("HTTP server shutdown error: %v", err)
		return err
	}

	log.Println("WebSocket server stopped successfully")
	return nil
}

// Обновите метод handleWSConnection
func (s *WSServer) handleWSConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket connection attempt from", r.RemoteAddr)

	// Устанавливаем таймауты соединения
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	// Настройка параметров WebSocket соединения
	conn.SetReadLimit(2048)
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	client := NewClient(conn, r.RemoteAddr, s.roomManager)

	s.clientsMutex.Lock()
	s.clients[client] = true
	s.clientsMutex.Unlock()

	// Запускаем горутины с контролируемым завершением
	go client.StartWritePump()
	validDevices := make([]string, 0, len(s.config.ValidDeviceIDs))
	for deviceID := range s.config.ValidDeviceIDs {
		validDevices = append(validDevices, deviceID)
	}
	go client.StartReadPump(validDevices, func(msg *ClientMessage) {
		s.handleClientMessage(client, msg)
	}, func() {
		s.removeClient(client)
		s.roomManager.RemoveClientFromAllRooms(client)
	})
}

// removeClient видаляє клієнта з сервера
func (s *WSServer) removeClient(client *Client) {
	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()

	delete(s.clients, client)
}

// handleClientMessage обробляє повідомлення від клієнта
func (s *WSServer) handleClientMessage(client *Client, msg *ClientMessage) {

	if msg.Type != "auth_request" && msg.Type != "auth_check" {
		if !s.authManager.IsAuthorized(client.GetDeviceID()) {
			client.SendError("Unauthorized access")
			return
		}
	}

	switch msg.Type {
	case "host_info":
		s.handleHostInfoMessage(client, msg)
	case "join_room":
		s.handleJoinRoomMessage(client, msg)
	case "leave_room":
		s.handleLeaveRoomMessage(client, msg)
	case "media":
		s.handleMediaCommand(client, msg)
	case "auth_request":
		if s.authManager != nil {
			s.authManager.HandleAuthRequest(client, msg)
		} else {
			log.Printf("ERROR: authManager is nil, cannot process auth_request")
			client.SendError("Internal server error: auth manager not initialized")
		}
	case "auth_check":
		if s.authManager != nil {
			s.authManager.HandleAuthCheck(client)
		} else {
			log.Printf("ERROR: authManager is nil, cannot process auth_check")
			client.SendError("Internal server error: auth manager not initialized")
		}
	default:
		log.Printf("Unknown message type: %s", msg.Type)

	}
}

// handleHostInfoMessage обробляє відомлення з інформацією про хост
// Відправляє інформацію про систему назад клієнту
func (s *WSServer) handleHostInfoMessage(client *Client, msg *ClientMessage) {
	// Отримуємо характеристики системи
	ramTotal, _ := metrics.GetRamTotal()

	// Отримуємо характеристики системи
	cpuModel, _ := metrics.GetCPUModel()

	// Отримуємо інформацію про пристрій
	deviceInfo := metrics.GetDeviceInfo()

	freq, _ := metrics.GetCPUFrequency()
	cores, threads, _ := metrics.GetCPUCoresAndThreads()

	// Формуємо відповідь з характеристиками системи
	host_info := HostInfo{
		OS:                 deviceInfo.OS,
		Hostname:           deviceInfo.Hostname,
		CpuModel:           cpuModel,
		VirtualMemoryTotal: ramTotal,
		CpuPhysicalCores:   cores,
		CpuLogicalCores:    threads,
		CpuFrequency:       freq,
	}

	response := HostInfoResponse{
		Type:     "host_info",
		Success:  true,
		HostInfo: host_info,
	}

	responseJSON, _ := json.Marshal(response)
	client.SendMessage(responseJSON)

}

// handleJoinRoomMessage обробляє повідомлення приєднання до кімнати
func (s *WSServer) handleJoinRoomMessage(client *Client, msg *ClientMessage) {
	// Добавляем клиента в комнату
	s.roomManager.AddClientToRoom(msg.Room, client)
}

// handleLeaveRoomMessage обробляє повідомлення виходу з кімнати
func (s *WSServer) handleLeaveRoomMessage(client *Client, msg *ClientMessage) {
	s.roomManager.RemoveClientFromRoom(msg.Room, client)
}

// GetRoomManager повертає менеджер кімнат
func (s *WSServer) GetRoomManager() *RoomManager {
	return s.roomManager
} // Используем broadcaster вместо прямых реализаций методов
func (s *WSServer) BroadcastMetrics(metricsData []byte) {
	s.broadcaster.BroadcastMetrics(metricsData)
}

func (s *WSServer) BroadcastMedia(mediaData []byte) {
	s.broadcaster.BroadcastMedia(mediaData)
}

// handleMediaCommand обрабатывает команды управления мультимедиа,и звуком
func (s *WSServer) handleMediaCommand(client *Client, msg *ClientMessage) {
	// First check if client is in media room
	if !s.roomManager.IsClientInRoom("media", client) {
		log.Printf("Client %s tried to send media command without joining media room", client.DeviceName)
		return
	}

	var data map[string]interface{}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		log.Printf("Error unmarshaling media command: %v", err)
		return
	}

	action, ok1 := data["action"].(float64)
	value, ok2 := data["value"].(float64)

	var mediaCommand = media.MediaCommand{
		Action: int(action),
		Value:  int(value),
	}

	// Проверяем, что action и value корректные
	if !ok1 {
		log.Printf("Invalid media command format from %s", client.DeviceName)
		return
	}

	if !ok2 {
		log.Printf("Invalid media command format from %s", client.DeviceName)
		return
	}

	err := media.HandleMediaCommand(mediaCommand)
	if err != nil {
		log.Printf("Error executing media command: %v", err)
		return
	}
}
