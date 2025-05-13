package media

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
	"strings"
)

const (

	// Типы команд аудио
	AudioSetVolume      = 0 // Установить громкость
	AudioMute           = 1 // Включить/выключить звук
	AudioIncreaseVolume = 2 // Увеличить громкость
	AudioDecreaseVolume = 3 // Уменьшить громкость

	// Типы команд мультимедиа
	MediaPlayPause = 10 // Переключение воспроизведение/пауза
	MediaNext      = 12 // Следующий трек
	MediaPrevious  = 13 // Предыдущий трек
	MediaGetInfo   = 14 // Получить информацию о текущем треке
)

type MediaCommand struct {
	Action int `json:"action"`
	Value  int `json:"value"`
}

type NowPlaying struct {
	Artist      string `json:"artist,omitempty"`
	Title       string `json:"title,omitempty"`
	Album       string `json:"album,omitempty"`
	Application string `json:"application,omitempty"`
	IsPlaying   bool   `json:"isPlaying"`
	Position    int    `json:"position"`
	Duration    int    `json:"duration"`
}

type MediaCapabilities struct {
	CanControlVolume bool `json:"canControlVolume"`
	CanControlMedia  bool `json:"canControlMedia"`
	CanGetMediaInfo  bool `json:"canGetMediaInfo"`
	CurrentVolume    int  `json:"currentVolume"`
	IsMuted          bool `json:"isMuted"`
}

/**
Реалізувати обробку команд медіа на різних ОС
**/

func GetMediaInfo() (NowPlaying, error) {

	var result NowPlaying
	var err error

	switch runtime.GOOS {
	case "linux":
		result, err = getLinuxMediaInfo()
	case "windows":
		// Получение информации о текущем треке в Windows более сложное
		// Возвращаем базовую информацию
		info := NowPlaying{
			Title:       "Неизвестно",
			Application: "Медиаплеер Windows",
			IsPlaying:   true,
		}
		return info, nil
	case "darwin":
		result, err = getMacOSMediaInfo()
	default:
		return NowPlaying{}, fmt.Errorf("неподдерживаемая ОС: %s", runtime.GOOS)
	}

	if err != nil {
		return NowPlaying{}, err
	}

	return result, nil

}

func HandleMediaCommand(command MediaCommand) error {
	var err error

	switch runtime.GOOS {
	case "linux":
		err = handleLinuxMedia(command)
	case "windows":
		err = handleWindowsMedia(command)
	case "darwin":
		err = handleMacOSMedia(command)
	default:
		return fmt.Errorf("неподдерживаемая ОС: %s", runtime.GOOS)
	}

	if err != nil {
		return err
	}

	return nil
}

// Обработка медиа команд на Linux
func handleLinuxMedia(command MediaCommand) error {
	var cmd *exec.Cmd

	// Проверяем наличие playerctl
	hasPlayerctl := exec.Command("which", "playerctl").Run() == nil

	if hasPlayerctl {
		// Используем playerctl для управления медиаплеерами
		switch command.Action {
		case AudioSetVolume:
			cmd = exec.Command("amixer", "set", "Master", fmt.Sprintf("%d%%", command.Value))
		case AudioMute:
			if command.Value == 1 {
				cmd = exec.Command("amixer", "set", "Master", "mute")
			} else {
				cmd = exec.Command("amixer", "set", "Master", "unmute")
			}
		case AudioIncreaseVolume:
			cmd = exec.Command("amixer", "set", "Master", "5%+")
		case AudioDecreaseVolume:
			cmd = exec.Command("amixer", "set", "Master", "5%-")
		case MediaPlayPause:
			cmd = exec.Command("playerctl", "play-pause")
		case MediaNext:
			cmd = exec.Command("playerctl", "next")
		case MediaPrevious:
			cmd = exec.Command("playerctl", "previous")

		default:
			return fmt.Errorf("неизвестное медиа действие: %d", command.Action)
		}

		err := cmd.Run()
		if err != nil {
			log.Printf("Ошибка выполнения playerctl: %v", err)
			return err
		}
	} else {
		// Используем xdotool для эмуляции клавиш
		switch command.Action {
		case MediaPlayPause:
			cmd = exec.Command("xdotool", "key", "XF86AudioPlay")
		case MediaNext:
			cmd = exec.Command("xdotool", "key", "XF86AudioNext")
		case MediaPrevious:
			cmd = exec.Command("xdotool", "key", "XF86AudioPrev")
		default:
			return fmt.Errorf("неизвестное медиа действие: %d", command.Action)
		}

		err := cmd.Run()
		if err != nil {
			log.Printf("Ошибка выполнения xdotool: %v", err)
			return err
		}
	}

	return nil
}

