package LinqoraHost

import (
	"context"
	"log"

	"LinqoraHost/internal/auth"
	"LinqoraHost/internal/config"
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
	metricsCollector *metrics.MetricsCollector
	mediaCollector   *media.MediaCollector
}

// Create a new Server instance
func NewServer(cfg *config.ServerConfig, authManager *auth.AuthManager) *Server {
	if cfg == nil {
		cfg = config.DefaultConfig()
	}

	ctx, cancel := context.WithCancel(context.Background())

	wsServer := ws.NewWSServer(cfg, authManager)

	// Create metrics and media collectors
	metricsCollector := metrics.NewMetricsCollector(wsServer.BroadcastMetrics)
	mediaCollector := media.NewMediaCollector(wsServer.BroadcastMedia)

	return &Server{
		ctx:              ctx,
		cancel:           cancel,
		config:           cfg,
		wsServer:         wsServer,
		metricsCollector: metricsCollector,
		mediaCollector:   mediaCollector,
	}
}

func (s *Server) Start(ctx context.Context) error {
	var err error

	// Start the WebSocket server in a goroutine
	wsErrCh := make(chan error, 1)
	go func() {
		log.Println("Starting WebSocket server...")
		if err := s.wsServer.Start(ctx); err != nil && err != context.Canceled {
			log.Printf("WebSocket server error: %v", err)
			wsErrCh <- err
		}
	}()

	go s.metricsCollector.Start(s.ctx)
	go s.mediaCollector.Start(s.ctx)

	select {
	case <-ctx.Done():
		return s.Shutdown()
	case err = <-wsErrCh:
		return err
	}
}

// Shutdown runs the shutdown process for the server
func (s *Server) Shutdown() error {
	log.Println("Shutting down Linqora server...")

	s.cancel()
	return nil
}
