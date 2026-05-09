package process

import (
	goproc "github.com/shirou/gopsutil/v4/process"
)

// ProcessInfo holds a snapshot of a single system process.
type ProcessInfo struct {
	PID    int32   `json:"pid"`
	Name   string  `json:"name"`
	CPU    float64 `json:"cpu"`
	RSS    uint64  `json:"rss"`
	Status string  `json:"status"`
}

// List returns a snapshot of all running processes on the system.
func List() ([]ProcessInfo, error) {
	procs, err := goproc.Processes()
	if err != nil {
		return nil, err
	}

	result := make([]ProcessInfo, 0, len(procs))
	for _, p := range procs {
		info := ProcessInfo{PID: p.Pid}

		if name, err := p.Name(); err == nil {
			info.Name = name
		}
		if cpu, err := p.CPUPercent(); err == nil {
			info.CPU = cpu
		}
		if mem, err := p.MemoryInfo(); err == nil && mem != nil {
			info.RSS = mem.RSS
		}
		if statuses, err := p.Status(); err == nil && len(statuses) > 0 {
			info.Status = statuses[0]
		}

		result = append(result, info)
	}

	return result, nil
}

// Kill terminates the process with the given PID.
func Kill(pid int32) error {
	p, err := goproc.NewProcess(pid)
	if err != nil {
		return err
	}
	return p.Kill()
}
