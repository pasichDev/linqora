package media

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"syscall"

	"golang.org/x/sys/windows"
)

// Virtual-key codes for media and volume keys.
const (
	vkMediaPlayPause = 0xB3
	vkMediaNextTrack = 0xB0
	vkMediaPrevTrack = 0xB1
	vkVolumeMute     = 0xAD
	vkVolumeDown     = 0xAE
	vkVolumeUp       = 0xAF

	keyeventfKeyup = 0x0002
)

var (
	modUser32      = windows.NewLazySystemDLL("user32.dll")
	procKeybdEvent = modUser32.NewProc("keybd_event")
)

// platformHandleMedia executes media and audio commands.
func platformHandleMedia(command MediaCommand) error {
	switch command.Action {
	case MediaPlayPause:
		return sendMediaKey(vkMediaPlayPause)
	case MediaNext:
		return sendMediaKey(vkMediaNextTrack)
	case MediaPrevious:
		return sendMediaKey(vkMediaPrevTrack)
	case AudioMute:
		return sendMediaKey(vkVolumeMute)
	case AudioIncreaseVolume:
		return sendMediaKey(vkVolumeUp)
	case AudioDecreaseVolume:
		return sendMediaKey(vkVolumeDown)
	case AudioSetVolume:
		return setWindowsMasterVolume(command.Value)
	default:
		return fmt.Errorf("unknown media action: %d", command.Action)
	}
}

// sendMediaKey simulates a key press and release via keybd_event.
func sendMediaKey(vk byte) error {
	procKeybdEvent.Call(uintptr(vk), 0, 0, 0)
	procKeybdEvent.Call(uintptr(vk), 0, keyeventfKeyup, 0)
	return nil
}

// platformGetMediaInfo returns real media playback info using PowerShell/SMTC.
func platformGetMediaInfo() (NowPlaying, error) {
	// PowerShell script to get SMTC info (Windows 10+)
	script := `
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.IsGenericMethod })[0]

function Get-WinRT-Result($task, [type]$type) {
    $asTask = $asTaskGeneric.MakeGenericMethod($type)
    $t = $asTask.Invoke($null, @($task))
    $t.Wait()
    return $t.Result
}

[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime] | Out-Null
$managerTask = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
$manager = Get-WinRT-Result $managerTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

$session = $manager.GetCurrentSession()
if ($session) {
    $propsTask = $session.TryGetMediaPropertiesAsync()
    $props = Get-WinRT-Result $propsTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsProperties])
    $playback = $session.GetPlaybackInfo()
    
    $res = @{
        title = $props.Title
        artist = $props.Artist
        album = $props.AlbumTitle
        isPlaying = $playback.PlaybackStatus.ToString() -eq 'Playing'
        application = $session.SourceAppUserModelId
    }
    $res | ConvertTo-Json
} else {
    "{}"
}
`
	out, err := runPowerShell(script)
	if err != nil {
		return NowPlaying{}, err
	}

	var res NowPlaying
	if err := json.Unmarshal([]byte(out), &res); err != nil {
		return NowPlaying{}, nil // Return empty if no active session
	}
	return res, nil
}

// platformGetAudioCapabilities returns Windows audio capabilities.
func platformGetAudioCapabilities() (MediaCapabilities, error) {
	caps := MediaCapabilities{
		CanControlVolume: true,
		CanControlMedia:  true,
		CanGetMediaInfo:  true,
		IsMuted:          false,
	}

	vol, _ := getWindowsMasterVolume()
	caps.CurrentVolume = vol

	return caps, nil
}

// getWindowsMasterVolume reads master volume using PowerShell and COM.
func getWindowsMasterVolume() (int, error) {
	script := `
$obj = New-Object -ComObject MMDeviceEnumerator
$device = $obj.GetDefaultAudioEndpoint(0, 1)
$iid = [Guid]"5CDF2C82-1510-4914-A4AA-9C22C6702A45"
$volume = $device.Activate($iid, 3, [IntPtr]::Zero)
[int]($volume.GetMasterVolumeLevelScalar() * 100)
`
	out, err := runPowerShell(script)
	if err != nil {
		return 50, err
	}
	var vol int
	fmt.Sscanf(strings.TrimSpace(out), "%d", &vol)
	return vol, nil
}

// setWindowsMasterVolume sets master volume using PowerShell and COM.
func setWindowsMasterVolume(value int) error {
	if value < 0 {
		value = 0
	}
	if value > 100 {
		value = 100
	}

	// Format float with point for PowerShell
	fVal := float32(value) / 100.0
	script := fmt.Sprintf(`
$obj = New-Object -ComObject MMDeviceEnumerator
$device = $obj.GetDefaultAudioEndpoint(0, 1)
$iid = [Guid]"5CDF2C82-1510-4914-A4AA-9C22C6702A45"
$volume = $device.Activate($iid, 3, [IntPtr]::Zero)
$volume.SetMasterVolumeLevelScalar(%.2f, [Guid]::Empty)
`, fVal)

	_, err := runPowerShell(script)
	return err
}

// runPowerShell executes a powershell script and returns the output.
func runPowerShell(script string) (string, error) {
	cmd := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", script)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
}
