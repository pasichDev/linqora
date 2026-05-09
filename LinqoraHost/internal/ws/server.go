package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"runtime"
	"sync"
	"time"

	"LinqoraHost/internal/capabilities"
	"LinqoraHost/internal/clipboard"
	"LinqoraHost/internal/collectors"
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/deviceinfo"
	"LinqoraHost/internal/filebrowser"
	"LinqoraHost/internal/keyboard"
	"LinqoraHost/internal/media"
	"LinqoraHost/internal/metrics"
	"LinqoraHost/internal/monitors"
	"LinqoraHost/internal/mouse"
	"LinqoraHost/internal/power"
	"LinqoraHost/internal/privileges"
	"LinqoraHost/internal/process"
	"LinqoraHost/internal/scheduler"
	"LinqoraHost/internal/startup"

	"LinqoraHost/internal/interfaces"

	"github.com/gorilla/websocket"
	gopshost "github.com/shirou/gopsutil/v4/host"
)

// WSServer represents the primary WebSocket server coordinating communication
// between the host and remote clients.
type WSServer struct {
	config                *config.ServerConfig
	httpServer            *http.Server
	roomManager           *RoomManager
	broadcaster           *Broadcaster
	clients               map[*Client]bool
	clientsMutex          sync.Mutex
	upgrader              websocket.Upgrader
	authManager           interfaces.AuthManagerInterface
	scriptManager         *scheduler.Manager
	batteryAlertCollector *collectors.BatteryAlertCollector
	ctx                   context.Context
	cancel                context.CancelFunc
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

	server.scriptManager.SeedDefaults()

	broadcaster := NewBroadcaster(roomManager)
	server.broadcaster = broadcaster

	// Initialise collectors
	metricsCollector := collectors.NewMetricsCollector(broadcaster.GetMetricsBroadcaster())
	mediaCollector := collectors.NewMediaCollector(broadcaster.GetMediaBroadcaster())
	clipboardCollector := collectors.NewClipboardCollector(broadcaster.GetClipboardBroadcaster())

	// Register collector manager
	collectorManager := collectors.NewCollectorManager(metricsCollector, mediaCollector, clipboardCollector)
	roomManager.AddRoomListener(collectorManager)

	// Initialise and start the battery alert collector (always active, not room-based).
	batteryAlertCollector := collectors.NewBatteryAlertCollector(server.broadcastToAll)
	server.batteryAlertCollector = batteryAlertCollector
	batteryAlertCollector.Start()

	// Start inactivity monitoring
	server.StartInactiveClientsMonitor()

	// Start the lock-state monitor
	power.StartLockStateMonitor(ctx)

	// Start cron loop: fires scheduled scripts and broadcasts results to all clients.
	server.scriptManager.StartCronLoop(ctx, func(scriptID string) {
		slog.Info("Cron trigger", "script", scriptID)
		result, err := server.scriptManager.Execute(scriptID, func(chunk scheduler.OutputChunk) {
			server.broadcastToAll("script_output", chunk)
		})
		if err != nil {
			slog.Error("Scheduled script failed", "script", scriptID, "err", err)
			return
		}
		server.broadcastToAll("script_execute", map[string]interface{}{
			"id":          result.ID,
			"exit_code":   result.ExitCode,
			"stdout":      result.Stdout,
			"stderr":      result.Stderr,
			"duration_ms": result.Duration,
			"triggered":   "schedule",
		})
	})

	return server
}

// broadcastToAll sends a message to every connected client regardless of room membership.
func (s *WSServer) broadcastToAll(msgType string, data interface{}) {
	s.clientsMutex.Lock()
	snapshot := make([]*Client, 0, len(s.clients))
	for client := range s.clients {
		if !client.IsClosed() {
			snapshot = append(snapshot, client)
		}
	}
	s.clientsMutex.Unlock()

	for _, client := range snapshot {
		client.SendSuccess(msgType, data) //nolint:errcheck
	}
}

