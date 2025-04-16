package main

import (
	"LinqoraHost/backend"
	sysModel "LinqoraHost/backend/model"
	"context"
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

func (a *App) FetchSystemInfo() (sysModel.SystemInfoInitial, error) {
	return backend.GetSystemInfo()
}
