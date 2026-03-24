package monitor

import (
	"context"
	"time"

	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/logger"
	"smart-shutdown/pkg/pinger"
	"smart-shutdown/pkg/system"
)

func Run(ctx context.Context, cfg *config.Config) {
	logger.Info("启动后台网络监控")
	logger.Info("监控目标 IP: %s", cfg.TargetIP)
	logger.Info("故障判定窗口: %d秒", cfg.MonitorWindowSeconds)
	logger.Info("关机倒计时阈值: %d秒", cfg.ShutdownCountdown)

	var failureStartTime time.Time
	var inFailureWindow bool = false

	normalStatusCounter := 0
	const normalStatusLogInterval = 24

	for {
		select {
		case <-ctx.Done():
			logger.Info("接收到系统停止指令, 退出核心调度监控")
			return
		default:
		}

		isOnline := pinger.Ping(cfg.TargetIP, 3)

		if isOnline {
			if inFailureWindow {
				logger.Succ("网络连通性恢复, 监控窗口重置")
				inFailureWindow = false
				normalStatusCounter = 0
			} else {
				normalStatusCounter++
				if normalStatusCounter >= normalStatusLogInterval {
					logger.Info("网络探测状态正常 (定期状态更新)")
					normalStatusCounter = 0
				}
			}

			time.Sleep(time.Duration(cfg.NormalPingInterval) * time.Second)

		} else {
			logger.Warn("目标节点未响应探针包: %s", cfg.TargetIP)

			if !inFailureWindow {
				failureStartTime = time.Now()
				inFailureWindow = true
				logger.Warn("触发网络状态失效, 开始累计中断时间监控")
			}

			failureDuration := time.Since(failureStartTime).Seconds()

			if int(failureDuration) >= cfg.MonitorWindowSeconds {
				logger.Crit("持续中断时长超越设定的阈值上限 (%d秒), 进入关机响应流程", cfg.MonitorWindowSeconds)

				shutdownCancelled := startCountdown(ctx, cfg.TargetIP, cfg.ShutdownCountdown)

				if !shutdownCancelled {
					logger.Crit("倒计时时限完毕, 开始下发系统级级终态关机指令")
					system.ExecuteShutdown()
					return
				} else {
					inFailureWindow = false
				}
			} else {
				logger.Info("网络持续断失: %.0f/%d 秒", failureDuration, cfg.MonitorWindowSeconds)
				time.Sleep(time.Duration(cfg.NormalPingInterval) * time.Second)
			}
		}
	}
}

func startCountdown(ctx context.Context, targetIP string, countdownSec int) bool {
	logger.Warn("执行系统关机倒计时流程 (预设: %d秒)...", countdownSec)

	endTime := time.Now().Add(time.Duration(countdownSec) * time.Second)
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		remaining := int(time.Until(endTime).Seconds())
		if remaining <= 0 {
			return false 
		}

		logger.Warn("距离关机指令处分剩余: %d 秒", remaining)

		select {
		case <-ctx.Done():
			logger.Info("挂起关机倒计流程：收到系统强制干预信号")
			return true
		case <-ticker.C:
			if pinger.Ping(targetIP, 3) {
				logger.Succ("倒计时周期内网络指标恢复, 全局关机流程已被重置并取消")
				return true
			}
		}
	}
}
