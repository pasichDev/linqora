package auth

import (
	"encoding/json"
	"log"
	"os"
	"runtime"
	"time"

	"LinqoraHost/internal/interfaces"
)

type AuthResponse struct {
	Type      string `json:"type"`
	Success   bool   `json:"success"`
	Code      int    `json:"codeResponse"`
	Descripte string `json:"data"`
}

// AuthResponseWithData структура ответа с дополнительными данными
type AuthResponseWithData struct {
	Type      string      `json:"type"`
	Success   bool        `json:"success"`
	Code      int         `json:"codeResponse"`
	Descripte string      `json:"data"`
	Extra     interface{} `json:"extra"`
}

// AuthRequestData представляет данные запроса авторизации
type AuthRequestData struct {
	DeviceID   string `json:"deviceId"`
	DeviceName string `json:"deviceName"`
	IP         string `json:"ip"`
}

// AuthResponseData представляет данные ответа авторизации
type AuthResponseData struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}
type SystemInfo struct {
	Hostname string `json:"hostname"`
	OS       string `json:"os"`
}

// getSystemInfo возвращает информацию о системе
func getSystemInfo() SystemInfo {
	hostname, _ := os.Hostname()
	return SystemInfo{
		Hostname: hostname,
		OS:       runtime.GOOS,
	}
}

// HandleAuthRequest обрабатывает запрос авторизации от клиента
func (am *AuthManager) HandleAuthRequest(client interfaces.WSClient, msg interfaces.WSMessage) {
	log.Printf("Processing auth request from %s", client.GetIP())

	var authData AuthRequestData
	if err := json.Unmarshal(msg.GetData(), &authData); err != nil {
		log.Printf("Error unmarshaling auth data: %v", err)
		sendErrorResponse(client, AuthStatusInvalidFormat)
		return
	}

	deviceID := authData.DeviceID
	if deviceID == "" {
		log.Printf("Empty device ID in auth request")
		sendErrorResponse(client, AuthStatusMissingDeviceID)
		return
	}

	log.Printf("Auth request from device %s (%s) at IP %s",
		authData.DeviceName, deviceID, client.GetIP())

	// Проверяем, авторизовано ли устройство
	if am.IsAuthorized(deviceID) {
		log.Printf("Device %s already authorized", authData.DeviceName)
		client.SetDeviceID(deviceID)
		client.SetDeviceName(authData.DeviceName)

		// Отправляем успешный ответ с информацией о хосте
		hostInfo := getSystemInfo()
		sendSuccessResponseWithData(client, AuthStatusAuthorized, hostInfo)
		return
	}

	// Запрашиваем авторизацию
	pending := am.RequestAuthorization(authData.DeviceName, deviceID, client.GetIP())
	if pending {
		// Сохраняем DeviceID для будущей проверки
		client.SetDeviceID(deviceID)
		client.SetDeviceName(authData.DeviceName)

		// Отправляем сообщение, что запрос на авторизацию отправлен
		sendPendingResponse(client, AuthStatusPending)

		// Запускаем фоновую проверку результата
		go am.checkAuthResultPeriodically(client)
		log.Printf("Auth request for %s is pending", authData.DeviceName)
	} else {
		sendErrorResponse(client, AuthStatusRequestFailed)
		log.Printf("Failed to request auth for %s", authData.DeviceName)
	}
}

// Метод для периодической проверки статуса авторизации
func (am *AuthManager) checkAuthResultPeriodically(client interfaces.WSClient) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	timeout := time.After(30 * time.Second)

	for {
		select {
		case <-ticker.C:
			deviceID := client.GetDeviceID()
			if deviceID == "" {
				return
			}

			// Проверяем результат авторизации
			result, exists := am.CheckPendingResult(deviceID)
			if exists {
				hostInfo := getSystemInfo()

				if result {
					// Авторизация одобрена
					sendSuccessResponseWithData(client, AuthStatusApproved, hostInfo)
				} else {
					// Авторизация отклонена
					sendErrorResponse(client, AuthStatusRejected)
				}
				return // Завершаем проверку после отправки результата
			}

		case <-timeout:
			sendErrorResponse(client, AuthStatusTimeout)
			return
		}
	}
}

// HandleAuthCheck проверяет текущий статус авторизации
func (am *AuthManager) HandleAuthCheck(client interfaces.WSClient) {
	deviceID := client.GetDeviceID()

	// Если у клиента нет deviceID, он еще не проходил авторизацию
	if deviceID == "" {
		sendErrorResponse(client, AuthStatusNotAuthorized)
		return
	}

	// Проверяем, авторизован ли клиент
	if am.IsAuthorized(deviceID) {
		// Клиент авторизован
		sendSuccessResponse(client, AuthStatusAuthorized)
		return
	}

	// Проверяем результат ожидающего запроса
	result, exists := am.CheckPendingResult(deviceID)
	if exists {
		if result {
			// Запрос авторизации был одобрен
			sendSuccessResponse(client, AuthStatusApproved)
		} else {
			// Запрос авторизации был отклонен
			sendErrorResponse(client, AuthStatusRejected)
		}
		return
	}

	// Запрос авторизации все еще в ожидании
	sendPendingResponse(client, AuthStatusPending)
}

// Вспомогательные функции для отправки ответов
func sendSuccessResponse(client interfaces.WSClient, code int) {
	response := AuthResponse{
		Type:      MessageTypeAuthResponse,
		Success:   true,
		Code:      code,
		Descripte: GetAuthMessage(code),
	}

	responseJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling auth response: %v", err)
		return
	}

	client.SendMessage(responseJSON)
}

func sendSuccessResponseWithData(client interfaces.WSClient, code int, data interface{}) {
	response := AuthResponseWithData{
		Type:      MessageTypeAuthResponse,
		Success:   true,
		Code:      code,
		Descripte: GetAuthMessage(code),
		Extra:     data,
	}

	responseJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling auth response: %v", err)
		return
	}

	client.SendMessage(responseJSON)
}

func sendPendingResponse(client interfaces.WSClient, code int) {
	response := AuthResponse{
		Type:      MessageTypeAuthPending,
		Success:   false,
		Code:      code,
		Descripte: GetAuthMessage(code),
	}

	responseJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling auth response: %v", err)
		return
	}

	client.SendMessage(responseJSON)
}

func sendErrorResponse(client interfaces.WSClient, code int) {
	response := AuthResponse{
		Type:      MessageTypeAuthResponse,
		Success:   false,
		Code:      code,
		Descripte: GetAuthMessage(code),
	}

	responseJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling auth response: %v", err)
		return
	}

	client.SendMessage(responseJSON)
}