// Обработка медиа команд на Windows
func handleWindowsMedia(command MediaCommand) error {
	script := ""

	switch command.Action {
	case MediaPlayPause:
		script = `Set objShell = CreateObject("WScript.Shell") : objShell.SendKeys(chr(179))`

	case MediaNext:
		script = `Set objShell = CreateObject("WScript.Shell") : objShell.SendKeys(chr(176))`
	case MediaPrevious:
		script = `Set objShell = CreateObject("WScript.Shell") : objShell.SendKeys(chr(177))`

	default:
		return fmt.Errorf("неизвестное медиа действие: %d", command.Action)
	}

	// Создаем временный VBS скрипт
	cmd := exec.Command("cmd", "/c", "echo "+script+" > %TEMP%\\media.vbs && cscript //nologo %TEMP%\\media.vbs")
	return cmd.Run()
}

// Обработка медиа команд на macOS
func handleMacOSMedia(command MediaCommand) error {
	var script string

	switch command.Action {
	case MediaPlayPause:
		script = `tell application "System Events" to tell (first application process whose frontmost is true) to keystroke space`
	case MediaNext:
		script = `tell application "System Events" to key code 124 using {command down}` // Cmd + Right Arrow
	case MediaPrevious:
		script = `tell application "System Events" to key code 123 using {command down}` // Cmd + Left Arrow

	default:
		return fmt.Errorf("неизвестное медиа действие: %d", command.Action)
	}

	cmd := exec.Command("osascript", "-e", script)
	return cmd.Run()
}

// getLinuxMediaInfo получает информацию о текущем треке на Linux
func getLinuxMediaInfo() (NowPlaying, error) {
	info := NowPlaying{
		IsPlaying: false,
		Position:  0,
		Duration:  0,
	}

	// Получаем статус воспроизведения
	statusCmd := exec.Command("playerctl", "status")
	statusOutput, err := statusCmd.Output()
	if err == nil {
		status := strings.TrimSpace(string(statusOutput))
		info.IsPlaying = status == "Playing"
	}

	// Получаем название
	titleCmd := exec.Command("playerctl", "metadata", "title")
	titleOutput, err := titleCmd.Output()
	if err == nil {
		info.Title = strings.TrimSpace(string(titleOutput))
	}

	// Получаем исполнителя
	artistCmd := exec.Command("playerctl", "metadata", "artist")
	artistOutput, err := artistCmd.Output()
	if err == nil {
		info.Artist = strings.TrimSpace(string(artistOutput))
	}

	// Получаем альбом
	albumCmd := exec.Command("playerctl", "metadata", "album")
	albumOutput, err := albumCmd.Output()
	if err == nil {
		info.Album = strings.TrimSpace(string(albumOutput))
	}

	// Получаем название приложения
	appCmd := exec.Command("playerctl", "-l")
	appOutput, err := appCmd.Output()
	if err == nil {
		apps := strings.Split(strings.TrimSpace(string(appOutput)), "\n")
		if len(apps) > 0 {
			info.Application = apps[0]
		}
	}

	// Получаем позицию
	posCmd := exec.Command("playerctl", "position")
	posOutput, err := posCmd.Output()
	if err == nil {
		posStr := strings.TrimSpace(string(posOutput))
		parts := strings.Split(posStr, ".")
		if len(parts) > 0 {
			fmt.Sscanf(parts[0], "%d", &info.Position)
		}
	}

	// Получаем длительность
	durCmd := exec.Command("playerctl", "metadata", "mpris:length")
	durOutput, err := durCmd.Output()
	if err == nil {
		durStr := strings.TrimSpace(string(durOutput))
		durNum := 0
		fmt.Sscanf(durStr, "%d", &durNum)
		info.Duration = durNum / 1000000 // микросекунды в секунды
	}

	return info, nil
}

