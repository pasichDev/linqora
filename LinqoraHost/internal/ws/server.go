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
	"LinqoraHost/internal/filebrowser"
	"LinqoraHost/internal/media"
	"LinqoraHost/internal/metrics"
	"LinqoraHost/internal/monitors"
	"LinqoraHost/internal/mouse"
	"LinqoraHost/internal/power"
	"LinqoraHost/internal/privileges"
	"LinqoraHost/internal/scheduler"

	"LinqoraHost/internal/interfaces"

	"github.com/gorilla/websocket"
)

// WSServer represents the primary WebSocket server coordinating communication
// between the host and remote clients.
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

// NewWSServer initialises a new WebSocket server with the provided configuration.
func NewWSServer(config *config.ServerConfig, authManager interfaces.AuthManagerInterface) *WSServer {
	ctx, cancel := context.WithCancel(context.Background())
	roomManager := NewRoomManager()

	server := &WSServer{
		config:        config,
		roomManager:   roomManager,
		clients:       make(map[*Client]bool),
		authManager:   authManager,
		scriptManager: scheduler.NewManager(scheduler.DefaultScriptsPath()),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// Native clients (mobile app) send no Origin header.
				// Browsers always set Origin, so rejecting non-empty Origin blocks
				// cross-site WebSocket hijacking (CSRF via browser pages).
				return r.Header.Get("Origin") == ""
			},
		},
		ctx:    ctx,
		cancel: cancel,
	}

	broadcaster := NewBroadcaster(roomManager)
	server.broadcaster = broadcaster

	// Initialise collectors
	metricsCollector := collectors.NewMetricsCollector(broadcaster.GetMetricsBroadcaster())
	mediaCollector := collectors.NewMediaCollector(broadcaster.GetMediaBroadcaster())

	// Register collector manager
	collectorManager := collectors.NewCollectorManager(metricsCollector, mediaCollector)
	roomManager.AddRoomListener(collectorManager)

	// Start inactivity monitoring
	server.StartInactiveClientsMonitor()

	// Start the lock-state monitor
	power.StartLockStateMonitor(ctx)

	return server
}

// Start begins listening for incoming WebSocket connections.
func (s *WSServer) Start(parentCtx context.Context) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		s.handleWSConnection(w, r)
	})

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", s.config.Port),
		Handler: mux,
	}

	serverErr := make(chan error, 1)

	go func() {
		var err error
		log.Printf("WebSocket server started at :%d", s.config.Port)

		if s.config.EnableTLS {
			err = s.httpServer.ListenAndServeTLS(
				s.config.CertFile,
				s.config.KeyFile,
			)
		} else {
			err = s.httpServer.ListenAndServe()
		}

		if err != nil && err != http.ErrServerClosed {
			log.Printf("WebSocket server failed: %v", err)
			serverErr <- err
		}
	}()

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

// Shutdown gracefully stops the server and disconnects all clients.
func (s *WSServer) Shutdown() error {
	log.Println("Shutting down WebSocket server...")

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

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

	if err := s.httpServer.Shutdown(ctx); err != nil {
		log.Printf("HTTP server shutdown error: %v", err)
		return err
	}

	s.cancel()
	log.Println("WebSocket server stopped successfully")
	return nil
}

// StopServer triggers an internal cancellation of the server context.
func (s *WSServer) StopServer() error {
	s.cancel()
	return nil
}

// handleWSConnection upgrades an HTTP connection to a WebSocket connection.
func (s *WSServer) handleWSConnection(w http.ResponseWriter, r *http.Request) {
	log.Println("WebSocket connection attempt from", r.RemoteAddr)

	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	client := NewClient(conn, r.RemoteAddr)
	if s.config.EnableE2EE && s.config.SharedSecret != "" {
		client.SetE2EEKey(DeriveKey(s.config.SharedSecret))
	}

	s.clientsMutex.Lock()
	s.clients[client] = true
	s.clientsMutex.Unlock()

	go client.StartWritePump()
	go client.StartReadPump(func(msg *ClientMessage) {
		s.handleClientMessage(client, msg)
	}, func() {
		s.removeClient(client)
		s.roomManager.RemoveClientFromAllRooms(client)
	})
}

