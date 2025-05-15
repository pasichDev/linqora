package auth

// Коды типов сообщений
const (
	// Тип сообщения - ответ авторизации
	MessageTypeAuthResponse = "auth_response"

	// Тип сообщения - ожидание авторизации
	MessageTypeAuthPending = "auth_pending"
)

// Коды статусов авторизации
const (
	// Устройство не авторизовано (0xx)
	AuthStatusNotAuthorized = 001

	// Устройство уже авторизовано (1xx)
	AuthStatusAuthorized = 100

	// Авторизация одобрена (1xx)
	AuthStatusApproved = 101

	// Ожидание авторизации (2xx)
	AuthStatusPending = 200

	// Авторизация отклонена (4xx - ошибки клиента)
	AuthStatusRejected = 400

	// Ошибка неверный формат запроса авторизации
	AuthStatusInvalidFormat = 401

	// Ошибка отсутствует ID устройства
	AuthStatusMissingDeviceID = 402

	// Истекло время ожидания авторизации (5xx - ошибки сервера)
	AuthStatusTimeout = 500

	// Ошибка запроса авторизации
	AuthStatusRequestFailed = 501
)

// Сообщения для кодов статуса
var authMessages = map[int]string{
	AuthStatusNotAuthorized:   "Device not authorized",
	AuthStatusAuthorized:      "Device authorized",
	AuthStatusApproved:        "Authorization approved",
	AuthStatusRejected:        "Authorization rejected",
	AuthStatusPending:         "Waiting for authorization",
	AuthStatusTimeout:         "Authorization timeout",
	AuthStatusInvalidFormat:   "Invalid authorization data format",
	AuthStatusMissingDeviceID: "Device ID is missing",
	AuthStatusRequestFailed:   "Authorization request failed",
}

// GetAuthMessage возвращает описание для кода статуса
func GetAuthMessage(code int) string {
	if msg, ok := authMessages[code]; ok {
		return msg
	}
	return "Unknown authorization error"
}
