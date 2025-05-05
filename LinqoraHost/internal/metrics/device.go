package metrics

import (
	"net"
	"os"
	"runtime"
	"strconv"
)

type DeviceInfo struct {
	IP       string `json:"ip"`
	PORT     string `json:"port"`
	OS       string `json:"os"`
	Hostname string `json:"hostname"` // Ім'я хоста

}

func GetDeviceInfo() DeviceInfo {
	// Отримати IP-адресу
	ip := getLocalIP()
	if ip == "" {
		ip = "Не вдалося визначити IP"
	}

	// Припустимо, що порт відомий (наприклад, 8070)
	port := 8070

	// Отримати ОС
	osType := runtime.GOOS

	// Отримати ім'я хоста
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "Не вдалося отримати ім'я хоста"
	}

	return DeviceInfo{
		IP:       ip,
		PORT:     strconv.Itoa(port),
		OS:       osPrettyName(osType),
		Hostname: hostname,
	}
}

// Функція для визначення локальної IP-адреси
func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ip4 := ipnet.IP.To4(); ip4 != nil {
				return ip4.String()
			}
		}
	}
	return ""
}

// Невелика обгортка для покращеного відображення ОС
func osPrettyName(goos string) string {
	switch goos {
	case "linux":
		return detectLinuxDistro()
	case "windows":
		return "Windows"
	case "darwin":
		return "macOS"
	default:
		return goos
	}
}

// Для Linux можна прочитати з /etc/os-release
func detectLinuxDistro() string {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "Linux"
	}
	lines := string(data)
	for _, line := range []string{"PRETTY_NAME=", "NAME="} {
		for _, l := range splitLines(lines) {
			if len(l) > len(line) && l[:len(line)] == line {
				return trimQuotes(l[len(line):])
			}
		}
	}
	return "Linux"
}

// Допоміжні утиліти
func splitLines(s string) []string {
	var lines []string
	curr := ""
	for _, r := range s {
		if r == '\n' {
			lines = append(lines, curr)
			curr = ""
		} else {
			curr += string(r)
		}
	}
	if curr != "" {
		lines = append(lines, curr)
	}
	return lines
}

func trimQuotes(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		return s[1 : len(s)-1]
	}
	return s
}