// removeClient cleans up client resources and removes them from the server registry.
func (s *WSServer) removeClient(client *Client) {
	if client == nil {
		return
	}

	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()

	if _, exists := s.clients[client]; exists {
		delete(s.clients, client)
		client.Close()
		log.Printf("Client %s removed from active clients list", client.DeviceName)
	}
}

// StartInactiveClientsMonitor periodically purges clients that haven't sent a ping.
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

// checkInactiveClients identifies and disconnects non-responsive clients.
func (s *WSServer) checkInactiveClients() {
	s.clientsMutex.Lock()
	inactiveClients := make([]*Client, 0)

	for client := range s.clients {
		if client.TimeSinceLastPing() > 2*time.Minute {
			inactiveClients = append(inactiveClients, client)
		}
	}
	s.clientsMutex.Unlock()

	for _, client := range inactiveClients {
		log.Printf("Disconnecting inactive client %s (no PING for over 2 minutes)", client.DeviceName)

		closeMsg := websocket.FormatCloseMessage(
			websocket.CloseGoingAway,
			"inactive client timeout (no PING)",
		)
		client.Conn.WriteControl(
			websocket.CloseMessage,
			closeMsg,
			time.Now().Add(time.Second),
		)

		client.Conn.Close()
		s.removeClient(client)
		s.roomManager.RemoveClientFromAllRooms(client)
	}
}

// handleClientMessage routes incoming client messages to appropriate handlers.
func (s *WSServer) handleClientMessage(client *Client, msg *ClientMessage) {
	// Skip authorization check for authentication-related messages
	authExempt := map[string]bool{
		"auth_request":            true,
		"auth_check":              true,
		"ping":                    true,
		"auth_challenge_response": true,
	}

	if !authExempt[msg.Type] {
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
	case "monitor_list":
		s.handleMonitorList(client)
	case "monitor_cmd":
		s.handleMonitorCommand(client, msg)
	case "file_list":
		s.handleFileList(client, msg)
	case "file_read":
		s.handleFileRead(client, msg)
	case "file_write":
		s.handleFileWrite(client, msg)
	case "auth_request":
		if s.authManager != nil {
			s.authManager.HandleAuthRequest(client, msg)
		} else {
			log.Printf("ERROR: authManager is nil")
			client.SendError("auth_request", "Internal server error", 500)
		}
	case "auth_check":
		if s.authManager != nil {
			s.authManager.HandleAuthCheck(client)
		} else {
			client.SendError("auth_check", "Internal server error", 500)
		}
	case "auth_challenge_response":
		if s.authManager != nil {
			s.authManager.HandleChallengeResponse(client, msg)
		} else {
			client.SendError("auth_challenge_response", "Internal server error", 500)
		}
	default:
		log.Printf("Unknown message type: %s", msg.Type)
	}
}

// handlePingMessage responds to client heartbeats.
func (s *WSServer) handlePingMessage(client *Client, msg *ClientMessage) {
	var timestamp interface{} = time.Now().UnixMilli()
	if len(msg.Data) > 0 {
		var pingData map[string]interface{}
		if err := json.Unmarshal(msg.Data, &pingData); err == nil && pingData["timestamp"] != nil {
			timestamp = pingData["timestamp"]
		}
	}

	client.SendSuccess("pong", map[string]interface{}{
		"timestamp": timestamp,
	})
}

// handleHostInfoMessage provides system and hardware specifications to the client.
func (s *WSServer) handleHostInfoMessage(client *Client) {
	cpuInfo, _ := metrics.GetCPUInfo()
	deviceInfo := deviceinfo.GetDeviceInfo()
	ramInfo, _ := metrics.GetRAMInfo()
	gpuInfo, _ := metrics.GetGPUInfo()
	diskInfo, _ := metrics.GetDiskInfo()
	batteryInfo, _ := metrics.GetBatteryInfo()

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

	client.SendSuccess("host_info", hostInfo)
}

