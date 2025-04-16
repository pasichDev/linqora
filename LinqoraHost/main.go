package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

var assets embed.FS

func main() {
	// Create an instance of the app structure
	app := NewApp()

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
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
