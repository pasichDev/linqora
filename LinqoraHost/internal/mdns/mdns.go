package mdns

import (
	"fmt"
	"log"
	"os"
	"strings"

	"LinqoraHost/internal/config"

	"github.com/grandcat/zeroconf"
)

const (
	MDNSType   = "linqora-"
	MDNSDomain = ".local"
)

// MDNSServer представляє mDNS сервер для виявлення в мережі
type MDNSServer struct {
	server     *zeroconf.Server
	config     *config.ServerConfig
	hostname   string
	mdnsName   string
	mdnsType   string
	mdnsDomain string
}

func NewMDNSServer(cfg *config.ServerConfig) (*MDNSServer, error) {
	hostname, err := os.Hostname()
	if err != nil {
		return nil, fmt.Errorf("failed to get hostname: %w", err)
	}

	cleanHostname := strings.ToLower(strings.ReplaceAll(hostname, " ", "_"))

	return &MDNSServer{
		config:     cfg,
		hostname:   hostname,
		mdnsName:   cleanHostname,
		mdnsType:   MDNSType,
		mdnsDomain: MDNSDomain,
	}, nil
}

// Start запускає mDNS сервер
func (s *MDNSServer) Start() error {
	port := s.config.Port

	//  Перетворюємо метадані в правильний формат для TXT записів
	txtRecords := []string{
		fmt.Sprintf("hostname=%s", s.hostname),
		fmt.Sprintf("tls=%v", s.config.EnableTLS),
	}

	// Create mDNS
	server, err := zeroconf.Register(
		s.mdnsName,
		s.mdnsType,
		s.mdnsDomain,
		port,
		txtRecords,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to register mDNS server: %w", err)
	}

	s.server = server
	log.Printf("mDNS server started as '%s.%s.%s' on port %d",
		s.mdnsName, s.mdnsType, s.mdnsDomain, port)
	return nil
}

func (s *MDNSServer) Stop() {
	if s.server != nil {
		log.Printf("Shutting down mDNS server")
		s.server.Shutdown()
	}
}

func (s *MDNSServer) GetServiceName() string {
	return s.mdnsName
}

func (s *MDNSServer) GetServiceType() string {
	return s.mdnsType
}
