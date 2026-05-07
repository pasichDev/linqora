package deviceinfo

import (
	"net"
	"os"
	"runtime"
	"strconv"
)

// DeviceInfo provides identification and network details about the host machine.
type DeviceInfo struct {
	IP       string `json:"ip"`
	PORT     string `json:"port"`
	OS       string `json:"os"`
	Hostname string `json:"hostname"`
}

// GetDeviceInfo aggregates system information including IP, port, OS, and hostname.
func GetDeviceInfo() DeviceInfo {
	ip := getLocalIP()
	if ip == "" {
		ip = "Unknown IP"
	}

	// Default application port
	port := 8070

	osType := runtime.GOOS

	hostname, err := os.Hostname()
	if err != nil {
		hostname = "Unknown Hostname"
	}

	return DeviceInfo{
		IP:       ip,
		PORT:     strconv.Itoa(port),
		OS:       osPrettyName(osType),
		Hostname: hostname,
	}
}

// getLocalIP identifies the primary local network address, prioritizing private LAN ranges.
func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}

	var fallbackIP string

	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ip4 := ipnet.IP.To4(); ip4 != nil {
				ipStr := ip4.String()

				// Skip link-local addresses (APIPA 169.254.x.x)
				if ip4.IsLinkLocalUnicast() {
					continue
				}

				// Prefer typical private networks (Wi-Fi/Ethernet)
				if ip4.IsPrivate() {
					// Specifically prioritize 192.168.x.x and 10.x.x.x as they are most common for LAN
					if (ip4[0] == 192 && ip4[1] == 168) || ip4[0] == 10 {
						return ipStr
					}

					// Keep other private IPs (like 172.16.x.x) as fallback
					if fallbackIP == "" {
						fallbackIP = ipStr
					}
				} else if fallbackIP == "" {
					// Last resort: any non-loopback IPv4
					fallbackIP = ipStr
				}
			}
		}
	}

	return fallbackIP
}

// osPrettyName converts runtime.GOOS into a user-friendly operating system name.
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

// detectLinuxDistro attempts to read the distribution name from /etc/os-release.
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

// splitLines is a simple utility to break a string into a slice of lines.
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

// trimQuotes removes leading and trailing double quotes from a string.
func trimQuotes(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		return s[1 : len(s)-1]
	}
	return s
}
