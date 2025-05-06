package mdns

import (
	"context"
	"fmt"
	"log"

	"github.com/grandcat/zeroconf"

	"LinqoraHost/internal/config"
	"LinqoraHost/pkg/utils"
)

// MDNSService представляє mDNS сервіс
type MDNSService struct {
	config *config.ServerConfig
	server *zeroconf.Server
}

// NewMDNSService створює новий mDNS сервіс
func NewMDNSService(config *config.ServerConfig) *MDNSService {
	return &MDNSService{
		config: config,
	}
}

// Start запускає mDNS сервіс
func (s *MDNSService) Start(ctx context.Context) error {
	// Отримуємо локальну IP-адресу
	ip, err := utils.GetLocalIP()
	if err != nil {
		log.Printf("Error getting local IP: %v", err)
	}

	// Додаємо інформацію про IP-адресу в сервіс
	var txt []string
	if ip != "" {
		txt = append(txt, fmt.Sprintf("ip=%s", ip))
	}

	if s.config.EnableTLS {
		txt = append(txt, "tls=true")
	} else {
		txt = append(txt, "tls=false")
	}

	// Реєструємо сервіс
	server, err := zeroconf.Register(
		s.config.MDNSName,
		s.config.MDNSType,
		s.config.MDNSDomain,
		s.config.Port,
		txt,
		nil,
	)

	if err != nil {
		return fmt.Errorf("mDNS registration failed: %w", err)
	}

	s.server = server

	log.Printf("mDNS service registered: %s.%s.%s on port %d (TLS: %v)",
		s.config.MDNSName, s.config.MDNSType, s.config.MDNSDomain,
		s.config.Port, s.config.EnableTLS)

	// Очікуємо на завершення контексту
	<-ctx.Done()

	// Зупиняємо сервер
	s.Shutdown()

	return nil
}

// Shutdown зупиняє mDNS сервіс
func (s *MDNSService) Shutdown() {
	if s.server != nil {
		s.server.Shutdown()
		log.Printf("mDNS service shutdown: %s.%s.%s",
			s.config.MDNSName, s.config.MDNSType, s.config.MDNSDomain)
	}
}

// UpdateConfig оновлює конфігурацію mDNS сервісу
func (s *MDNSService) UpdateConfig(name, serviceType, domain string) {
	// Зупиняємо поточний сервер
	s.Shutdown()

	// Оновлюємо конфігурацію
	s.config.MDNSName = name
	s.config.MDNSType = serviceType
	s.config.MDNSDomain = domain

	// Запускаємо новий сервер у goroutine
	go func() {
		if err := s.Start(context.Background()); err != nil {
			log.Printf("Failed to restart mDNS service: %v", err)
		}
	}()
}
