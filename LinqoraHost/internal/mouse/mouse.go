package mouse

// MouseAction identifies a mouse operation.
type MouseAction int

const (
	ActionMove        MouseAction = 0
	ActionLeftClick   MouseAction = 1
	ActionRightClick  MouseAction = 2
	ActionMiddleClick MouseAction = 3
	ActionScroll      MouseAction = 4
	ActionDoubleClick MouseAction = 5
)

// MouseCommand is the payload received from the client.
type MouseCommand struct {
	Action MouseAction `json:"action"`
	DX     int         `json:"dx"`    // relative pixels for ActionMove
	DY     int         `json:"dy"`    // relative pixels for ActionMove
	Delta  int         `json:"delta"` // notches for ActionScroll (positive = up)
}

// HandleMouseCommand dispatches a mouse command to the platform implementation.
func HandleMouseCommand(cmd MouseCommand) error {
	return platformHandleMouse(cmd)
}
