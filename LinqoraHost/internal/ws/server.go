package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"LinqoraHost/internal/collectors"
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/deviceinfo"
	"LinqoraHost/internal/media"
	"LinqoraHost/internal/metrics"
	"LinqoraHost/internal/mouse"
	"LinqoraHost/internal/power"
	"LinqoraHost/internal/privileges"
	"LinqoraHost/internal/scheduler"

	"LinqoraHost/internal/interfaces"

	"github.com/gorilla/websocket"
)

// WSServer WebSocket сервер
type WSServer struct {
	config        *config.ServerConfig
	httpServer    *http.Server
	roomManager   *RoomManager
	broadcaster   *Broadcaster
	clients       map[*Client]bool
	clientsMutex  sync.Mutex
	upgrader      websocket.Upgrader
	authManager   interfaces.AuthManagerInterface
	scriptManager *scheduler.Manager
	ctx           context.Context
	cancel        context.CancelFunc
}

// NewWSServer создаёт новый WebSocket сервер
func NewWSServer(config *config.ServerConfig, authManager interfaces.AuthManagerInterface) *WSServer {
	// Создаем контекст с возможностью отмены
	ctx, cancel := context.WithCancel(context.Background())

	roomManager := NewRoomManager()

	server := &WSServer{
		config:        config,
		roomManager:   roomManager,
		clients:       make(map[*Client]bool),
		authManager:   authManager,
		scriptManager: scheduler.NewManager(scheduler.DefaultScriptsPath()),
		upgrader: websocket.Upgrader{
			// Native clients (mobile app) send no Origin header.
			// Browsers always set Origin, so rejecting non-empty Origin blocks
			// cross-site WebSocket hijacking (CSRF via browser pages).
			CheckOrigin: func(r *http.Request) bool {
				return r.Header.Get("Origin") == ""
			},
		},
		ctx:    ctx,
		cancel: cancel,
	}

	// Инициализируем broadcaster
	broadcaster := NewBroadcaster(roomManager)
	server.broadcaster = broadcaster

	// Инициализируем коллекторы (но не запускаем их)
	metricsCollector := collectors.NewMetricsCollector(broadcaster.GetMetricsBroadcaster())
	mediaCollector := collectors.NewMediaCollector(broadcaster.GetMediaBroadcaster())

	// Создаем и регистрируем менеджер коллекторов
	collectorManager := collectors.NewCollectorManager(metricsCollector, mediaCollector)
	roomManager.AddRoomListener(collectorManager)

	// Запускаем мониторинг неактивных клиентов
	server.StartInactiveClientsMonitor()

	// Start the lock-state monitor; it stops when the server context is cancelled
	power.StartLockStateMonitor(ctx)
	return server
}

// Start запускает сервер и ожидает его завершения
func (s *WSServer) Start(parentCtx context.Context) error {
	// Создаем мультиплексор HTTP запросов
	mux := http.NewServeMux()

	// Обработчик WebSocket соединения
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		s.handleWSConnection(w, r)
	})

	// Создаем HTTP сервер
	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", s.config.Port),
		Handler: mux,
	}

	// Канал для ошибок сервера
	serverErr := make(chan error, 1)

	// Запускаем HTTP сервер в горутине
	go func() {
		var err error
		log.Printf("WebSocket server started at :%d", s.config.Port)

		if s.config.EnableTLS {
			// Запускаем с TLS (WSS)
			err = s.httpServer.ListenAndServeTLS(
				s.config.CertFile,
				s.config.KeyFile,
			)
		} else {
			// Обычный запуск без TLS (WS)
			err = s.httpServer.ListenAndServe()
		}

		if err != nil && err != http.ErrServerClosed {
			log.Printf("WebSocket server failed: %v", err)
			serverErr <- err
		}
	}()

	// Ожидаем завершения сервера или контекста
	select {
	case <-parentCtx.Done():
		log.Println("Parent context cancelled, shutting down...")
		return s.Shutdown()
	case <-s.ctx.Done():
		log.Println("Server context cancelled, shutting down...")
		return s.Shutdown()
	case err := <-serverErr:
		return err
	}
}

// Shutdown останавливает сервер
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

	// Вызываем функцию отмены контекста для завершения горутин
	s.cancel()

	log.Println("WebSocket server stopped successfully")
	return nil
}

