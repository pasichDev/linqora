package LinqoraHost

import (
	"context"
	"log"

	"LinqoraHost/internal/auth"
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
	mdnsService      *mdns.MDNSServer
	metricsCollector *metrics.MetricsCollector
	mediaCollector   *media.MediaCollector
}

// NewServer створює новий сервер
func NewServer(cfg *config.ServerConfig, authManager *auth.AuthManager) *Server {
	if cfg == nil {
		cfg = config.DefaultConfig()
	}

	ctx, cancel := context.WithCancel(context.Background())

	// Створюємо WebSocket сервер с правильной передачей authManager
	wsServer := ws.NewWSServer(cfg, authManager)

	// Створюємо mDNS сервіс
	mdnsService, err := mdns.NewMDNSServer(cfg)
	if err != nil {
		log.Printf("Failed to create mDNS server: %v", err)
		cancel()
		return nil
	}

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

func (s *Server) Start(ctx context.Context) error {
	var err error

	// Запускаем WebSocket сервер
	wsErrCh := make(chan error, 1)
	go func() {
		log.Println("Starting WebSocket server...")
		if err := s.wsServer.Start(ctx); err != nil && err != context.Canceled {
			log.Printf("WebSocket server error: %v", err)
			wsErrCh <- err
		}
	}()

	// Запускаем сборщик метрик в отдельной горутине
	if s.config.MetricsInterval > 0 {
		go s.metricsCollector.Start(s.ctx)
	}

	// Запускаем сборщик медиа в отдельной горутине
	if s.config.MediasInterval > 0 {
		go s.mediaCollector.Start(s.ctx)
	}

	// Ожидаем сигнала завершения или ошибки
	select {
	case <-ctx.Done():
		return s.Shutdown()
	case err = <-wsErrCh:
		return err
	}
}

// Shutdown зупиняє сервер
func (s *Server) Shutdown() error {
	log.Println("Shutting down Linqora server...")

	// Скасовуємо контекст, щоб всі компоненти отримали сигнал про зупинку
	s.cancel()
	return nil
}

// GetConfig повертає конфігурацію сервера
func (s *Server) GetConfig() *config.ServerConfig {
	return s.config
}
