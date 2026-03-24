package monitor

import (
	"context"
	"time"

	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/logger"
	"smart-shutdown/pkg/pinger"
	"smart-shutdown/pkg/system"
)

// Run 开启核心状态机循环监控，接收 ctx 以便主程序或者服务管理器控制安全退出
func Run(ctx context.Context, cfg *config.Config) {
	logger.Info("========== 智能关机监控已启动 ==========")
	logger.Info("监控目标: %s", cfg.TargetIP)
	logger.Info("监控窗口: %d秒", cfg.MonitorWindowSeconds)
	logger.Info("关机倒计时: %d秒", cfg.ShutdownCountdown)

	var failureStartTime time.Time
	var inFailureWindow bool = false

	normalStatusCounter := 0
	// 每 24 次正常检测输出一次日志（约 6 分钟）
	const normalStatusLogInterval = 24

	for {
		select {
		case <-ctx.Done():
			logger.Info("========== 收到停止信号，退出监控 ==========")
			return
		default:
		}

		isOnline := pinger.Ping(cfg.TargetIP, 3) // 3 秒超时探测一次

		if isOnline {
			if inFailureWindow {
				logger.Succ("网络连接已恢复！重置断网计时器。")
				inFailureWindow = false
				normalStatusCounter = 0
			} else {
				normalStatusCounter++
				if normalStatusCounter >= normalStatusLogInterval {
					logger.Info("网络连接持续正常（已检测 %d 次）", normalStatusCounter)
					normalStatusCounter = 0
				}
			}

			// 正常状态下休眠等待下一次探测
			time.Sleep(time.Duration(cfg.NormalPingInterval) * time.Second)

		} else {
			logger.Fail("Ping 测试失败 - 目标: %s", cfg.TargetIP)

			if !inFailureWindow {
				// 首次断网
				failureStartTime = time.Now()
				inFailureWindow = true
				logger.Warn("网络首次中断，开始进入监控窗口计时。")
			}

			// 计算当前断网累计时间
			failureDuration := time.Since(failureStartTime).Seconds()

			if int(failureDuration) >= cfg.MonitorWindowSeconds {
				logger.Crit("网络持续中断已超过 %d 秒，触发关机流程！", cfg.MonitorWindowSeconds)

				// 进入倒计时阶段，倒计时期间高频检测（阻塞调用）
				shutdownCancelled := startCountdown(ctx, cfg.TargetIP, cfg.ShutdownCountdown)

				if !shutdownCancelled {
					logger.Crit("倒计时结束，执行最终关机！")
					system.ExecuteShutdown()
					// 关机指令发出，理论上系统即将终止进程，为了优雅，此处也退出
					return
				} else {
					// 倒计时中途网络恢复被取消了，重置状态重新进入监控环节
					inFailureWindow = false
				}
			} else {
				// 还在容忍窗口期内，仅仅打印日志并休眠
				logger.Info("网络已持续中断 %.0f / %d 秒，继续监控...", failureDuration, cfg.MonitorWindowSeconds)
				time.Sleep(time.Duration(cfg.NormalPingInterval) * time.Second)
			}
		}
	}
}

// startCountdown 执行关机前倒计时的轮询，如果中途恢复网络返回 true (代表取消关机)。
// 返回 false 代表断网到底，坚决关机。
func startCountdown(ctx context.Context, targetIP string, countdownSec int) bool {
	logger.Warn("============================================")
	logger.Warn("准备关机！倒计时 %d 秒期间将快速探测网络...", countdownSec)
	logger.Warn("============================================")

	endTime := time.Now().Add(time.Duration(countdownSec) * time.Second)
	// 倒计时期间提高探测频率：每 3 秒一次
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		remaining := int(time.Until(endTime).Seconds())
		if remaining <= 0 {
			return false // 时间到，确认无法恢复
		}

		logger.Warn("距离关机还有 %d 秒... 正在高频检测网络", remaining)

		select {
		case <-ctx.Done():
			logger.Info("收到退出系统服务信号，中止倒计时关机！")
			return true
		case <-ticker.C:
			// 高频重试检测网络
			if pinger.Ping(targetIP, 3) {
				logger.Succ("============================================")
				logger.Succ("网络在倒计时期间奇迹般地恢复了！立刻取消关机！")
				logger.Succ("============================================")
				return true
			}
		}
	}
}
