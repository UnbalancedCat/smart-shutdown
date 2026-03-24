package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/daemon"
	"smart-shutdown/pkg/logger"

	"github.com/kardianos/service"
	"github.com/spf13/cobra"
)

func main() {
	if err := logger.InitLogger(); err != nil {
		fmt.Printf("无法初始化日志系统: %v\n", err)
		os.Exit(1)
	}

	cfg, err := config.LoadConfig()
	if err != nil {
		logger.Crit("读取配置失败: %v", err)
		os.Exit(1)
	}

	svc, err := daemon.GetService(cfg)
	if err != nil {
		logger.Crit("构建服务对象失败: %v", err)
		os.Exit(1)
	}

	var rootCommand = &cobra.Command{
		Use:   "smart-shutdown",
		Short: "智能网络状态检测与自动关机后台服务",
		Run: func(cmd *cobra.Command, args []string) {
			err := svc.Run()
			if err != nil {
				logger.Fail("运行异常: %v", err)
			}
		},
	}

	// 禁用生成补全帮助
	rootCommand.CompletionOptions.DisableDefaultCmd = true

	cmds := []*cobra.Command{
		{
			Use:   "install",
			Short: "安装系统常驻服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "install")
			},
		},
		{
			Use:   "uninstall",
			Short: "卸载系统常驻服务",
			Run: func(cmd *cobra.Command, args []string) {
				service.Control(svc, "stop")
				handleServiceControl(svc, "uninstall")
			},
		},
		{
			Use:   "start",
			Short: "启动后台运行服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "start")
			},
		},
		{
			Use:   "stop",
			Short: "停止后台运行服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "stop")
			},
		},
		{
			Use:   "restart",
			Short: "重启服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "restart")
			},
		},
		{
			Use:   "status",
			Short: "查询核心配置、服务运行状态及近期日志",
			Run: func(cmd *cobra.Command, args []string) {
				status, err := svc.Status()

				fmt.Println("\n========== 运行状态 ==========")
				if err != nil {
					fmt.Printf("服务状态查询失败 (需系统管理员权限): %v\n", err)
				} else {
					switch status {
					case service.StatusRunning:
						fmt.Println("系统服务: [运行中]")
					case service.StatusStopped:
						fmt.Println("系统服务: [已停止]")
					default:
						fmt.Println("系统服务: [未注册或状态未知]")
					}
				}

				fmt.Println("\n========== 核心配置 ==========")
				fmt.Printf("探测目标 IP       : %s\n", cfg.TargetIP)
				fmt.Printf("容忍断连窗口 (秒) : %d\n", cfg.MonitorWindowSeconds)
				fmt.Printf("预警关机倒计 (秒) : %d\n", cfg.ShutdownCountdown)
				fmt.Printf("平稳探测频次 (秒) : %d\n", cfg.NormalPingInterval)

				logFilePath := filepath.Join(config.GetLogDir(), "network_monitor.log")
				if fi, fileErr := os.Stat(logFilePath); fileErr == nil {
					fmt.Println("\n========== 日志系统 ==========")
					fmt.Printf("日志位置: %s\n", logFilePath)
					fmt.Printf("当前占用: %.2f KB\n", float64(fi.Size())/1024)
				}

				printLastLogLines(10)
			},
		},
	}

	var configCmd = &cobra.Command{
		Use:   "config",
		Short: "管理运行配置文件",
	}

	var configSetCmd = &cobra.Command{
		Use:   "set [键] [值]",
		Short: "修改指定的配置参数 (例如 config set TargetIP 192.168.1.1)",
		Args:  cobra.ExactArgs(2),
		Run: func(cmd *cobra.Command, args []string) {
			key := args[0]
			val := args[1]
			err := config.UpdateConfig(key, val)
			if err != nil {
				fmt.Printf("修改配置失败: %v\n", err)
			} else {
				fmt.Printf("成功将配置 [%s] 更新为 [%s]。\n(提示: 请主动执行 smart-shutdown restart 使更改生效)\n", key, val)
			}
		},
	}

	configCmd.AddCommand(configSetCmd)
	rootCommand.AddCommand(configCmd)

	for _, c := range cmds {
		rootCommand.AddCommand(c)
	}

	// 初始化并汉化帮助菜单
	rootCommand.InitDefaultHelpCmd()
	for _, cmd := range rootCommand.Commands() {
		if cmd.Name() == "help" {
			cmd.Short = "获取任意指令的帮助文档"
		}
	}

	if err := rootCommand.Execute(); err != nil {
		os.Exit(1)
	}
}

func handleServiceControl(s service.Service, action string) {
	err := service.Control(s, action)
	if err != nil {
		errStr := err.Error()
		if strings.Contains(errStr, "Access is denied") || strings.Contains(errStr, "permission denied") || strings.Contains(errStr, "拒绝访问") {
			logger.Fail("执行动作 [%s] 失败: 权限遭拒。请以 Administrator 或 Root 权限重新执行。", action)
			return
		}
		logger.Crit("执行动作 [%s] 失败: %v", action, err)
		return
	}
	logger.Succ("执行动作 [%s] 成功", action)
}

func printLastLogLines(n int) {
	logFilePath := filepath.Join(config.GetLogDir(), "network_monitor.log")
	file, err := os.Open(logFilePath)
	if err != nil {
		fmt.Printf("\n(暂无历史探测日志)\n")
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")

	validLines := make([]string, 0, len(lines))
	for _, l := range lines {
		if strings.TrimSpace(l) != "" {
			validLines = append(validLines, l)
		}
	}

	start := len(validLines) - n
	if start < 0 {
		start = 0
	}

	fmt.Printf("\n========== 最近 %d 条抓取日志 ==========\n", n)
	for i := start; i < len(validLines); i++ {
		fmt.Println(validLines[i])
	}
}