// StopServer останавливает сервер (вспомогательный метод для внешних вызовов)
func (s *WSServer) StopServer() error {
	s.cancel()
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

	// Connection parameters (read limit, deadline, pong handler) are configured
	// inside StartReadPump using the package-level constants. Setting them here
	// would be overwritten immediately and would cause an inconsistent read limit
	// (2048 here vs maxMessageSize=512 in StartReadPump).
	client := NewClient(conn, r.RemoteAddr)

	s.clientsMutex.Lock()
	s.clients[client] = true
	s.clientsMutex.Unlock()

	// Запускаем горутины с контролируемым завершением
	go client.StartWritePump()

	go client.StartReadPump(func(msg *ClientMessage) {
		s.handleClientMessage(client, msg)
	}, func() {
		s.removeClient(client)
		s.roomManager.RemoveClientFromAllRooms(client)
	})
}

// removeClient видаляє клієнта з сервера
func (s *WSServer) removeClient(client *Client) {
	// Проверяем текущее состояние клиента
	if client == nil {
		return
	}

	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()

	if _, exists := s.clients[client]; exists {
		// Удаляем из списка активных клиентов
		delete(s.clients, client)

		// Закрываем клиента (это безопасная операция)
		client.Close()

		log.Printf("Client %s removed from active clients list",
			client.DeviceName)
	}
}

// StartInactiveClientsMonitor periodically disconnects clients that stopped
// sending pings. The goroutine exits when the server context is cancelled.
func (s *WSServer) StartInactiveClientsMonitor() {
	go func() {
		ticker := time.NewTicker(40 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				s.checkInactiveClients()
			case <-s.ctx.Done():
				return
			}
		}
	}()
}

// Метод для проверки неактивных клиентов
func (s *WSServer) checkInactiveClients() {
	s.clientsMutex.Lock()
	inactiveClients := make([]*Client, 0)

	for client := range s.clients {
		// Проверяем время последнего PING
		if client.TimeSinceLastPing() > 2*time.Minute {
			inactiveClients = append(inactiveClients, client)
		}
	}
	s.clientsMutex.Unlock()

	// Отключаем неактивных клиентов
	for _, client := range inactiveClients {
		log.Printf("Disconnecting inactive client %s (no PING for over 2 minutes)",
			client.DeviceName)

		// Отправляем сообщение о закрытии соединения
		closeMsg := websocket.FormatCloseMessage(
			websocket.CloseGoingAway,
			"inactive client timeout (no PING)",
		)
		client.Conn.WriteControl(
			websocket.CloseMessage,
			closeMsg,
			time.Now().Add(time.Second),
		)

		// Закрываем соединение и удаляем клиента
		client.Conn.Close()
		s.removeClient(client)
		s.roomManager.RemoveClientFromAllRooms(client)
	}
}

// handleClientMessage обробляє повідомлення від клієнта
func (s *WSServer) handleClientMessage(client *Client, msg *ClientMessage) {

	if msg.Type != "auth_request" && msg.Type != "auth_check" && msg.Type != "ping" && msg.Type != "auth_challenge_response" {
		if !s.authManager.IsAuthorized(client.GetDeviceID()) {
			client.SendError(msg.Type, "Unauthorized access", 401)
			return
		}
	}

	switch msg.Type {
	case "ping":
		client.UpdateLastPingTime()
		s.handlePingMessage(client, msg)

	case "host_info":
		s.handleHostInfoMessage(client)
	case "join_room":
		s.handleJoinRoomMessage(client, msg)
	case "leave_room":
		s.handleLeaveRoomMessage(client, msg)
	case "media":
		s.handleMediaCommand(client, msg)
	case "power":
		s.handlePowerCommand(client, msg)
	case "mouse":
		s.handleMouseCommand(client, msg)
	case "script_list":
		s.handleScriptList(client)
	case "script_add":
		s.handleScriptAdd(client, msg)
	case "script_update":
		s.handleScriptUpdate(client, msg)
	case "script_delete":
		s.handleScriptDelete(client, msg)
	case "script_stop":
		s.handleScriptStop(client, msg)
	case "script_execute":
		s.handleScriptExecute(client, msg)
	case "auth_request":
		if s.authManager != nil {
			s.authManager.HandleAuthRequest(client, msg)
		} else {
			log.Printf("ERROR: authManager is nil, cannot process auth_request")
			client.SendError("auth_request", "Internal server error: auth manager not initialized", 500)
		}
	case "auth_check":
		if s.authManager != nil {
			s.authManager.HandleAuthCheck(client)
		} else {
			client.SendError("auth_check", "Internal server error: auth manager not initialized", 500)
		}
	case "auth_challenge_response":
		if s.authManager != nil {
			s.authManager.HandleChallengeResponse(client, msg)
		} else {
			client.SendError("auth_challenge_response", "Internal server error: auth manager not initialized", 500)
		}
	default:
		log.Printf("Unknown message type: %s", msg.Type)

	}
}
func (s *WSServer) handlePingMessage(client *Client, msg *ClientMessage) {

	// Извлекаем timestamp из данных (если есть)
	var timestamp interface{} = time.Now().UnixMilli()
	if len(msg.Data) > 0 {
		if pingData, err := extractPingData(msg.Data); err == nil && pingData["timestamp"] != nil {
			timestamp = pingData["timestamp"]
		}
	}

	client.SendSuccess("pong", map[string]interface{}{
		"timestamp": timestamp,
	})

}

