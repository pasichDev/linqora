package main

import (
	"embed"
	"math"
	"runtime"

	"fmt"

	"github.com/jaypipes/ghw"
	"github.com/pbnjay/memory"
	"github.com/shirou/gopsutil/disk"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

//go:embed all:frontend/dist
var assets embed.FS

// SystemInfoInitial з інформацією про систему
type SystemInfoInitial struct {
	System   string  `json:"system"`
	CPU      string  `json:"cpu"`
	RAMTotal float64 `json:"ram_total"`
	RAMUsage float64 `json:"ram_usage"`
}

func (s *SystemInfoInitial) GetSystemInfo() (*SystemInfoInitial, error) {
	// ОС
	s.System = runtime.GOOS

	// CPU
	cpuInfo, err := ghw.CPU()
	if err != nil {
		return nil, err
	}
	if len(cpuInfo.Processors) > 0 {
		s.CPU = cpuInfo.Processors[0].Model
	} else {
		s.CPU = "Unknown"
	}

	// RAM
	s.RAMTotal = math.Round((float64(memory.TotalMemory())/1024/1024/1024)*100) / 100
	s.RAMUsage = math.Round((float64(memory.TotalMemory()-memory.FreeMemory())/1024/1024/1024)*100) / 100

	// Диск
	partitions, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}

	var totalSpace uint64
	var usageSpace uint64
	//	var systemDevice string

	for _, p := range partitions {

		usage, err := disk.Usage(p.Mountpoint)
		if err != nil {
			continue
		}
		totalSpace += usage.Total
		usageSpace += usage.Used
	}
	return s, nil
}
func main() {
	// Create an instance of the app structure
	app := NewApp()
	systemInfo := &SystemInfoInitial{}

	width := 400
	height := 900

	/*
		StartHidden — початково приховати вікно при запуску.
		HideWindowOnClose — приховати вікно замість його закриття.

	*/

	err := wails.Run(&options.App{
		Title:         "LinqoraHost",
		Width:         width,
		Height:        height,
		MinWidth:      width,
		MinHeight:     height,
		MaxWidth:      width,
		MaxHeight:     height,
		DisableResize: true, //заборонити зміну розміру
		Frameless:     true,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 8, G: 14, B: 23, A: 120},
		OnStartup:        app.startup,
		OnBeforeClose:    app.beforeClose,
		Bind: []interface{}{
			app,
			systemInfo,
		},
	})
	fmt.Printf("Total system memory: %d\n", memory.TotalMemory())
	fmt.Printf("Free memory: %d\n", memory.FreeMemory())
	if err != nil {
		println("Error:", err.Error())
	}
}
