package main

import (
	"fmt"
	"os"

	"github.com/kardianos/service"
	"github.com/spf13/cobra"
	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/daemon"
	"smart-shutdown/pkg/logger"
)

func main() {
	// 初始化全局系统日志
	if err := logger.InitLogger(); err != nil {
		fmt.Printf("无法初始化日志系统: %v\n", err)
		os.Exit(1)
	}

	// 初始化配置加载
	cfg, err := config.LoadConfig()
	if err != nil {
		logger.Crit("读取配置失败: %v", err)
		os.Exit(1)
	}

	// 注册为跨平台系统服务
	svc, err := daemon.GetService(cfg)
	if err != nil {
		logger.Crit("构建服务对象失败: %v", err)
		os.Exit(1)
	}

	// 定义根命令，无后续子命令会直接触发
	var rootCommand = &cobra.Command{
		Use:   "smart-monitor",
		Short: "智能网络监控自动关机",
		Run: func(cmd *cobra.Command, args []string) {
			// 如果没有输入子命令，尝试作为服务直接前台或者后台跑起来
			// 这个分支也是系统启动服务（systemd/services.msc）自动拉起进程时的必然入口
			err := svc.Run()
			if err != nil {
				logger.Fail("运行抛出异常: %v", err)
			}
		},
	}

	// 系统服务管理一键控制逻辑，使用 kardianos/service 提供的内置 Control方法
	cmds := []*cobra.Command{
		{
			Use:   "install",
			Short: "将本程序装载并注册为系统常驻服务 (例如 systemd / windows registry)",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "install")
			},
		},
		{
			Use:   "uninstall",
			Short: "从系统中彻底卸载此后台监控服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "uninstall")
			},
		},
		{
			Use:   "start",
			Short: "令已注册的系统服务开始运行",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "start")
			},
		},
		{
			Use:   "stop",
			Short: "停止系统服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "stop")
			},
		},
		{
			Use:   "restart",
			Short: "重启系统服务",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "restart")
			},
		},
		{
			Use:   "status",
			Short: "查询服务存活进程状态",
			Run: func(cmd *cobra.Command, args []string) {
				status, err := svc.Status()
				if err != nil {
					fmt.Printf("❌ 获取服务状态失败: %v\n", err)
					return
				}
				switch status {
				case service.StatusRunning:
					fmt.Println("✅ 服务存活 [运行中]")
				case service.StatusStopped:
					fmt.Println("💤 服务处于 [已停止] 状态")
				default:
					fmt.Println("❓ 服务尚未在本机注册或者状态未知。请确认你是否执行过 smart-monitor install")
				}
			},
		},
	}

	for _, c := range cmds {
		rootCommand.AddCommand(c)
	}

	if err := rootCommand.Execute(); err != nil {
		os.Exit(1)
	}
}

func handleServiceControl(s service.Service, action string) {
	err := service.Control(s, action)
	if err != nil {
		logger.Crit("执行动作 [%s] 遭到拒绝或失败: %v", action, err)
		return
	}
	logger.Succ("成功对系统后台服务执行 [%s] 指令！", action)
}
