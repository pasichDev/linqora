package auth

import (
	"encoding/json"
	"log"
	"time"

	"LinqoraHost/internal/interfaces"

	"github.com/Masterminds/semver"
)

const (
	// Мінімальна версія клієнта
	MinVersionClient = "0.1.0"
)

type AuthResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// AuthRequestData представляет данные запроса авторизации
type AuthRequestData struct {
	DeviceID      string `json:"deviceId"`
	DeviceName    string `json:"deviceName"`
	IP            string `json:"ip"`
	VersionClient string `json:"versionClient"`
}

// IsVersionSupported checks if the client version is supported
func (am *AuthManager) IsVersionClientSupported(version string) bool {
	clientVersion, err := semver.NewVersion(version)
	if err != nil {
		return false
	}
	minVersion, _ := semver.NewVersion(MinVersionClient)

	return clientVersion.GreaterThan(minVersion) || clientVersion.Equal(minVersion)
}

// HandleAuthRequest обрабатывает запрос авторизации от клиента
func (am *AuthManager) HandleAuthRequest(client interfaces.WSClient, msg interfaces.WSMessage) {
	log.Printf("Processing auth request from %s", client.GetIP())

	var authData AuthRequestData
	if err := json.Unmarshal(msg.GetData(), &authData); err != nil {
		log.Printf("Error unmarshaling auth data: %v", err)
		sendResponse(client, AuthStatusInvalidFormat, false, MessageTypeAuthResponse)
		return
	}

	deviceID := authData.DeviceID
	if deviceID == "" {
		log.Printf("Empty device ID in auth request")
		sendResponse(client, AuthStatusMissingDeviceID, false, MessageTypeAuthResponse)
		return
	}

	// Перевіряємо версію клієнта
	if !am.IsVersionClientSupported(authData.VersionClient) {
		log.Printf("Unsupported client version: %s", authData.VersionClient)
		sendResponse(client, AuthStatusUnsupportedVersion, false, MessageTypeAuthResponse)
		return
	}

	log.Printf("Auth request from device %s (%s) at IP %s",
		authData.DeviceName, deviceID, client.GetIP())

	// Проверяем, авторизовано ли устройство
	if am.IsAuthorized(deviceID) {
		log.Printf("Device %s already authorized", authData.DeviceName)
		client.SetDeviceID(deviceID)
		client.SetDeviceName(authData.DeviceName)

		sendResponse(client, AuthStatusAuthorized, true, MessageTypeAuthResponse)
		return
	}

	// Запрашиваем авторизацию
	pending := am.RequestAuthorization(authData.DeviceName, deviceID, client.GetIP())
	if pending {
		// Сохраняем DeviceID для будущей проверки
		client.SetDeviceID(deviceID)
		client.SetDeviceName(authData.DeviceName)

		// Отправляем сообщение, что запрос на авторизацию отправлен
		sendResponse(client, AuthStatusPending, false, MessageTypeAuthPending)

		// Запускаем фоновую проверку результата
		go am.checkAuthResultPeriodically(client)
		log.Printf("Auth request for %s is pending", authData.DeviceName)
	} else {
		sendResponse(client, AuthStatusRequestFailed, false, MessageTypeAuthResponse)
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
				if result {
					// Авторизация одобрена
					sendResponse(client, AuthStatusApproved, true, MessageTypeAuthResponse)
				} else {
					// Авторизация отклонена
					sendResponse(client, AuthStatusRejected, false, MessageTypeAuthResponse)
				}
				return // Завершаем проверку после отправки результата
			}

		case <-timeout:
			sendResponse(client, AuthStatusTimeout, false, MessageTypeAuthResponse)
			return
		}
	}
}

// HandleAuthCheck проверяет текущий статус авторизации
func (am *AuthManager) HandleAuthCheck(client interfaces.WSClient) {
	deviceID := client.GetDeviceID()

	// Если у клиента нет deviceID, он еще не проходил авторизацию
	if deviceID == "" {
		sendResponse(client, AuthStatusNotAuthorized, false, MessageTypeAuthResponse)
		return
	}

	// Проверяем, авторизован ли клиент
	if am.IsAuthorized(deviceID) {
		// Клиент авторизован
		sendResponse(client, AuthStatusAuthorized, true, MessageTypeAuthResponse)
		return
	}

	// Проверяем результат ожидающего запроса
	result, exists := am.CheckPendingResult(deviceID)
	if exists {
		if result {
			// Запрос авторизации был одобрен
			sendResponse(client, AuthStatusApproved, true, MessageTypeAuthResponse)
		} else {
			// Запрос авторизации был отклонен
			sendResponse(client, AuthStatusRejected, false, MessageTypeAuthResponse)
		}
		return
	}

	// Запрос авторизации все еще в ожидании
	sendResponse(client, AuthStatusPending, false, MessageTypeAuthPending)
}

// Функція для відправки відповіді про успішну авторизацію
func sendResponse(client interfaces.WSClient, code int, success bool, typeResponse string) {
	response := AuthResponse{
		Success: success,
		Code:    code,
		Message: GetAuthMessage(code),
	}

	client.SendSuccess(typeResponse, response)
}