// handleJoinRoomMessage subscribes the client to a broadcast room.
func (s *WSServer) handleJoinRoomMessage(client *Client, msg *ClientMessage) {
	s.roomManager.AddClientToRoom(msg.Room, client)
}

// handleLeaveRoomMessage unsubscribes the client from a broadcast room.
func (s *WSServer) handleLeaveRoomMessage(client *Client, msg *ClientMessage) {
	s.roomManager.RemoveClientFromRoom(msg.Room, client)
}

// handleMediaCommand processes volume and playback control requests.
func (s *WSServer) handleMediaCommand(client *Client, msg *ClientMessage) {
	if !s.roomManager.IsClientInRoom("media", client) {
		client.SendError("media", "Client not in media room", 403)
		return
	}

	var data map[string]interface{}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("media", "Invalid format", 400)
		return
	}

	action, ok1 := data["action"].(float64)
	value, ok2 := data["value"].(float64)

	if !ok1 || !ok2 {
		client.SendError("media", "Invalid parameters", 400)
		return
	}

	err := media.HandleMediaCommand(media.MediaCommand{
		Action: int(action),
		Value:  int(value),
	})
	if err != nil {
		client.SendError("media", err.Error(), 500)
		return
	}

	client.SendSuccess("media", map[string]interface{}{
		"action": int(action),
		"value":  int(value),
		"status": "success",
	})
}

// handleScriptList returns all registered scripts.
func (s *WSServer) handleScriptList(client *Client) {
	client.SendSuccess("script_list", map[string]interface{}{
		"scripts": s.scriptManager.List(),
	})
}

// handleScriptAdd registers a new script on the host.
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

// handleScriptUpdate modifies an existing script definition.
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

// handleScriptDelete removes a script definition from the host.
func (s *WSServer) handleScriptDelete(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_delete", "Invalid script ID", 400)
		return
	}
	if err := s.scriptManager.Delete(req.ID); err != nil {
		client.SendError("script_delete", err.Error(), 500)
		return
	}
	client.SendSuccess("script_delete", req)
}

// handleScriptStop terminates a running script process.
func (s *WSServer) handleScriptStop(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_stop", "Invalid script ID", 400)
		return
	}
	s.scriptManager.Stop(req.ID)
	client.SendSuccess("script_stop", req)
}

