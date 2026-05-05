package media

const (
	AudioSetVolume      = 0
	AudioMute           = 1
	AudioIncreaseVolume = 2
	AudioDecreaseVolume = 3

	MediaPlayPause = 10
	MediaNext      = 12
	MediaPrevious  = 13
	MediaGetInfo   = 14
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

// GetMediaInfo returns the currently playing track. Platform implementation
// is in media_<os>.go.
func GetMediaInfo() (NowPlaying, error) {
	return platformGetMediaInfo()
}

// HandleMediaCommand dispatches a media or audio command. Platform
// implementation is in media_<os>.go.
func HandleMediaCommand(command MediaCommand) error {
	return platformHandleMedia(command)
}

// GetAudioCapabilities returns platform audio capabilities including the
// current volume level. Platform implementation is in media_<os>.go.
func GetAudioCapabilities() (MediaCapabilities, error) {
	return platformGetAudioCapabilities()
}
