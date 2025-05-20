package LinqoraHost

import (
	"LinqoraHost/systeminfo"
	"context"
	"net/http"
)

type App struct {
	ctx        context.Context
	httpServer *http.Server
	shutdownCh chan struct{}
}

func NewApp() *App {
	app := &App{
		shutdownCh: make(chan struct{}),
	}

	return app
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

}

func (a *App) beforeClose(ctx context.Context) (prevent bool) {
	defer a.close()
	return false
}

func (a *App) close() {
	println("App is closing...")

	println("App closed successfully.")
}

func (a *App) FetchSystemInfo() (systeminfo.SystemInfoInitial, error) {
	return systeminfo.GetSystemInfo()
}
