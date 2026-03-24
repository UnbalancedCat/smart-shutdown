package config

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
)

type Config struct {
	TargetIP             string `json:"TargetIP"`
	MonitorWindowSeconds int    `json:"MonitorWindowSeconds"`
	ShutdownCountdown    int    `json:"ShutdownCountdown"`
	NormalPingInterval   int    `json:"NormalPingInterval"`
}

func DefaultConfig() *Config {
	return &Config{
		TargetIP:             "192.168.3.1",
		MonitorWindowSeconds: 180,
		ShutdownCountdown:    60,
		NormalPingInterval:   15,
	}
}

func GetConfigDir() string {
	if runtime.GOOS == "windows" {
		return `C:\ProgramData\SmartNetworkMonitor`
	}
	return `/etc/smart-network-monitor`
}

func GetLogDir() string {
	if runtime.GOOS == "windows" {
		return `C:\ProgramData\SmartNetworkMonitor\logs`
	}
	return `/var/log/smart-network-monitor`
}

func LoadConfig() (*Config, error) {
	configDir := GetConfigDir()
	configPath := filepath.Join(configDir, "config.json")
	return loadConfigFile(configPath)
}

func LoadConfigFrom(path string) (*Config, error) {
	return loadConfigFile(path)
}

func loadConfigFile(configPath string) (*Config, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return DefaultConfig(), nil
		}
		return nil, err
	}

	if len(data) >= 3 && data[0] == 0xef && data[1] == 0xbb && data[2] == 0xbf {
		data = data[3:]
	}

	cfg := &Config{}
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func SaveConfig(cfg *Config) error {
	configDir := GetConfigDir()
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return err
	}
	configPath := filepath.Join(configDir, "config.json")

	data, err := json.MarshalIndent(cfg, "", "    ")
	if err != nil {
		return err
	}
	return os.WriteFile(configPath, data, 0644)
}

func UpdateConfig(key string, value string) error {
	cfg, err := LoadConfig()
	if err != nil {
		return fmt.Errorf("加载配置文件失败: %v", err)
	}

	switch key {
	case "TargetIP":
		if net.ParseIP(value) == nil {
			return fmt.Errorf("非法 IP 地址: %s", value)
		}
		cfg.TargetIP = value
	case "MonitorWindowSeconds":
		val, err := strconv.Atoi(value)
		if err != nil || val <= 0 {
			return fmt.Errorf("非法输入: MonitorWindowSeconds 必须为正整数")
		}
		cfg.MonitorWindowSeconds = val
	case "ShutdownCountdown":
		val, err := strconv.Atoi(value)
		if err != nil || val <= 0 {
			return fmt.Errorf("非法输入: ShutdownCountdown 必须为正整数")
		}
		cfg.ShutdownCountdown = val
	case "NormalPingInterval":
		val, err := strconv.Atoi(value)
		if err != nil || val <= 0 {
			return fmt.Errorf("非法输入: NormalPingInterval 必须为正整数")
		}
		cfg.NormalPingInterval = val
	default:
		return fmt.Errorf("未知配置项: %s (开放编辑项: TargetIP, MonitorWindowSeconds, ShutdownCountdown, NormalPingInterval)", key)
	}

	return SaveConfig(cfg)
}