// Вспомогательный метод для извлечения данных
func extractPingData(data json.RawMessage) (map[string]interface{}, error) {
	var pingData map[string]interface{}
	err := json.Unmarshal(data, &pingData)
	return pingData, err
}

// handleHostInfoMessage обробляє відомлення з інформацією про хост
func (s *WSServer) handleHostInfoMessage(client *Client) {
	// Базовая информация о системе
	cpuInfo, _ := metrics.GetCPUInfo()
	deviceInfo := deviceinfo.GetDeviceInfo()

	// Новая информация
	ramInfo, _ := metrics.GetRAMInfo()
	gpuInfo, _ := metrics.GetGPUInfo()
	diskInfo, _ := metrics.GetDiskInfo()
	batteryInfo, _ := metrics.GetBatteryInfo()

	// Формируем расширенный ответ
	hostInfo := map[string]interface{}{
		"os":       deviceInfo.OS,
		"hostname": deviceInfo.Hostname,
		"su":       privileges.CheckAdminPrivileges(),
		"cpu":      cpuInfo,
		"ram":      ramInfo,
		"gpu":      gpuInfo,
		"disks":    diskInfo,
		"battery":  batteryInfo,
	}

	// Отправляем ответ
	client.SendSuccess("host_info", hostInfo)
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

/*
// GetRoomManager повертає менеджер кімнат
func (s *WSServer) GetRoomManager() *RoomManager {
	return s.roomManager
}
*/

// handleMediaCommand обрабатывает команды управления мультимедиа,и звуком
func (s *WSServer) handleMediaCommand(client *Client, msg *ClientMessage) {
	// First check if client is in media room
	if !s.roomManager.IsClientInRoom("media", client) {
		client.SendError("media", "Client not in media room", 403)
		return
	}

	var data map[string]interface{}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("media", "Invalid media command format", 400)
		return
	}

	action, ok1 := data["action"].(float64)
	value, ok2 := data["value"].(float64)

	// Проверяем, что action и value корректные
	if !ok1 || !ok2 {
		client.SendError("media", "Invalid media command parameters", 400)
		return
	}

	var mediaCommand = media.MediaCommand{
		Action: int(action),
		Value:  int(value),
	}

	err := media.HandleMediaCommand(mediaCommand)
	if err != nil {
		client.SendError("media", fmt.Sprintf("Error executing media command: %v", err), 500)
		return
	}

	// Отправляем успешный ответ
	client.SendSuccess("media", map[string]interface{}{
		"action": int(action),
		"value":  int(value),
		"status": "success",
	})
}

func (s *WSServer) handleScriptList(client *Client) {
	client.SendSuccess("script_list", map[string]interface{}{
		"scripts": s.scriptManager.List(),
	})
}

func (s *WSServer) handleScriptAdd(client *Client, msg *ClientMessage) {
	var script scheduler.Script
	if err := json.Unmarshal(msg.Data, &script); err != nil {
		client.SendError("script_add", "Invalid script data", 400)
		return
	}
	if err := s.scriptManager.Add(script); err != nil {
		client.SendError("script_add", err.Error(), 500)
		return
	}
	client.SendSuccess("script_add", script)
}