// Start begins listening for incoming WebSocket connections.
func (s *WSServer) Start(parentCtx context.Context) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		s.handleWSConnection(w, r)
	})

	// REST API endpoints.
	mux.HandleFunc("/api/v1/info", s.restInfo)
	mux.HandleFunc("/api/v1/processes", s.restProcesses)
	mux.HandleFunc("/api/v1/processes/kill", s.restKillProcess)
	mux.HandleFunc("/api/v1/qr", s.restQR)
	mux.HandleFunc("/api/v1/metrics", s.restMetrics)
	mux.HandleFunc("/api/v1/scripts", s.restScripts)
	mux.HandleFunc("/api/v1/scripts/execute", s.restScriptExecute)
	mux.HandleFunc("/api/v1/media", s.restMedia)
	mux.HandleFunc("/api/v1/power", s.restPower)
	mux.HandleFunc("/api/v1/keyboard/type", s.restKeyboardType)

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", s.config.Port),
		Handler: mux,
	}

	serverErr := make(chan error, 1)

	go func() {
		var err error
		slog.Info("WebSocket server started", "port", s.config.Port)

		if s.config.EnableTLS {
			err = s.httpServer.ListenAndServeTLS(
				s.config.CertFile,
				s.config.KeyFile,
			)
		} else {
			err = s.httpServer.ListenAndServe()
		}

		if err != nil && err != http.ErrServerClosed {
			slog.Error("WebSocket server failed", "err", err)
			serverErr <- err
		}
	}()

	select {
	case <-parentCtx.Done():
		slog.Info("Parent context cancelled, shutting down...")
		return s.Shutdown()
	case <-s.ctx.Done():
		slog.Info("Server context cancelled, shutting down...")
		return s.Shutdown()
	case err := <-serverErr:
		return err
	}
}

// Shutdown gracefully stops the server and disconnects all clients.
func (s *WSServer) Shutdown() error {
	slog.Info("Shutting down WebSocket server...")

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	s.clientsMutex.Lock()
	slog.Info("Closing client connections", "count", len(s.clients))
	for client := range s.clients {
		if err := client.Conn.WriteControl(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.CloseGoingAway, "server shutdown"),
			time.Now().Add(time.Second)); err != nil {
			slog.Error("Error sending close message to client", "err", err)
		}
		client.Conn.Close()
		delete(s.clients, client)
	}
	s.clientsMutex.Unlock()

	if err := s.httpServer.Shutdown(ctx); err != nil {
		slog.Error("HTTP server shutdown error", "err", err)
		return err
	}

	s.cancel()
	slog.Info("WebSocket server stopped successfully")
	return nil
}

// StopServer triggers an internal cancellation of the server context.
func (s *WSServer) StopServer() error {
	s.cancel()
	return nil
}

