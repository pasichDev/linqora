package database

type CPUMetric struct {
	Temperature float64 `json:"temperature"`
	LoadPercent float64 `json:"loadPercent"`
}

type RAMMetric struct {
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
}
