package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
)

// Config 存储程序的各类配置常量，支持通过读取 json 文件动态修改
type Config struct {
	TargetIP             string `json:"TargetIP"`             // 检测目标 IP，默认 192.168.3.3
	MonitorWindowSeconds int    `json:"MonitorWindowSeconds"` // 监控窗口期内持续失败才触发关机
	ShutdownCountdown    int    `json:"ShutdownCountdown"`    // 关机倒计时时间
	NormalPingInterval   int    `json:"NormalPingInterval"`   // 正常状态下的 ping 间隔
}

// DefaultConfig 提供一套开箱即用的默认配置
func DefaultConfig() *Config {
	return &Config{
		TargetIP:             "192.168.3.3",
		MonitorWindowSeconds: 180,
		ShutdownCountdown:    60,
		NormalPingInterval:   15,
	}
}

// GetConfigDir 根据当前操作系统返回标准的配置存放路径
func GetConfigDir() string {
	if runtime.GOOS == "windows" {
		return `C:\ProgramData\SmartNetworkMonitor`
	}
	return `/etc/smart-network-monitor`
}

// GetLogDir 根据当前操作系统返回标准的日志存放路径
func GetLogDir() string {
	if runtime.GOOS == "windows" {
		return `C:\ProgramData\SmartNetworkMonitor\logs`
	}
	return `/var/log/smart-network-monitor`
}

// LoadConfig 从系统标准路径读取 config.json 并反序列化。如果不存在，则返回默认配置。
func LoadConfig() (*Config, error) {
	configDir := GetConfigDir()
	configPath := filepath.Join(configDir, "config.json")

	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			// 文件不存在时，静默采用默认配置
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
