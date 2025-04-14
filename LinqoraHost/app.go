package main

import (
	"context"
	"fmt"
	"math"
	"path/filepath"
	"strings"

	"github.com/jaypipes/ghw"
	"github.com/shirou/gopsutil/disk"
)

// App struct
type App struct {
	ctx context.Context
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// beforeClose is called when the application is about to quit,
// either by clicking the window close button or calling runtime.Quit.
// Returning true will cause the application to continue, false will continue shutdown as normal.
func (a *App) beforeClose(ctx context.Context) (prevent bool) {
	defer a.close()
	return false
}

func (a *App) close() {
	// Додати очистку даних бд тощо
	println("App is closing...")
}

type SystemDiskInfo struct {
	TotalSpace float64 `json:"total_space"`
	UsageSpace float64 `json:"usage_space"`
	ModelDisk  string  `json:"model_disk"`
	TypeDisk   string  `json:"type_disk"`
}

func extractDiskBaseName(device string) string {
	base := filepath.Base(device)

	// Для NVMe (наприклад: nvme0n1p1 → nvme0n1)
	if strings.HasPrefix(base, "nvme") {
		if idx := strings.Index(base, "p"); idx != -1 {
			return base[:idx]
		}
	}

	// Для звичайних (наприклад: sda1 → sda)
	return strings.TrimRightFunc(base, func(r rune) bool {
		return r >= '0' && r <= '9'
	})
}

func (a *App) GetSystemDisk() (SystemDiskInfo, error) {

	partitions, err := disk.Partitions(false)
	if err != nil {
		return SystemDiskInfo{}, err
	}

	var systemDevice string
	for _, p := range partitions {
		if p.Mountpoint == "/" {
			systemDevice = p.Device
			break
		}
	}

	if systemDevice == "" {
		return SystemDiskInfo{}, fmt.Errorf("System device not found")
	}

	// Витягуємо базове ім’я диску (sda, nvme0n1 і т.д.)
	deviceBase := extractDiskBaseName(systemDevice)

	// Отримуємо інформацію про диск
	block, err := ghw.Block()
	if err != nil {
		return SystemDiskInfo{}, err
	}

	var model, diskType string
	for _, d := range block.Disks {
		if d.Name == deviceBase {
			model = d.Model

			switch d.DriveType.String() {
			case "SSD":
				if d.StorageController.String() == "NVMe" {
					diskType = "SSD (NVMe)"
				} else {
					diskType = "SSD (SATA)"
				}

			default:
				diskType = fmt.Sprintf("%s ", d.DriveType.String())
			}
			break
		}
	}

	if model == "" {
		model = "Unkown"
	}
	if diskType == "" {
		diskType = "Unkown"
	}

	// Отримуємо використання простору
	usage, err := disk.Usage("/")
	if err != nil {
		return SystemDiskInfo{}, err
	}

	info := SystemDiskInfo{
		TotalSpace: math.Round((float64(usage.Total)/1024/1024/1024)*100) / 100, // GB
		UsageSpace: math.Round((float64(usage.Used)/1024/1024/1024)*100) / 100,  // GB
		ModelDisk:  model,
		TypeDisk:   diskType,
	}

	return info, nil
}
