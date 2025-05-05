package main

import (
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/metrics"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"LinqoraHost"

	"github.com/mdp/qrterminal/v3"
)

func main() {
	// Виводимо заголовок
	fmt.Println("====================================================")
	fmt.Println("                 LINQORA HOST SERVER                ")
	fmt.Println("====================================================")

	// Отримуємо системну інформацію
	deviceInfo := metrics.GetDeviceInfo()
	// Ініціалізуємо генератор випадкових чисел
	rand.Seed(time.Now().UnixNano())
	// Генеруємо число в діапазоні [100000, 999999]
	code := rand.Intn(900000) + 100000
	codeStr := strconv.Itoa(code)

	// Вивід додаткової системної інформації
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %s\n", deviceInfo.PORT)
	fmt.Printf("ОС:          %s\n", deviceInfo.OS)
	fmt.Println("═════════════════════════════════════════════════")
	fmt.Printf("КОД АВТЕНТИФІКАЦІЇ:          %s\n", codeStr)
	fmt.Println("═════════════════════════════════════════════════")
	fmt.Println()

	// Налаштування та генерація QR-коду
	qrConfig := qrterminal.Config{
		Level:     qrterminal.M,
		Writer:    os.Stdout,
		BlackChar: qrterminal.BLACK,
		WhiteChar: qrterminal.WHITE,
		QuietZone: 1,
	}
	qrterminal.GenerateWithConfig(codeStr, qrConfig)

	// Лінія-розділювач після QR-коду
	fmt.Println(strings.Repeat("─", 50))
	fmt.Println()

	// Створюємо конфігурацію сервера
	cfg := &config.ServerConfig{
		Port:       8070,
		MDNSName:   "linqora_host",
		MDNSType:   "_" + codeStr + "._tcp",
		MDNSDomain: "local.",
		ValidDeviceIDs: map[string]bool{
			codeStr: true,
		},
		MetricsInterval: 2 * 1000000000, // 2 секунди в наносекундах
	}

	// Повідомлення про підготовку до запуску
	fmt.Println("Підготовка до запуску сервера...")
	fmt.Println("Натисніть Ctrl+C для виходу")
	fmt.Println()

	// Створюємо новий сервер
	server := LinqoraHost.NewServer(cfg)

	// Обробка сигналів для коректного завершення
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	// Запускаємо сервер у goroutine
	go func() {
		if err := server.Start(); err != nil {
			log.Fatalf("Server error: %v", err)
		}
	}()

	fmt.Println(strings.Repeat("─", 50))
	fmt.Println()

	// Очікуємо на сигнал завершення
	<-sigCh
	fmt.Println("\nВимикання сервера...")

	// Зупиняємо сервер
	server.Shutdown()
	fmt.Println("Сервер зупинено")
}