func (s *WSServer) handleScriptUpdate(client *Client, msg *ClientMessage) {
	var script scheduler.Script
	if err := json.Unmarshal(msg.Data, &script); err != nil {
		client.SendError("script_update", "Invalid script data", 400)
		return
	}
	if err := s.scriptManager.Update(script); err != nil {
		client.SendError("script_update", err.Error(), 500)
		return
	}
	client.SendSuccess("script_update", script)
}

func (s *WSServer) handleScriptDelete(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_delete", "Missing or invalid script id", 400)
		return
	}
	if err := s.scriptManager.Delete(req.ID); err != nil {
		client.SendError("script_delete", err.Error(), 500)
		return
	}
	client.SendSuccess("script_delete", req)
}

func (s *WSServer) handleScriptStop(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_stop", "Missing or invalid script id", 400)
		return
	}
	s.scriptManager.Stop(req.ID)
	client.SendSuccess("script_stop", req)
}

func (s *WSServer) handleScriptExecute(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_execute", "Missing or invalid script id", 400)
		return
	}

	go func() {
		onOutput := func(chunk scheduler.OutputChunk) {
			client.SendSuccess("script_output", chunk)
		}

		result, err := s.scriptManager.Execute(req.ID, onOutput)
		if err != nil {
			client.SendError("script_execute", err.Error(), 404)
			return
		}
		client.SendSuccess("script_execute", map[string]interface{}{
			"id":          result.ID,
			"exit_code":   result.ExitCode,
			"stdout":      result.Stdout,
			"stderr":      result.Stderr,
			"duration_ms": result.Duration,
		})
	}()
}

func (s *WSServer) handleMouseCommand(client *Client, msg *ClientMessage) {
	var cmd mouse.MouseCommand
	if err := json.Unmarshal(msg.Data, &cmd); err != nil {
		client.SendError("mouse", "Invalid mouse command format", 400)
		return
	}
	if err := mouse.HandleMouseCommand(cmd); err != nil {
		client.SendError("mouse", fmt.Sprintf("Mouse error: %v", err), 500)
		return
	}
	// Move events don't need a success reply — reduces latency and bandwidth.
	if cmd.Action != mouse.ActionMove {
		client.SendSuccess("mouse", map[string]interface{}{"action": cmd.Action})
	}
}

// Handle commands for power management
func (s *WSServer) handlePowerCommand(client *Client, msg *ClientMessage) {

	var powerCmd power.PowerCommand
	if err := json.Unmarshal(msg.Data, &powerCmd); err != nil {
		client.SendError("power", "Invalid power command format", 400)
		return
	}

	if power.IsDeviceLocked() {
		// Send a response before the lock command is executed
		client.SendSuccess("power", map[string]interface{}{
			"action": powerCmd.Action,
			"status": "locked",
		})
		return
	}

	// If it is a Lock command, process it separately
	if powerCmd.Action == power.Lock {
		// Отправляем ответ до выполнения команды блокировки
		client.SendSuccess("power", map[string]interface{}{
			"action": powerCmd.Action,
			"status": "executing",
		})
		// If it is a Lock command, process it separately// Check if the client has rights to execute the Lock command
		// Execute the Lock command
		go func() {
			log.Printf("Executing lock action requested by client %s", client.DeviceName)

			if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
				log.Printf("Error executing lock command: %v", err)
			} else {
				// Устанавливаем флаг блокировки
				power.SetDeviceLocked(true)
				log.Printf("Device locked successfully")
			}
		}()
		return
	}

	// Для других команд (выключение, перезагрузка) проверяем состояние блокировки
	locked, err := power.IsSystemLocked()
	if err != nil {
		log.Printf("Warning: Failed to check system lock state: %v", err)
		// Используем внутреннее состояние
		locked = power.IsDeviceLocked()
	}

	if locked {
		lockTime := power.GetLockTime()
		client.SendError("power", fmt.Sprintf("Device is locked (since %s), power action not permitted",
			lockTime.Format("15:04:05")), 403)
		return
	}

	// Отправляем ответ до выполнения команды, так как некоторые команды могут прервать соединение
	client.SendSuccess("power", map[string]interface{}{
		"action": powerCmd.Action,
		"status": "executing",
	})

	// Выполняем команду управления питанием в отдельной горутине
	go func() {
		log.Printf("Executing power action: %d requested by client %s",
			powerCmd.Action, client.DeviceName)

		if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
			log.Printf("Error executing power command: %v", err)
		}
	}()
}