// handleScriptExecute starts a script and routes its output back to the client.
func (s *WSServer) handleScriptExecute(client *Client, msg *ClientMessage) {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.ID == "" {
		client.SendError("script_execute", "Invalid script ID", 400)
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

// handleMonitorList returns all connected monitors and their current settings.
func (s *WSServer) handleMonitorList(client *Client) {
	list, err := monitors.GetMonitors()
	if err != nil {
		client.SendError("monitor_list", err.Error(), 500)
		return
	}
	client.SendSuccess("monitor_list", map[string]interface{}{
		"monitors": list,
	})
}

// handleMonitorCommand processes changes to monitor resolution or primary status.
func (s *WSServer) handleMonitorCommand(client *Client, msg *ClientMessage) {
	var data struct {
		Action    string `json:"action"` // "set_resolution", "set_primary"
		MonitorID string `json:"monitor_id"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
		Rate      int    `json:"rate"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("monitor_cmd", "Invalid format", 400)
		return
	}

	var err error
	switch data.Action {
	case "set_resolution":
		err = monitors.SetResolution(data.MonitorID, data.Width, data.Height, data.Rate)
	case "set_primary":
		err = monitors.SetPrimary(data.MonitorID)
	default:
		client.SendError("monitor_cmd", "Unknown action", 400)
		return
	}

	if err != nil {
		client.SendError("monitor_cmd", err.Error(), 500)
		return
	}

	client.SendSuccess("monitor_cmd", map[string]interface{}{"status": "ok"})
}

// handleFileList lists directory contents.
func (s *WSServer) handleFileList(client *Client, msg *ClientMessage) {
	var data struct {
		Path string `json:"path"`
	}
	json.Unmarshal(msg.Data, &data)
	if data.Path == "" {
		data.Path = filebrowser.GetHomeDir()
	}

	list, err := filebrowser.ListDir(data.Path)
	if err != nil {
		client.SendError("file_list", err.Error(), 500)
		return
	}

	client.SendSuccess("file_list", map[string]interface{}{
		"path":  data.Path,
		"files": list,
	})
}

// handleFileRead reads a file and sends it to the client.
func (s *WSServer) handleFileRead(client *Client, msg *ClientMessage) {
	var data struct {
		Path string `json:"path"`
	}
	json.Unmarshal(msg.Data, &data)

	content, err := filebrowser.ReadFile(data.Path)
	if err != nil {
		client.SendError("file_read", err.Error(), 500)
		return
	}

	client.SendSuccess("file_read", map[string]interface{}{
		"path":    data.Path,
		"content": content, // JSON marshal will base64 encode this
	})
}

// handleFileWrite saves a file from the client.
func (s *WSServer) handleFileWrite(client *Client, msg *ClientMessage) {
	var data struct {
		Path    string `json:"path"`
		Content []byte `json:"content"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("file_write", "Invalid format", 400)
		return
	}

	if err := filebrowser.WriteFile(data.Path, data.Content); err != nil {
		client.SendError("file_write", err.Error(), 500)
		return
	}

	client.SendSuccess("file_write", map[string]interface{}{"status": "ok"})
}

// handleMouseCommand performs cursor movement or button clicks.
func (s *WSServer) handleMouseCommand(client *Client, msg *ClientMessage) {
	var cmd mouse.MouseCommand
	if err := json.Unmarshal(msg.Data, &cmd); err != nil {
		client.SendError("mouse", "Invalid format", 400)
		return
	}
	if err := mouse.HandleMouseCommand(cmd); err != nil {
		client.SendError("mouse", err.Error(), 500)
		return
	}
	// Move events don't need a success reply — reduces latency and bandwidth.
	if cmd.Action != mouse.ActionMove {
		client.SendSuccess("mouse", map[string]interface{}{"action": cmd.Action})
	}
}

// handlePowerCommand executes system power actions like Lock, Restart, or Shutdown.
func (s *WSServer) handlePowerCommand(client *Client, msg *ClientMessage) {
	var powerCmd power.PowerCommand
	if err := json.Unmarshal(msg.Data, &powerCmd); err != nil {
		client.SendError("power", "Invalid format", 400)
		return
	}

	if power.IsDeviceLocked() {
		client.SendSuccess("power", map[string]interface{}{
			"action": powerCmd.Action,
			"status": "locked",
		})
		return
	}

	if powerCmd.Action == power.Lock {
		client.SendSuccess("power", map[string]interface{}{
			"action": powerCmd.Action,
			"status": "executing",
		})
		go func() {
			log.Printf("Executing lock requested by %s", client.DeviceName)
			if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
				log.Printf("Lock failed: %v", err)
			} else {
				power.SetDeviceLocked(true)
				log.Printf("Device locked")
			}
		}()
		return
	}

	locked, err := power.IsSystemLocked()
	if err != nil {
		log.Printf("Warning: system lock check failed: %v", err)
		locked = power.IsDeviceLocked()
	}

	if locked {
		lockTime := power.GetLockTime()
		client.SendError("power", fmt.Sprintf("Device is locked (since %s)", lockTime.Format("15:04:05")), 403)
		return
	}

	client.SendSuccess("power", map[string]interface{}{
		"action": powerCmd.Action,
		"status": "executing",
	})

	go func() {
		log.Printf("Executing power action %d requested by %s", powerCmd.Action, client.DeviceName)
		if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
			log.Printf("Power action failed: %v", err)
		}
	}()
}
