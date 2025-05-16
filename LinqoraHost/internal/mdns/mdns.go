package mdns

import (
	"fmt"
	"log"
	"os"
	"strings"

	"LinqoraHost/internal/config"

	"github.com/grandcat/zeroconf"
)

// MDNSServer представляет mDNS сервер для обнаружения в сети
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

	// Используем фиксированный тип сервиса для облегчения обнаружения
	mdnsType := "_linqora._tcp"

	// Создаем имя сервиса на основе хоста
	cleanHostname := strings.ToLower(strings.ReplaceAll(hostname, " ", "_"))

	return &MDNSServer{
		config:     cfg,
		hostname:   hostname,
		mdnsName:   cleanHostname,
		mdnsType:   mdnsType,
		mdnsDomain: "local.",
	}, nil
}

// Start запускает mDNS сервер
func (s *MDNSServer) Start() error {
	port := s.config.Port

	// Преобразуем метаданные в правильный формат для TXT записей
	txtRecords := []string{
		fmt.Sprintf("hostname=%s", s.hostname),
		fmt.Sprintf("tls=%v", s.config.EnableTLS),
	}

	// Создаем mDNS сервер со стандартным типом
	server, err := zeroconf.Register(
		s.mdnsName,   // Имя сервиса (например "pasich-ubuntu")
		s.mdnsType,   // Тип сервиса (фиксированный "_linqora._tcp")
		s.mdnsDomain, // Домен (фиксированный "local.")
		port,         // Порт
		txtRecords,   // Метаданные в формате ["key=value", ...]
		nil,          // Интерфейсы (nil = все)
	)
	if err != nil {
		return fmt.Errorf("failed to register mDNS server: %w", err)
	}

	s.server = server
	log.Printf("mDNS server started as '%s.%s.%s' on port %d",
		s.mdnsName, s.mdnsType, s.mdnsDomain, port)
	return nil
}

// Stop останавливает mDNS сервер
func (s *MDNSServer) Stop() {
	if s.server != nil {
		log.Printf("Shutting down mDNS server")
		s.server.Shutdown()
	}
}

// GetServiceName возвращает имя mDNS сервиса
func (s *MDNSServer) GetServiceName() string {
	return s.mdnsName
}

// GetServiceType возвращает тип mDNS сервиса
func (s *MDNSServer) GetServiceType() string {
	return s.mdnsType
}
