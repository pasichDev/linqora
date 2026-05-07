package media

import (
	"fmt"
	"os/exec"
	"strings"
)

func platformHandleMedia(command MediaCommand) error {
	var script string

	switch command.Action {
	case MediaPlayPause:
		script = `tell application "System Events" to tell (first application process whose frontmost is true) to keystroke space`
	case MediaNext:
		script = `tell application "System Events" to key code 124 using {command down}`
	case MediaPrevious:
		script = `tell application "System Events" to key code 123 using {command down}`
	case AudioSetVolume:
		script = fmt.Sprintf("set volume output volume %d", command.Value)
	case AudioMute:
		if command.Value == 1 {
			script = "set volume output muted true"
		} else {
			script = "set volume output muted false"
		}
	case AudioIncreaseVolume:
		script = `set volume output volume ((output volume of (get volume settings)) + 5)`
	case AudioDecreaseVolume:
		script = `set volume output volume ((output volume of (get volume settings)) - 5)`
	default:
		return fmt.Errorf("unknown media action: %d", command.Action)
	}

	return exec.Command("osascript", "-e", script).Run()
}

func platformGetMediaInfo() (NowPlaying, error) {
	info := NowPlaying{}

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

	output, err := exec.Command("osascript", "-e", script).Output()
	if err != nil {
		return info, err
	}

	parts := strings.Split(string(output), ", ")
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

func platformGetAudioCapabilities() (MediaCapabilities, error) {
	caps := MediaCapabilities{
		CanControlVolume: true,
		CanControlMedia:  true,
		CanGetMediaInfo:  true,
		IsMuted:          false,
		CurrentVolume:    50,
	}

	if output, err := exec.Command("osascript", "-e", "output volume of (get volume settings)").Output(); err == nil {
		fmt.Sscanf(string(output), "%d", &caps.CurrentVolume)
	}
	if output, err := exec.Command("osascript", "-e", "output muted of (get volume settings)").Output(); err == nil {
		caps.IsMuted = strings.TrimSpace(string(output)) == "true"
	}

	return caps, nil
}
