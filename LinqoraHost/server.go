package LinqoraHost

import (
	"context"
	"log"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/mdns"
	"LinqoraHost/internal/media"
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
	mediaCollector   *media.MediaCollector
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
	mediaCollector := media.NewMediaCollector(cfg, wsServer.BroadcastMedia)

	return &Server{
		ctx:              ctx,
		cancel:           cancel,
		config:           cfg,
		wsServer:         wsServer,
		mdnsService:      mdnsService,
		metricsCollector: metricsCollector,
		mediaCollector:   mediaCollector,
	}
}

// Start запускає сервер
func (s *Server) Start() error {
	log.Println("Starting Linqora server...")

	// Запускаємо mDNS сервіс в goroutine
	go func() {
		if err := s.mdnsService.Start(s.ctx); err != nil {
			log.Printf("mDNS service error: %v", err)
		}
	}()

	go s.metricsCollector.Start(s.ctx)
	go s.mediaCollector.Start(s.ctx)

	return s.wsServer.Start(s.ctx)
}

// Restart перезапускає сервер з новими параметрами
func (s *Server) Restart(cfg *config.ServerConfig) error {
	s.Shutdown()
	newServer := NewServer(cfg)
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
