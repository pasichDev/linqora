package LinqoraHost

import (
	"context"
	"log"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/mdns"
	"LinqoraHost/internal/metrics"
	"LinqoraHost/internal/ws"
)

// Server основний клас сервера
type Server struct {
	ctx              context.Context
	cancel           context.CancelFunc
	config           *config.ServerConfig
	wsServer         *ws.WSServer
	mdnsService      *mdns.MDNSService
	metricsCollector *metrics.MetricsCollector
}

// NewServer створює новий сервер
func NewServer(cfg *config.ServerConfig) *Server {
	if cfg == nil {
		cfg = config.DefaultConfig()
	}

	ctx, cancel := context.WithCancel(context.Background())

	// Створюємо WebSocket сервер
	wsServer := ws.NewWSServer(cfg)

	// Створюємо mDNS сервіс
	mdnsService := mdns.NewMDNSService(cfg)

	// Створюємо колектор метрик
	metricsCollector := metrics.NewMetricsCollector(cfg, wsServer.BroadcastMetrics)

	return &Server{
		ctx:              ctx,
		cancel:           cancel,
		config:           cfg,
		wsServer:         wsServer,
		mdnsService:      mdnsService,
		metricsCollector: metricsCollector,
	}
}

// Start запускає сервер
func (s *Server) Start() error {
	// Запускаємо всі компоненти
	log.Println("Starting Linqora server...")

	// Запускаємо mDNS сервіс в goroutine
	go func() {
		if err := s.mdnsService.Start(s.ctx); err != nil {
			log.Printf("mDNS service error: %v", err)
		}
	}()

	// Запускаємо збір метрик в goroutine
	go s.metricsCollector.Start(s.ctx)

	// Запускаємо WebSocket сервер в goroutine
	return s.wsServer.Start(s.ctx)
}

// Restart перезапускає сервер з новими параметрами
func (s *Server) Restart(cfg *config.ServerConfig) error {
	// Зупиняємо поточний сервер
	s.Shutdown()

	// Створюємо новий сервер з новою конфігурацією
	newServer := NewServer(cfg)

	// Запускаємо новий сервер
	return newServer.Start()
}

// Shutdown зупиняє сервер
func (s *Server) Shutdown() {
	log.Println("Shutting down Linqora server...")

	// Скасовуємо контекст, щоб всі компоненти отримали сигнал про зупинку
	s.cancel()
}

// UpdateMDNSConfig оновлює конфігурацію mDNS
func (s *Server) UpdateMDNSConfig(name, serviceType, domain string) {
	s.mdnsService.UpdateConfig(name, serviceType, domain)
}

// GetConfig повертає конфігурацію сервера
func (s *Server) GetConfig() *config.ServerConfig {
	return s.config
}
