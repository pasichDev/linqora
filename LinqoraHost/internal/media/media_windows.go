package media

import (
	"fmt"
	"log"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Virtual-key codes for media and volume keys.
const (
	vkMediaPlayPause  = 0xB3
	vkMediaNextTrack  = 0xB0
	vkMediaPrevTrack  = 0xB1
	vkVolumeMute      = 0xAD
	vkVolumeDown      = 0xAE
	vkVolumeUp        = 0xAF

	keyeventfKeyup = 0x0002
)

var (
	modUser32       = windows.NewLazySystemDLL("user32.dll")
	procKeybdEvent  = modUser32.NewProc("keybd_event")

	modWinMM              = windows.NewLazySystemDLL("winmm.dll")
	procWaveOutGetVolume  = modWinMM.NewProc("waveOutGetVolume")
	procWaveOutSetVolume  = modWinMM.NewProc("waveOutSetVolume")
)

// platformHandleMedia executes media and audio commands using Win32 API calls
// instead of the previous VBScript + WScript.Shell approach, which was fragile
// and required an extra process.
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
		return setWindowsVolume(command.Value)
	default:
		return fmt.Errorf("unknown media action: %d", command.Action)
	}
}

// sendMediaKey simulates a key press and release via keybd_event.
func sendMediaKey(vk byte) error {
	// key down
	procKeybdEvent.Call(uintptr(vk), 0, 0, 0)
	// key up
	procKeybdEvent.Call(uintptr(vk), 0, keyeventfKeyup, 0)
	log.Printf("Sent media key VK=0x%X", vk)
	return nil
}

// platformGetMediaInfo returns media playback info on Windows.
// Full SMTC integration requires Windows Runtime; returning a stub for now.
func platformGetMediaInfo() (NowPlaying, error) {
	return NowPlaying{
		IsPlaying:   false,
		Application: "Windows Media Player",
	}, nil
}

// platformGetAudioCapabilities returns Windows audio capabilities including
// the current master volume level via waveOutGetVolume.
func platformGetAudioCapabilities() (MediaCapabilities, error) {
	caps := MediaCapabilities{
		CanControlVolume: true,
		CanControlMedia:  true,
		CanGetMediaInfo:  false,
		IsMuted:          false,
	}

	vol, err := getWindowsVolume()
	if err == nil {
		caps.CurrentVolume = vol
	} else {
		caps.CurrentVolume = 50
	}

	return caps, nil
}

// getWindowsVolume reads the current master volume from winmm.dll.
// The waveOutGetVolume value is a 32-bit word: low word = left, high word = right,
// each in the range 0–0xFFFF.
func getWindowsVolume() (int, error) {
	var vol uint32
	r, _, err := procWaveOutGetVolume.Call(0, uintptr(unsafe.Pointer(&vol)))
	if r != 0 {
		return 0, fmt.Errorf("waveOutGetVolume failed: %w", err)
	}
	// Use the left channel; scale 0xFFFF → 100.
	left := int(vol & 0xFFFF)
	return left * 100 / 0xFFFF, nil
}

// setWindowsVolume sets the master volume via waveOutSetVolume.
// value must be in the range 0–100.
func setWindowsVolume(value int) error {
	if value < 0 {
		value = 0
	}
	if value > 100 {
		value = 100
	}
	scaled := uint32(value * 0xFFFF / 100)
	combined := scaled | (scaled << 16) // left + right channels identical

	r, _, err := procWaveOutSetVolume.Call(0, uintptr(combined))
	if r != 0 {
		return fmt.Errorf("waveOutSetVolume failed: %w", err)
	}
	log.Printf("Windows volume set to %d%%", value)
	return nil
}
