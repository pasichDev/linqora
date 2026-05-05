package media

import (
	"fmt"
	"log"
	"os/exec"
	"strings"
)

func platformHandleMedia(command MediaCommand) error {
	var cmd *exec.Cmd

	hasPlayerctl := exec.Command("which", "playerctl").Run() == nil

	if hasPlayerctl {
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
			return fmt.Errorf("unknown media action: %d", command.Action)
		}
	} else {
		switch command.Action {
		case MediaPlayPause:
			cmd = exec.Command("xdotool", "key", "XF86AudioPlay")
		case MediaNext:
			cmd = exec.Command("xdotool", "key", "XF86AudioNext")
		case MediaPrevious:
			cmd = exec.Command("xdotool", "key", "XF86AudioPrev")
		default:
			return fmt.Errorf("unknown media action: %d", command.Action)
		}
	}

	if err := cmd.Run(); err != nil {
		log.Printf("Linux media command error: %v", err)
		return err
	}
	return nil
}

func platformGetMediaInfo() (NowPlaying, error) {
	info := NowPlaying{IsPlaying: false}

	if output, err := exec.Command("playerctl", "status").Output(); err == nil {
		info.IsPlaying = strings.TrimSpace(string(output)) == "Playing"
	}
	if output, err := exec.Command("playerctl", "metadata", "title").Output(); err == nil {
		info.Title = strings.TrimSpace(string(output))
	}
	if output, err := exec.Command("playerctl", "metadata", "artist").Output(); err == nil {
		info.Artist = strings.TrimSpace(string(output))
	}
	if output, err := exec.Command("playerctl", "metadata", "album").Output(); err == nil {
		info.Album = strings.TrimSpace(string(output))
	}
	if output, err := exec.Command("playerctl", "-l").Output(); err == nil {
		apps := strings.Split(strings.TrimSpace(string(output)), "\n")
		if len(apps) > 0 {
			info.Application = apps[0]
		}
	}
	if output, err := exec.Command("playerctl", "position").Output(); err == nil {
		parts := strings.Split(strings.TrimSpace(string(output)), ".")
		if len(parts) > 0 {
			fmt.Sscanf(parts[0], "%d", &info.Position)
		}
	}
	if output, err := exec.Command("playerctl", "metadata", "mpris:length").Output(); err == nil {
		var dur int
		fmt.Sscanf(strings.TrimSpace(string(output)), "%d", &dur)
		info.Duration = dur / 1_000_000
	}

	return info, nil
}

func platformGetAudioCapabilities() (MediaCapabilities, error) {
	caps := MediaCapabilities{
		CanControlVolume: true,
		CanControlMedia:  exec.Command("which", "playerctl").Run() == nil,
		CurrentVolume:    50,
		IsMuted:          false,
	}
	caps.CanGetMediaInfo = caps.CanControlMedia

	if output, err := exec.Command("amixer", "sget", "Master").Output(); err == nil {
		s := string(output)
		caps.IsMuted = strings.Contains(s, "[off]")
		if strings.Contains(s, "%") {
			parts := strings.Split(s, "[")
			for _, p := range parts {
				if strings.Contains(p, "%]") {
					fmt.Sscanf(p, "%d%%]", &caps.CurrentVolume)
					break
				}
			}
		}
	}

	return caps, nil
}
