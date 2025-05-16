package mdns

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/user"
	"strings"

	"LinqoraHost/internal/config"

	"github.com/grandcat/zeroconf"
)

// MDNSServer представляет mDNS сервер для обнаружения в сети
type MDNSServer struct {
	server     *zeroconf.Server
	config     *config.ServerConfig
	hostname   string
	username   string
	mdnsName   string
	mdnsType   string
	mdnsDomain string
}

func NewMDNSServer(cfg *config.ServerConfig) (*MDNSServer, error) {
	// Получаем информацию о системе для идентификации хоста
	hostname, err := os.Hostname()
	if err != nil {
		return nil, fmt.Errorf("failed to get hostname: %w", err)
	}

	currentUser, err := user.Current()
	username := "unknown"
	if err == nil {
		username = currentUser.Username
	}

	// Используем фиксированный тип сервиса для облегчения обнаружения
	mdnsType := "_linqora._tcp"

	// Создаем имя сервиса на основе пользователя и хоста
	cleanUsername := strings.ToLower(strings.ReplaceAll(username, " ", "_"))
	cleanHostname := strings.ToLower(strings.ReplaceAll(hostname, " ", "_"))
	mdnsName := fmt.Sprintf("%s-%s", cleanUsername, cleanHostname)

	return &MDNSServer{
		config:     cfg,
		hostname:   hostname,
		username:   username,
		mdnsName:   mdnsName,
		mdnsType:   mdnsType,
		mdnsDomain: cfg.MDNSDomain,
	}, nil
}

// Start запускает mDNS сервер
func (s *MDNSServer) Start() error {
	port := s.config.Port

	// Получить текущий IP адрес
	ip, err := getOutboundIP()
	if err != nil {
		log.Printf("Warning: could not determine outbound IP: %v", err)
	}

	// Преобразуем метаданные в правильный формат для TXT записей
	txtRecords := []string{
		fmt.Sprintf("hostname=%s", s.hostname),
		fmt.Sprintf("os=%s", fmt.Sprintf("%s %s", os.Getenv("DESKTOP_SESSION"), os.Getenv("XDG_CURRENT_DESKTOP"))),
		fmt.Sprintf("ip=%s", ip.String()),
		fmt.Sprintf("tls=%v", s.config.EnableTLS),
		fmt.Sprintf("username=%s", s.username),
	}

	// Создаем mDNS сервер со стандартным типом
	server, err := zeroconf.Register(
		s.mdnsName,   // Имя сервиса (например "pasich-ubuntu")
		s.mdnsType,   // Тип сервиса (фиксированный "_linqora._tcp")
		s.mdnsDomain, // Домен (обычно "local.")
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

// getOutboundIP определяет IP адрес для исходящих подключений
func getOutboundIP() (net.IP, error) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP, nil
}
