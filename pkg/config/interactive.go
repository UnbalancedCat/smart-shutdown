package config

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// ConfigFileExists checks if the config.json file exists at the expected location.
func ConfigFileExists() bool {
	configPath := filepath.Join(GetConfigDir(), "config.json")
	_, err := os.Stat(configPath)
	return err == nil
}

// isTerminal checks if stdin is connected to a terminal (not a pipe).
func isTerminal() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

// InteractiveSetup prompts the user to configure each parameter interactively.
// If stdin is not a terminal (pipe mode), it silently saves and returns defaults.
func InteractiveSetup() (*Config, error) {
	cfg := DefaultConfig()

	if !isTerminal() {
		if err := SaveConfig(cfg); err != nil {
			return nil, fmt.Errorf("写入默认配置失败: %v", err)
		}
		return cfg, nil
	}

	fmt.Println("\n========== 首次配置 ==========")
	fmt.Println("未检测到配置文件，将引导您完成初始设置。直接按回车使用 [默认值]。")

	scanner := bufio.NewScanner(os.Stdin)

	cfg.TargetIP = promptString(scanner, "目标监控 IP 地址", cfg.TargetIP, func(s string) error {
		if net.ParseIP(s) == nil {
			return fmt.Errorf("非法 IP 地址: %s", s)
		}
		return nil
	})

	cfg.MonitorWindowSeconds = promptInt(scanner, "断网容忍超时时长 (秒)", cfg.MonitorWindowSeconds)
	cfg.ShutdownCountdown = promptInt(scanner, "关机倒计时缓冲 (秒)", cfg.ShutdownCountdown)
	cfg.NormalPingInterval = promptInt(scanner, "探测发包间隔 (秒)", cfg.NormalPingInterval)

	if err := SaveConfig(cfg); err != nil {
		return nil, fmt.Errorf("写入配置文件失败: %v", err)
	}

	configPath := filepath.Join(GetConfigDir(), "config.json")
	fmt.Printf("\n配置已保存至: %s\n", configPath)
	return cfg, nil
}

// ConfirmAndCleanup prompts the user to confirm deletion of config and log files separately.
// Non-terminal stdin skips all prompts.
func ConfirmAndCleanup() {
	if !isTerminal() {
		return
	}

	scanner := bufio.NewScanner(os.Stdin)
	configDir := GetConfigDir()
	configPath := filepath.Join(configDir, "config.json")
	logDir := GetLogDir()

	if _, err := os.Stat(configPath); err == nil {
		fmt.Printf("检测到配置文件: %s\n是否清除配置文件？[y/N]: ", configPath)
		if scanner.Scan() && strings.EqualFold(strings.TrimSpace(scanner.Text()), "y") {
			os.Remove(configPath)
			fmt.Println("配置文件已清除。")
		}
	}

	if _, err := os.Stat(logDir); err == nil {
		fmt.Printf("检测到日志目录: %s\n是否清除日志文件？[y/N]: ", logDir)
		if scanner.Scan() && strings.EqualFold(strings.TrimSpace(scanner.Text()), "y") {
			os.RemoveAll(logDir)
			fmt.Println("日志文件已清除。")
		}
	}

	// If configDir is now empty, remove it too
	entries, err := os.ReadDir(configDir)
	if err == nil && len(entries) == 0 {
		os.Remove(configDir)
	}
}

func promptString(scanner *bufio.Scanner, label, defaultVal string, validate func(string) error) string {
	for {
		fmt.Printf("\n%s [%s]: ", label, defaultVal)
		if !scanner.Scan() {
			return defaultVal
		}
		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			return defaultVal
		}
		if validate != nil {
			if err := validate(input); err != nil {
				fmt.Printf("  输入无效: %v，请重新输入。\n", err)
				continue
			}
		}
		return input
	}
}

func promptInt(scanner *bufio.Scanner, label string, defaultVal int) int {
	for {
		fmt.Printf("%s [%d]: ", label, defaultVal)
		if !scanner.Scan() {
			return defaultVal
		}
		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			return defaultVal
		}
		val, err := strconv.Atoi(input)
		if err != nil || val <= 0 {
			fmt.Println("  输入无效: 必须为正整数，请重新输入。")
			continue
		}
		return val
	}
}
