package database

import (
	"database/sql"
	"fmt"
	"log"

	_ "modernc.org/sqlite" // Pure Go SQLite driver
)

const (
	DB_NAME          = "linqoraHost.db"
	TABLE_CPU_METRIC = "cpu_metric"
	TABLE_RAM_METRIC = "ram_metric"
	TABLE_SETTINGS   = "settings"
)

var DB *sql.DB

func Init() error {
	var err error
	DB, err = sql.Open("sqlite", DB_NAME)
	if err != nil {
		return err
	}

	// Створимо таблиці
	err = createTables()
	if err != nil {
		return err
	}

	return nil
}

func createTables() error {

	queries := []string{

		fmt.Sprintf(
			`CREATE TABLE IF NOT EXISTS %s (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
			temperature REAL,
			load_percent REAL
		);`, TABLE_CPU_METRIC),
		fmt.Sprintf(
			`CREATE TABLE IF NOT EXISTS %s (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
			usage REAL,
			load_percent REAL
		);`, TABLE_RAM_METRIC),

		fmt.Sprintf(
			`CREATE TABLE IF NOT EXISTS %s (
			key TEXT PRIMARY KEY,
			value TEXT
		);`, TABLE_SETTINGS),
	}

	for _, query := range queries {
		if _, err := DB.Exec(query); err != nil {
			return fmt.Errorf("failed to execute query: %v", err)
		}
	}

	log.Println("Database initialized and tables created")
	return nil
}

func Close() {
	if DB != nil {
		_ = DB.Close()
		log.Println("Database closed")
	}
}

func ClearTable(tableName string) error {
	query := fmt.Sprintf("DELETE FROM %s", tableName)
	_, err := DB.Exec(query)
	return err
}

func InsertCPUMetric(m CPUMetrics) error {
	_, err := DB.Exec(`INSERT INTO cpu_metric (temperature, load_percent) VALUES (?, ?)`,
		m.Temperature, m.LoadPercent)
	return err
}

func InsertRAMMetric(m RAMMetrics) error {
	_, err := DB.Exec(`INSERT INTO ram_metric (usage, load_percent) VALUES (?, ?)`,
		m.Usage, m.LoadPercent)
	return err
}

func GetCPUMetrics(count int) ([]CPUMetrics, error) {
	rows, err := DB.Query(`SELECT id, timestamp, temperature, load_percent FROM cpu_metric ORDER BY timestamp DESC LIMIT ?`, count)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var metrics []CPUMetrics
	for rows.Next() {
		var metric CPUMetrics

		// Оновлений rows.Scan для всіх полів
		if err := rows.Scan(&metric.ID, &metric.Timestamp, &metric.Temperature, &metric.LoadPercent); err != nil {
			return nil, err
		}

		metrics = append(metrics, metric)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return metrics, nil
}

// Оновлений код для отримання всіх RAM-метрик
func GetRAMMetrics(count int) ([]RAMMetrics, error) {
	rows, err := DB.Query(`SELECT id, timestamp, usage, load_percent FROM ram_metric ORDER BY timestamp DESC LIMIT ?`, count)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var metrics []RAMMetrics
	for rows.Next() {
		var metric RAMMetrics
		var id int
		var timestamp string

		// Оновлений rows.Scan для всіх полів
		if err := rows.Scan(&id, &timestamp, &metric.Usage, &metric.LoadPercent); err != nil {
			return nil, err
		}

		metrics = append(metrics, metric)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return metrics, nil
}
