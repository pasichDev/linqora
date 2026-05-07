package main

import (
	"context"
	"fmt"
	"image/color"
	"log/slog"
	"sync"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/deviceinfo"
)

// ─────────────────────── log writer ───────────────────────

type guiLogWriter struct {
	text *widget.Entry
}

// Write appends the log line to the GUI log entry on the main goroutine.
// fyne.Do runs f directly if already on the main goroutine, so it is
// safe to call from any goroutine including UI event handlers.
func (w *guiLogWriter) Write(p []byte) (n int, err error) {
	s := string(p)
	fyne.Do(func() {
		cur := w.text.Text
		if len(cur) > 60_000 {
			cur = cur[len(cur)-50_000:] // trim old entries
		}
		w.text.SetText(cur + s)
	})
	return len(p), nil
}

// ─────────────────────── server state ───────────────────────

var (
	guiRunning  bool
	guiCancel   context.CancelFunc
	guiCancelMu sync.Mutex
)

var (
	colGreen  = color.RGBA{R: 40, G: 200, B: 80, A: 255}
	colRed    = color.RGBA{R: 210, G: 55, B: 55, A: 255}
	colOrange = color.RGBA{R: 200, G: 140, B: 40, A: 255}
)

// ─────────────────────── auth watcher ───────────────────────

// watchAuth listens on authChan for manual approval requests and shows a
// confirm dialog for each. Exits when the server stops (stopCh is closed).
func watchAuth(win fyne.Window) {
	ch := authChan
	stop := stopCh
	for {
		select {
		case req, ok := <-ch:
			if !ok {
				return
			}
			r := req
			msg := fmt.Sprintf(
				"New device wants to connect\n\nName:  %s\nID:      %s\nIP:       %s\n\nApprove?",
				r.DeviceName, r.DeviceID, r.IP,
			)
			fyne.Do(func() {
				dialog.ShowConfirm("Connection Request", msg, func(approved bool) {
					authManager.RespondToAuthRequest(r.DeviceID, approved)
				}, win)
			})
		case <-stop:
			return
		}
	}
}

// ─────────────────────── server tab ───────────────────────

func buildServerTab(win fyne.Window) fyne.CanvasObject {
	info := deviceinfo.GetDeviceInfo()

	statusDot := canvas.NewText("⬤  Stopped", colRed)
	statusDot.TextStyle = fyne.TextStyle{Bold: true}
	statusDot.TextSize = 22

	ipLbl := widget.NewLabel("IP:      " + info.IP)
	portLbl := widget.NewLabel(fmt.Sprintf("Port:    %d", cfg.Port))
	tlsStr := "disabled"
	if cfg.EnableTLS {
		tlsStr = "enabled"
	}
	tlsLbl := widget.NewLabel("TLS:    " + tlsStr)

	infoCard := widget.NewCard("", "", container.NewVBox(ipLbl, portLbl, tlsLbl))

	var toggleBtn *widget.Button
	toggleBtn = widget.NewButton("Start Server", func() {
		guiCancelMu.Lock()
		running := guiRunning
		guiCancelMu.Unlock()

		if running {
			// Stop runs in a goroutine so the UI stays responsive.
			statusDot.Color = colOrange
			statusDot.Text = "⬤  Stopping…"
			statusDot.Refresh()
			toggleBtn.SetText("Stopping…")
			toggleBtn.Disable()

			guiCancelMu.Lock()
			cancel := guiCancel
			guiCancel = nil
			guiRunning = false
			guiCancelMu.Unlock()

			go func() {
				StopServer(cancel)
				fyne.Do(func() {
					statusDot.Color = colRed
					statusDot.Text = "⬤  Stopped"
					statusDot.Refresh()
					portLbl.SetText(fmt.Sprintf("Port:    %d", cfg.Port))
					toggleBtn.SetText("Start Server")
					toggleBtn.Enable()
				})
			}()
		} else {
			cancel, err := StartServerBackground(func(_ bool, ip string, port int) {
				fyne.Do(func() {
					statusDot.Color = colGreen
					statusDot.Text = "⬤  Running"
					statusDot.Refresh()
					ipLbl.SetText("IP:      " + ip)
					portLbl.SetText(fmt.Sprintf("Port:    %d", port))
					ts := "disabled"
					if cfg.EnableTLS {
						ts = "enabled"
					}
					tlsLbl.SetText("TLS:    " + ts)
					toggleBtn.SetText("Stop Server")
				})
			})
			if err != nil {
				dialog.ShowError(err, win)
				return
			}
			guiCancelMu.Lock()
			guiCancel = cancel
			guiRunning = true
			guiCancelMu.Unlock()

			go watchAuth(win)
		}
	})
	toggleBtn.Importance = widget.HighImportance

	return container.NewPadded(container.NewVBox(
		container.NewCenter(statusDot),
		widget.NewSeparator(),
		infoCard,
		container.NewPadded(toggleBtn),
	))
}

// ─────────────────────── devices tab ───────────────────────

