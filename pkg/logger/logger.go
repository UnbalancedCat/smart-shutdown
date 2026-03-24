package logger

import (
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/fatih/color"
	"gopkg.in/natefinch/lumberjack.v2"
	"smart-shutdown/pkg/config"
)

var (
	infoLogger *log.Logger
	succLogger *log.Logger
	warnLogger *log.Logger
	failLogger *log.Logger
	critLogger *log.Logger
)

// InitLogger 初始化全局日志系统，将日志同时输出到终端色彩日志和滚动文件
func InitLogger() error {
	logDir := config.GetLogDir()
	if err := os.MkdirAll(logDir, 0755); err != nil {
		// 降级为当前目录，适用于未具有系统写权限的 Local 执行
		logDir = "logs"
		os.MkdirAll(logDir, 0755)
	}

	logFile := filepath.Join(logDir, "network_monitor.log")

	// 使用 lumberjack 实现每天轮转和最大保留 30 天功能
	ljLogger := &lumberjack.Logger{
		Filename:   logFile,
		MaxSize:    10,   // 每个切片最大兆字节 (MB)
		MaxBackups: 30,   // 保留最近 30 个切片
		MaxAge:     30,   // 保留最近 30 天的文件
		Compress:   false, // 是否压缩
	}

	// 各级别终端色彩
	cSucc := color.New(color.FgGreen).SprintFunc()
	cFail := color.New(color.FgRed).SprintFunc()
	cWarn := color.New(color.FgYellow).SprintFunc()
	cCrit := color.New(color.FgHiRed, color.Bold).SprintFunc()

	// 构建复合输出写入器：终端标准输出 + 日志文件
	outGeneral := io.MultiWriter(os.Stdout, ljLogger)
	outError := io.MultiWriter(os.Stderr, ljLogger)

	// 时间戳格式前缀
	flags := log.Ldate | log.Ltime 

	// 实例化各个级别 Logger
	infoLogger = log.New(outGeneral, "[INFO] ", flags)
	succLogger = log.New(outGeneral, cSucc("[SUCCESS] "), flags)
	warnLogger = log.New(outGeneral, cWarn("[WARN] "), flags)
	failLogger = log.New(outError, cFail("[FAIL] "), flags)
	critLogger = log.New(outError, cCrit("[CRITICAL] "), flags)

	return nil
}

// 封装导出供业务调用的函数
func Info(format string, v ...interface{}) { infoLogger.Printf(format, v...) }
func Succ(format string, v ...interface{}) { succLogger.Printf(format, v...) }
func Warn(format string, v ...interface{}) { warnLogger.Printf(format, v...) }
func Fail(format string, v ...interface{}) { failLogger.Printf(format, v...) }
func Crit(format string, v ...interface{}) { critLogger.Printf(format, v...) }
