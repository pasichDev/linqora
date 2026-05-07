package mdns

import (
	"fmt"
	"log/slog"
	"os"
	"strings"

	"LinqoraHost/internal/config"

	"github.com/grandcat/zeroconf"
)

const (
	MDNSType   = "_linqora"
	MDNSDomain = "local"
)

type MDNSServer struct {
	server     *zeroconf.Server
	config     *config.ServerConfig
	hostname   string
	mdnsName   string
	mdnsType   string
	mdnsDomain string
}

func NewMDNSServer(cfg *config.ServerConfig) *MDNSServer {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "linqora-host"
		slog.Warn("Failed to get hostname, using default", "err", err, "default", "linqora-host")
	}

	cleanHostname := strings.ToLower(strings.ReplaceAll(hostname, " ", "_"))

	return &MDNSServer{
		config:     cfg,
		hostname:   hostname,
		mdnsName:   cleanHostname,
		mdnsType:   MDNSType,
		mdnsDomain: MDNSDomain,
	}
}

// Start registers the mDNS service with the provided configuration.
func (s *MDNSServer) Start() error {

	// Prepare TXT records with service information
	txtRecords := []string{
		fmt.Sprintf("hostname=%s", s.hostname),
		fmt.Sprintf("tls=%v", s.config.EnableTLS),
	}

	// Create mDNS
	server, err := zeroconf.Register(
		s.mdnsName,
		s.mdnsType,
		s.mdnsDomain,
		s.config.Port,
		txtRecords,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to register mDNS server: %w", err)
	}

	s.server = server
	slog.Info("mDNS server started", "name", s.mdnsName, "type", s.mdnsType, "domain", s.mdnsDomain, "port", s.config.Port)
	return nil
}

func (s *MDNSServer) Stop() {
	if s.server != nil {
		slog.Info("Shutting down mDNS server")
		s.server.Shutdown()
	}
}

func (s *MDNSServer) GetServiceName() string {
	return s.mdnsName
}

func (s *MDNSServer) GetServiceType() string {
	return s.mdnsType
}