// getMacOSMediaInfo получает информацию о текущем треке на macOS
func getMacOSMediaInfo() (NowPlaying, error) {
	info := NowPlaying{
		IsPlaying: false,
		Position:  0,
		Duration:  0,
	}

	// Проверяем iTunes/Music
	script := `
        try
            tell application "Music"
                set trackInfo to {name of current track, artist of current track, album of current track, player state, player position, duration of current track}
                return trackInfo
            end tell
        on error
            try
                tell application "iTunes"
                    set trackInfo to {name of current track, artist of current track, album of current track, player state, player position, duration of current track}
                    return trackInfo
                end tell
            on error
                return {"Unknown", "Unknown", "Unknown", "stopped", 0, 0}
            end try
        end try
    `

	cmd := exec.Command("osascript", "-e", script)
	output, err := cmd.Output()
	if err != nil {
		return info, err
	}

	// Парсим вывод
	outputStr := string(output)
	parts := strings.Split(outputStr, ", ")

	if len(parts) >= 6 {
		info.Title = strings.Trim(parts[0], "{\"")
		info.Artist = parts[1]
		info.Album = parts[2]
		info.IsPlaying = strings.Contains(parts[3], "play")
		info.Application = "Music/iTunes"

		fmt.Sscanf(parts[4], "%d", &info.Position)
		fmt.Sscanf(parts[5], "%d", &info.Duration)
	}

	return info, nil
}

// GetAudioCapabilities возвращает информацию о доступных возможностях управления звуком/медиа
func GetAudioCapabilities() (MediaCapabilities, error) {
	caps := MediaCapabilities{
		CanControlVolume: true,  //  Керування гучністю
		CanControlMedia:  false, // Керування медіаплеєром
		CurrentVolume:    50,    // Текущая громкость (по умолчанию 50)
		IsMuted:          false, // Звук выключен (по умолчанию false)
	}

	// Проверяем возможность управления медиа
	switch runtime.GOOS {
	case "linux":
		// Проверяем наличие playerctl для управления медиаплеерами
		caps.CanControlMedia = exec.Command("which", "playerctl").Run() == nil
		caps.CanGetMediaInfo = caps.CanControlMedia

		// Получаем текущую громкость через amixer
		volumeCmd := exec.Command("amixer", "sget", "Master")
		volumeOut, err := volumeCmd.Output()
		if err == nil {
			volumeStr := string(volumeOut)

			// Проверка на mute
			caps.IsMuted = strings.Contains(volumeStr, "[off]")

			// Извлекаем громкость используя регулярное выражение
			if strings.Contains(volumeStr, "%") {
				volumeParts := strings.Split(volumeStr, "[")
				for _, part := range volumeParts {
					if strings.Contains(part, "%]") {
						var volume int
						fmt.Sscanf(part, "%d%%]", &volume)
						caps.CurrentVolume = volume
						break
					}
				}
			}
		}

	case "windows":
		caps.CanControlMedia = true  // На Windows эмулируем клавиши через SendKeys
		caps.CanGetMediaInfo = false // Сложно получать информацию без специальных инструментов

	case "darwin":
		caps.CanControlMedia = true
		caps.CanGetMediaInfo = true

		// Получаем текущую громкость
		volumeCmd := exec.Command("osascript", "-e", "output volume of (get volume settings)")
		volumeOut, err := volumeCmd.Output()
		if err == nil {
			var volume int
			fmt.Sscanf(string(volumeOut), "%d", &volume)
			caps.CurrentVolume = volume
		}

		// Проверяем состояние mute
		muteCmd := exec.Command("osascript", "-e", "output muted of (get volume settings)")
		muteOut, err := muteCmd.Output()
		if err == nil {
			caps.IsMuted = strings.TrimSpace(string(muteOut)) == "true"
		}
	}

	return caps, nil
}
