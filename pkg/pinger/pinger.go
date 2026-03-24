package pinger

import (
	"time"

	probing "github.com/prometheus-community/pro-bing"
	"smart-shutdown/pkg/logger"
)

func Ping(targetIP string, timeoutSec int) bool {
	pinger, err := probing.NewPinger(targetIP)
	if err != nil {
		logger.Warn("目标 IP 解析异常 [%s]: %v", targetIP, err)
		return false
	}

	pinger.SetPrivileged(true)

	pinger.Count = 1
	pinger.Timeout = time.Duration(timeoutSec) * time.Second

	err = pinger.Run()
	if err != nil {
		logger.Fail("探针执行失败: %v", err)
		return false
	}

	stats := pinger.Statistics()
	if stats.PacketsRecv > 0 {
		return true
	}

	return false
}
