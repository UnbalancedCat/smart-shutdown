package pinger

import (
	"time"

	probing "github.com/prometheus-community/pro-bing"
	"smart-shutdown/pkg/logger"
)

// Ping 连通性测试，向指定的 targetIP 发送 ICMP 请求。
// 如果规定时间内可达返回 true，超时或者全部丢包返回 false。
func Ping(targetIP string, timeoutSec int) bool {
	pinger, err := probing.NewPinger(targetIP)
	if err != nil {
		logger.Warn("解析目标 IP 失败 [%s]: %v", targetIP, err)
		return false
	}

	// 大部分操作系统为了安全，普通程序发 ICMP 包会被拦截。开启 Privileged 会尝试使用 raw sockets 发行 
	// 本程序由于本身作为系统服务（System 或 Root 权限）运行，故直接开启特权模式以保障发包成功率。
	pinger.SetPrivileged(true)

	// 只发送 1 个探测包
	pinger.Count = 1
	pinger.Timeout = time.Duration(timeoutSec) * time.Second

	err = pinger.Run()
	if err != nil {
		logger.Fail("Ping 测试运行时遇到异常: %v", err)
		return false
	}

	stats := pinger.Statistics()
	// 只要成功收到至少 1 个回包，认为网络通畅
	if stats.PacketsRecv > 0 {
		return true
	}

	// 丢包或者无回音
	return false
}