// handleWSConnection upgrades an HTTP connection to a WebSocket connection.
func (s *WSServer) handleWSConnection(w http.ResponseWriter, r *http.Request) {
	slog.Info("WebSocket connection attempt", "remote_addr", r.RemoteAddr)

	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("Upgrade error", "err", err)
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
		slog.Info("Client removed from active clients list", "device", client.DeviceName)
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
		slog.Info("Disconnecting inactive client (no PING for over 2 minutes)", "device", client.DeviceName)

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
	case "monitor_set_resolution":
		s.handleMonitorSetResolution(client, msg)
	case "monitor_set_primary":
		s.handleMonitorSetPrimary(client, msg)
	case "file_list":
		s.handleFileList(client, msg)
	case "file_read":
		s.handleFileRead(client, msg)
	case "file_write":
		s.handleFileWrite(client, msg)
	case "keyboard":
		s.handleKeyboardCommand(client, msg)
	case "keyboard_type":
		s.handleKeyboardTypeCommand(client, msg)
	case "platform_caps":
		s.handlePlatformCaps(client)
	case "clipboard_set":
		s.handleClipboardSet(client, msg)
	case "display_cmd":
		s.handleDisplayCommand(client, msg)
	case "process_list":
		s.handleProcessList(client)
	case "process_kill":
		s.handleProcessKill(client, msg)
	case "startup_list":
		s.handleStartupList(client)
	case "startup_set":
		s.handleStartupSet(client, msg)
	case "battery_alert_config":
		s.handleBatteryAlertConfig(client, msg)
	case "auth_request":
		if s.authManager != nil {
			s.authManager.HandleAuthRequest(client, msg)
		} else {
			slog.Error("authManager is nil")
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
		slog.Warn("Unknown message type", "type", msg.Type)
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
	hostStat, _ := gopshost.Info()
	uptime, _ := gopshost.Uptime()

	kernelVersion := ""
	platformVersion := ""
	if hostStat != nil {
		kernelVersion = hostStat.KernelVersion
		platformVersion = hostStat.PlatformVersion
	}

	hostInfo := map[string]interface{}{
		"os":              deviceInfo.OS,
		"hostname":        deviceInfo.Hostname,
		"su":              privileges.CheckAdminPrivileges(),
		"cpu":             cpuInfo,
		"ram":             ramInfo,
		"gpu":             gpuInfo,
		"disks":           diskInfo,
		"battery":         batteryInfo,
		"uptime":          uptime,
		"architecture":    runtime.GOARCH,
		"kernelVersion":   kernelVersion,
		"platformVersion": platformVersion,
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

// handleMonitorSetResolution sets the resolution of a specific monitor.
func (s *WSServer) handleMonitorSetResolution(client *Client, msg *ClientMessage) {
	var data struct {
		MonitorID   string `json:"monitor_id"`
		Width       int    `json:"width"`
		Height      int    `json:"height"`
		RefreshRate int    `json:"refresh_rate"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("monitor_set_resolution", "Invalid format", 400)
		return
	}
	if err := monitors.SetResolution(data.MonitorID, data.Width, data.Height, data.RefreshRate); err != nil {
		client.SendError("monitor_set_resolution", err.Error(), 500)
		return
	}
	client.SendSuccess("monitor_set_resolution", map[string]any{"status": "ok"})
}

// handleMonitorSetPrimary designates the specified monitor as the primary display.
func (s *WSServer) handleMonitorSetPrimary(client *Client, msg *ClientMessage) {
	var data struct {
		MonitorID string `json:"monitor_id"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("monitor_set_primary", "Invalid format", 400)
		return
	}
	if err := monitors.SetPrimary(data.MonitorID); err != nil {
		client.SendError("monitor_set_primary", err.Error(), 500)
		return
	}
	client.SendSuccess("monitor_set_primary", map[string]any{"status": "ok"})
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

// handleKeyboardCommand sends a keystroke (with optional modifiers) to the OS.
func (s *WSServer) handleKeyboardCommand(client *Client, msg *ClientMessage) {
	var cmd keyboard.KeyCommand
	if err := json.Unmarshal(msg.Data, &cmd); err != nil {
		client.SendError("keyboard", "Invalid format", 400)
		return
	}
	if !keyboard.ValidKey(cmd.Key) {
		client.SendError("keyboard", fmt.Sprintf("Unknown key: %s", cmd.Key), 400)
		return
	}
	if err := keyboard.HandleKeyCommand(cmd); err != nil {
		client.SendError("keyboard", err.Error(), 500)
		return
	}
	client.SendSuccess("keyboard", map[string]interface{}{"key": cmd.Key})
}

// handleKeyboardTypeCommand injects a text string as Unicode keystrokes.
func (s *WSServer) handleKeyboardTypeCommand(client *Client, msg *ClientMessage) {
	var data struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil || data.Text == "" {
		client.SendError("keyboard_type", "text field required", 400)
		return
	}
	if len([]rune(data.Text)) > 1000 {
		client.SendError("keyboard_type", "text exceeds 1000 characters", 400)
		return
	}
	if err := keyboard.TypeText(data.Text); err != nil {
		client.SendError("keyboard_type", err.Error(), 500)
		return
	}
	client.SendSuccess("keyboard_type", map[string]interface{}{"status": "ok"})
}

// handlePlatformCaps returns the capability flags and platform name for the host.
func (s *WSServer) handlePlatformCaps(client *Client) {
	client.SendSuccess("platform_caps", map[string]interface{}{
		"platform": capabilities.Platform(),
		"features": capabilities.Get(),
	})
}

// handleClipboardSet writes text received from the phone to the host clipboard.
func (s *WSServer) handleClipboardSet(client *Client, msg *ClientMessage) {
	var data struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("clipboard_set", "Invalid format", 400)
		return
	}
	if err := clipboard.Set(data.Text); err != nil {
		client.SendError("clipboard_set", err.Error(), 500)
		return
	}
	client.SendSuccess("clipboard_set", map[string]interface{}{"status": "ok"})
}

// handleDisplayCommand routes sleep/wake/brightness commands to the monitors package.
func (s *WSServer) handleDisplayCommand(client *Client, msg *ClientMessage) {
	var data struct {
		Action     string `json:"action"`     // "sleep", "wake", "brightness"
		Brightness int    `json:"brightness"` // 0-100, used when action == "brightness"
	}
	if err := json.Unmarshal(msg.Data, &data); err != nil {
		client.SendError("display_cmd", "Invalid format", 400)
		return
	}

	var err error
	switch data.Action {
	case "sleep":
		err = monitors.SleepDisplay()
	case "wake":
		err = monitors.WakeDisplay()
	case "brightness":
		err = monitors.SetBrightness(data.Brightness)
	default:
		client.SendError("display_cmd", "Unknown action", 400)
		return
	}

	if err != nil {
		client.SendError("display_cmd", err.Error(), 500)
		return
	}
	client.SendSuccess("display_cmd", map[string]interface{}{"status": "ok"})
}

// ── Process management ────────────────────────────────────────────────────────

// handleProcessList returns a snapshot of all running processes.
func (s *WSServer) handleProcessList(client *Client) {
	procs, err := process.List()
	if err != nil {
		client.SendError("process_list", err.Error(), 500)
		return
	}
	client.SendSuccess("process_list", map[string]interface{}{
		"processes": procs,
	})
}

// handleProcessKill terminates the process with the requested PID.
func (s *WSServer) handleProcessKill(client *Client, msg *ClientMessage) {
	var req struct {
		PID int32 `json:"pid"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.PID == 0 {
		client.SendError("process_kill", "Invalid PID", 400)
		return
	}
	if err := process.Kill(req.PID); err != nil {
		client.SendError("process_kill", err.Error(), 500)
		return
	}
	client.SendSuccess("process_kill", map[string]interface{}{"pid": req.PID})
}

// ── Startup management ────────────────────────────────────────────────────────

// handleStartupList returns all startup entries visible to the current user.
func (s *WSServer) handleStartupList(client *Client) {
	entries, err := startup.ListEntries()
	if err != nil {
		client.SendError("startup_list", err.Error(), 500)
		return
	}
	client.SendSuccess("startup_list", map[string]interface{}{
		"entries": entries,
	})
}

// handleStartupSet enables or disables a startup entry by name.
func (s *WSServer) handleStartupSet(client *Client, msg *ClientMessage) {
	var req struct {
		Name    string `json:"name"`
		Enabled bool   `json:"enabled"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil || req.Name == "" {
		client.SendError("startup_set", "Invalid request", 400)
		return
	}
	if err := startup.SetEntry(req.Name, req.Enabled); err != nil {
		client.SendError("startup_set", err.Error(), 500)
		return
	}
	client.SendSuccess("startup_set", map[string]interface{}{
		"name":    req.Name,
		"enabled": req.Enabled,
	})
}

// ── Battery alert config ──────────────────────────────────────────────────────

// handleBatteryAlertConfig updates the battery alert threshold.
func (s *WSServer) handleBatteryAlertConfig(client *Client, msg *ClientMessage) {
	var req struct {
		Threshold int `json:"threshold"`
	}
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		client.SendError("battery_alert_config", "Invalid format", 400)
		return
	}
	if req.Threshold < 0 || req.Threshold > 100 {
		client.SendError("battery_alert_config", "Threshold must be 0–100", 400)
		return
	}
	if s.batteryAlertCollector != nil {
		s.batteryAlertCollector.SetThreshold(req.Threshold)
	}
	client.SendSuccess("battery_alert_config", map[string]interface{}{
		"threshold": req.Threshold,
	})
}

// ── REST helpers ──────────────────────────────────────────────────────────────

// getLANIP returns the first non-loopback IPv4 address of this machine.
func getLANIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, addr := range addrs {
		ipNet, ok := addr.(*net.IPNet)
		if !ok {
			continue
		}
		ip := ipNet.IP.To4()
		if ip == nil || ip.IsLoopback() {
			continue
		}
		return ip.String()
	}
	return ""
}

// restAuth checks the Authorization: Bearer header against the shared secret.
// If no shared secret is configured, the request is allowed (dev mode).
func (s *WSServer) restAuth(r *http.Request) bool {
	if s.config.SharedSecret == "" {
		return true
	}
	header := r.Header.Get("Authorization")
	if len(header) > 7 && header[:7] == "Bearer " {
		return header[7:] == s.config.SharedSecret
	}
	return false
}

// restWriteJSON serialises v as JSON and writes it to w with the given status code.
func restWriteJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}

// restInfo returns basic host information.
func (s *WSServer) restInfo(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodGet {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	devInfo := deviceinfo.GetDeviceInfo()
	restWriteJSON(w, http.StatusOK, map[string]interface{}{
		"hostname": devInfo.Hostname,
		"os":       devInfo.OS,
		"port":     s.config.Port,
	})
}

// restProcesses handles GET /api/v1/processes — returns the process list.
func (s *WSServer) restProcesses(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodGet {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	procs, err := process.List()
	if err != nil {
		restWriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	restWriteJSON(w, http.StatusOK, map[string]interface{}{"processes": procs})
}

// restKillProcess handles POST /api/v1/processes/kill — kills a process by PID.
func (s *WSServer) restKillProcess(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodPost {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var req struct {
		PID int32 `json:"pid"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PID == 0 {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid pid"})
		return
	}
	if err := process.Kill(req.PID); err != nil {
		restWriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	restWriteJSON(w, http.StatusOK, map[string]interface{}{"pid": req.PID, "status": "killed"})
}

// restQR handles GET /api/v1/qr — returns a deep-link URL for client pairing.
func (s *WSServer) restQR(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodGet {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	devInfo := deviceinfo.GetDeviceInfo()
	host := getLANIP()
	if host == "" {
		host = devInfo.Hostname
	}
	url := fmt.Sprintf("linqora://%s:%d", host, s.config.Port)
	restWriteJSON(w, http.StatusOK, map[string]interface{}{
		"url": url,
		"tls": s.config.EnableTLS,
	})
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
			slog.Info("Executing lock", "requested_by", client.DeviceName)
			if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
				slog.Error("Lock failed", "err", err)
			} else {
				power.SetDeviceLocked(true)
				slog.Info("Device locked")
			}
		}()
		return
	}

	locked, err := power.IsSystemLocked()
	if err != nil {
		slog.Warn("System lock check failed", "err", err)
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
		slog.Info("Executing power action", "action", powerCmd.Action, "requested_by", client.DeviceName)
		if err := power.ExecutePowerAction(powerCmd.Action); err != nil {
			slog.Error("Power action failed", "err", err)
		}
	}()
}

// ── Extended REST API ──────────────────────────────────────────────────────────

// restMetrics handles GET /api/v1/metrics — current system performance snapshot.
func (s *WSServer) restMetrics(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodGet {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	cpuMetrics, _ := metrics.GetCPUMetrics()
	ramMetrics, _ := metrics.GetRamMetrics()
	batteryInfo, _ := metrics.GetBatteryInfo()
	restWriteJSON(w, http.StatusOK, map[string]interface{}{
		"cpu":         cpuMetrics,
		"ram":         ramMetrics,
		"gpu_load":    metrics.GetGPULoadPercent(),
		"gpu_temp":    metrics.GetGPUTemperature(),
		"battery":     batteryInfo,
	})
}

// restScripts handles GET /api/v1/scripts — list all registered scripts.
func (s *WSServer) restScripts(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodGet {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	restWriteJSON(w, http.StatusOK, map[string]interface{}{"scripts": s.scriptManager.List()})
}

// restScriptExecute handles POST /api/v1/scripts/execute — run a script and return output.
// Body: {"id": "script-id"}
func (s *WSServer) restScriptExecute(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodPost {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var req struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ID == "" {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "id required"})
		return
	}
	result, err := s.scriptManager.Execute(req.ID, nil)
	if err != nil {
		restWriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	restWriteJSON(w, http.StatusOK, result)
}

// restMedia handles POST /api/v1/media — send a media or volume command.
// Body: {"action": <int>, "value": <int>}  (see media.MediaCommand)
func (s *WSServer) restMedia(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodPost {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var cmd media.MediaCommand
	if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	if err := media.HandleMediaCommand(cmd); err != nil {
		restWriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	restWriteJSON(w, http.StatusOK, map[string]interface{}{"status": "ok"})
}

// restPower handles POST /api/v1/power — trigger a power action.
// Body: {"action": "shutdown"|"restart"|"lock"|"sleep"}
func (s *WSServer) restPower(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodPost {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var req struct {
		Action string `json:"action"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Action == "" {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "action required"})
		return
	}
	actionMap := map[string]power.Action{
		"shutdown": power.Shutdown,
		"restart":  power.Restart,
		"lock":     power.Lock,
		"sleep":    power.Sleep,
	}
	action, ok := actionMap[req.Action]
	if !ok {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{
			"error": fmt.Sprintf("unknown action %q, valid: shutdown|restart|lock|sleep", req.Action),
		})
		return
	}
	go func() {
		if err := power.ExecutePowerAction(action); err != nil {
			slog.Error("REST power action failed", "action", req.Action, "err", err)
		}
	}()
	restWriteJSON(w, http.StatusAccepted, map[string]interface{}{"status": "accepted", "action": req.Action})
}

// restKeyboardType handles POST /api/v1/keyboard/type — inject text as keystrokes.
// Body: {"text": "hello world"}
func (s *WSServer) restKeyboardType(w http.ResponseWriter, r *http.Request) {
	if !s.restAuth(r) {
		restWriteJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if r.Method != http.MethodPost {
		restWriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var req struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Text == "" {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "text required"})
		return
	}
	if len([]rune(req.Text)) > 1000 {
		restWriteJSON(w, http.StatusBadRequest, map[string]string{"error": "text exceeds 1000 characters"})
		return
	}
	if err := keyboard.TypeText(req.Text); err != nil {
		restWriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	restWriteJSON(w, http.StatusOK, map[string]interface{}{"status": "ok"})
}
