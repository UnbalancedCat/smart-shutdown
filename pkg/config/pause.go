package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// SetPause writes a timestamp into pause_until.txt
func SetPause(until time.Time) error {
	dir := GetConfigDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	path := filepath.Join(dir, "pause_until.txt")
	ts := strconv.FormatInt(until.Unix(), 10)
	return os.WriteFile(path, []byte(ts), 0644)
}

// ClearPause removes the pause_until.txt file
func ClearPause() error {
	path := filepath.Join(GetConfigDir(), "pause_until.txt")
	return os.Remove(path)
}

// IsPaused checks if the service is currently paused via IPC file
func IsPaused() (bool, int64) {
	path := filepath.Join(GetConfigDir(), "pause_until.txt")
	data, err := os.ReadFile(path)
	if err != nil {
		return false, 0
	}

	tsStr := strings.TrimSpace(string(data))
	untilUnix, err := strconv.ParseInt(tsStr, 10, 64)
	if err != nil {
		// Invalid file, clean it up
		os.Remove(path)
		return false, 0
	}

	now := time.Now().Unix()
	if now < untilUnix {
		return true, untilUnix - now
	}

	// Expired
	os.Remove(path)
	return false, 0
}
