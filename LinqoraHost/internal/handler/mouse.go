package handler

import (
	"log"

	"github.com/go-vgo/robotgo"
)

const (
	MouseMove   = 0
	MouseClick  = 1
	MouseDouble = 2
	MouseRight  = 3
)

// HandleMouseCommand обрабатывает команды управления мышью
func HandleMouseCommand(x, y int, action int) {
	// Додаємо детальне логування
	beforeX, beforeY := robotgo.GetMousePos()
	log.Printf("Current mouse position: x=%d, y=%d", beforeX, beforeY)
	log.Printf("Applying delta: dx=%d, dy=%d", x, y)

	switch action {
	case MouseMove:
		newX := beforeX + x
		newY := beforeY + y
		log.Printf("Moving mouse to: x=%d, y=%d", newX, newY)
		robotgo.MoveRelative(x, y) // Використовуємо відносне переміщення

		// Перевіряємо нову позицію
		afterX, afterY := robotgo.GetMousePos()
		log.Printf("New mouse position: x=%d, y=%d", afterX, afterY)

	case MouseClick:
		log.Printf("Performing left click")
		robotgo.Click("left")

	case MouseDouble:
		log.Printf("Performing double click")
		robotgo.Click("left", true)

	case MouseRight:
		log.Printf("Performing right click")
		robotgo.Click("right")
	}
}
