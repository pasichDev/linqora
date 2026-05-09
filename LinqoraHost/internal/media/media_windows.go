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

const volumeTypeDefinition = `
using System;
using System.Runtime.InteropServices;

[Guid("5CDF2C82-1510-4914-A4AA-9C22C6702A45"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    void _r0(); void _r1(); void _r2();
    void SetMasterVolumeLevel(float fLevelDB, ref Guid g);
    void SetMasterVolumeLevelScalar(float fLevel, ref Guid g);
    void GetMasterVolumeLevel(out float pfLevelDB);
    void GetMasterVolumeLevelScalar(out float pfLevel);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    void Activate(ref Guid iid, uint ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object ppv);
    void _skip1(); void _skip2(); void _skip3();
}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    void _skip1();
    void GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppEndpoint);
    void _skip2(); void _skip3(); void _skip4();
}
[ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorCom {}
public static class Vol {
    static IAudioEndpointVolume _ep() {
        var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDevice dev; e.GetDefaultAudioEndpoint(0,1,out dev);
        var iid = typeof(IAudioEndpointVolume).GUID;
        object o; dev.Activate(ref iid,1,IntPtr.Zero,out o);
        return (IAudioEndpointVolume)o;
    }
    public static float Get() { float v; _ep().GetMasterVolumeLevelScalar(out v); return v*100; }
    public static void Set(float pct) { var g=Guid.Empty; _ep().SetMasterVolumeLevelScalar(pct/100f,ref g); }
}
`

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

// getWindowsMasterVolume reads master volume using PowerShell with WASAPI C# inline.
func getWindowsMasterVolume() (int, error) {
	script := fmt.Sprintf(`
Add-Type -TypeDefinition @'
%s
'@ -Language CSharp -ErrorAction Stop
[int][Vol]::Get()
`, volumeTypeDefinition)
	out, err := runPowerShell(script)
	if err != nil {
		return 50, err
	}
	var vol int
	fmt.Sscanf(strings.TrimSpace(out), "%d", &vol)
	return vol, nil
}

// setWindowsMasterVolume sets master volume using PowerShell with WASAPI C# inline.
func setWindowsMasterVolume(value int) error {
	if value < 0 {
		value = 0
	}
	if value > 100 {
		value = 100
	}
	script := fmt.Sprintf(`
Add-Type -TypeDefinition @'
%s
'@ -Language CSharp -ErrorAction Stop
[Vol]::Set(%d)
`, volumeTypeDefinition, value)
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