func buildDevicesTab() fyne.CanvasObject {
	var ids []string
	rebuild := func() {
		ids = ids[:0]
		for id := range cfg.AuthorizedDevs {
			ids = append(ids, id)
		}
	}
	rebuild()

	var list *widget.List
	sel := -1

	list = widget.NewList(
		func() int { return len(ids) },
		func() fyne.CanvasObject { return widget.NewLabel("") },
		func(i widget.ListItemID, obj fyne.CanvasObject) {
			lbl := obj.(*widget.Label)
			if i >= len(ids) {
				lbl.SetText("")
				return
			}
			d := cfg.AuthorizedDevs[ids[i]]
			lbl.SetText(fmt.Sprintf("%s  ·  last: %s", d.DeviceName, d.LastAuth))
		},
	)
	list.OnSelected = func(i widget.ListItemID) { sel = i }
	list.OnUnselected = func(_ widget.ListItemID) { sel = -1 }

	revokeBtn := widget.NewButtonWithIcon("Revoke Selected", theme.DeleteIcon(), func() {
		if sel < 0 || sel >= len(ids) {
			return
		}
		delete(cfg.AuthorizedDevs, ids[sel])
		cfg.SaveConfig()
		rebuild()
		sel = -1
		list.Refresh()
	})
	revokeBtn.Importance = widget.DangerImportance

	refreshBtn := widget.NewButtonWithIcon("Refresh", theme.ViewRefreshIcon(), func() {
		if loaded, err := config.LoadConfig(); err == nil {
			cfg = loaded
		}
		rebuild()
		list.Refresh()
	})

	return container.NewBorder(
		nil,
		container.NewHBox(revokeBtn, refreshBtn),
		nil, nil,
		list,
	)
}

// ─────────────────────── settings tab ───────────────────────

func buildSettingsTab() fyne.CanvasObject {
	portEntry := widget.NewEntry()
	portEntry.SetText(fmt.Sprintf("%d", cfg.Port))

	tlsCheck := widget.NewCheck("Enable TLS", nil)
	tlsCheck.SetChecked(cfg.EnableTLS)

	secretEntry := widget.NewPasswordEntry()
	secretEntry.SetText(cfg.SharedSecret)
	secretEntry.SetPlaceHolder("leave blank to disable")

	e2eeCheck := widget.NewCheck("Enable E2EE", nil)
	e2eeCheck.SetChecked(cfg.EnableE2EE)

	statusLbl := widget.NewLabel("")

	form := widget.NewForm(
		widget.NewFormItem("Port", portEntry),
		widget.NewFormItem("", tlsCheck),
		widget.NewFormItem("Shared Secret", secretEntry),
		widget.NewFormItem("", e2eeCheck),
	)

	saveBtn := widget.NewButtonWithIcon("Save Settings", theme.DocumentSaveIcon(), func() {
		var p int
		if _, err := fmt.Sscanf(portEntry.Text, "%d", &p); err != nil || p < 1 || p > 65535 {
			statusLbl.SetText("⚠  Invalid port value")
			return
		}
		cfg.Port = p
		cfg.EnableTLS = tlsCheck.Checked
		cfg.SharedSecret = secretEntry.Text
		cfg.EnableE2EE = e2eeCheck.Checked
		if err := cfg.SaveConfig(); err != nil {
			statusLbl.SetText("⚠  Save failed: " + err.Error())
			return
		}
		statusLbl.SetText("✓  Saved")
	})
	saveBtn.Importance = widget.HighImportance

	return container.NewPadded(container.NewVBox(
		form,
		widget.NewSeparator(),
		saveBtn,
		statusLbl,
	))
}

// ─────────────────────── log tab ───────────────────────

func buildLogTab() (fyne.CanvasObject, *guiLogWriter) {
	logEntry := widget.NewMultiLineEntry()
	logEntry.SetMinRowsVisible(18)
	logEntry.Wrapping = fyne.TextWrapWord
	logEntry.Disable()

	w := &guiLogWriter{text: logEntry}

	clearBtn := widget.NewButtonWithIcon("Clear", theme.DeleteIcon(), func() {
		// SetText works on disabled entries; Enable/Disable not needed.
		logEntry.SetText("")
	})

	return container.NewBorder(nil, clearBtn, nil, nil, container.NewScroll(logEntry)), w
}

// ─────────────────────── entry point ───────────────────────

func RunGUI() {
	hideConsole() // detach from terminal — no black console window

	var err error
	cfg, err = config.LoadConfig()
	if err != nil {
		cfg = config.DefaultConfig()
	}

	a := app.NewWithID("io.linqora.host")
	w := a.NewWindow("Linqora Host")
	w.Resize(fyne.NewSize(680, 520))

	logContent, logWriter := buildLogTab()

	// GUI mode: log only to the in-app log pane, not stderr.
	slog.SetDefault(slog.New(slog.NewTextHandler(
		logWriter,
		&slog.HandlerOptions{Level: slog.LevelInfo},
	)))

	tabs := container.NewAppTabs(
		container.NewTabItem("Server", buildServerTab(w)),
		container.NewTabItem("Devices", buildDevicesTab()),
		container.NewTabItem("Settings", buildSettingsTab()),
		container.NewTabItem("Log", logContent),
	)
	tabs.SetTabLocation(container.TabLocationTop)
	w.SetContent(tabs)

	if deskApp, ok := a.(desktop.App); ok {
		deskApp.SetSystemTrayMenu(fyne.NewMenu("Linqora Host",
			fyne.NewMenuItem("Show", func() { w.Show() }),
			fyne.NewMenuItemSeparator(),
			fyne.NewMenuItem("Quit", func() {
				guiCancelMu.Lock()
				if guiRunning && guiCancel != nil {
					go StopServer(guiCancel)
				}
				guiCancelMu.Unlock()
				a.Quit()
			}),
		))
	}

	w.SetCloseIntercept(func() { w.Hide() })
	w.ShowAndRun()
}
