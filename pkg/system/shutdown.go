package system

import (
	"os/exec"
	"runtime"
	"smart-shutdown/pkg/logger"
)

func ExecuteShutdown() error {
	logger.Crit("系统调用：执行关机指令")
	
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
