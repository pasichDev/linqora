package database

type CPUMetrics struct {
	ID          int     `json:"id"`
	Timestamp   string  `json:"timestamp"`
	Temperature float64 `json:"temperature"`
	LoadPercent float64 `json:"loadPercent"`
}

type RAMMetrics struct {
	ID          int     `json:"id"`
	Timestamp   string  `json:"timestamp"`
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
}
