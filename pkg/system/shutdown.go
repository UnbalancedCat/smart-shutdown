package system

import (
	"os/exec"
	"runtime"
	"smart-shutdown/pkg/logger"
)

// ExecuteShutdown 跨平台执行立即无条件关机
func ExecuteShutdown() error {
	logger.Crit("执行系统关机操作！")
	
	// 注意：在实际正式环境使用前，如果想防误触可暂时注释掉下方的 `cmd.Run()` 
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("shutdown", "-s", "-f", "-t", "0")
	} else {
		cmd = exec.Command("shutdown", "-h", "now")
	}

	err := cmd.Run()
	if err != nil {
		logger.Crit("系统关机指令执行失败: %v", err)
		return err
	}
	
	return nil
}
