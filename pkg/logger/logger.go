package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/fatih/color"
	"gopkg.in/natefinch/lumberjack.v2"
	"smart-shutdown/pkg/config"
)

var fileLogger *lumberjack.Logger

func InitLogger() error {
	logDir := config.GetLogDir()
	if err := os.MkdirAll(logDir, 0755); err != nil {
		logDir = "logs"
		os.MkdirAll(logDir, 0755)
	}

	logFile := filepath.Join(logDir, "network_monitor.log")

	fileLogger = &lumberjack.Logger{
		Filename:   logFile,
		MaxSize:    10,
		MaxBackups: 30,
		MaxAge:     30,
		Compress:   false,
	}

	return nil
}

func writeLog(level, plainPrefix, format string, v ...interface{}) {
	msg := fmt.Sprintf(format, v...)
	timestamp := time.Now().Format("2006/01/02 15:04:05")

	if fileLogger != nil {
		plainLine := fmt.Sprintf("%s %s %s\n", plainPrefix, timestamp, msg)
		fileLogger.Write([]byte(plainLine))
	}

	prefixColorFunc := getPrefixColor(level)
	coloredPrefix := prefixColorFunc(plainPrefix)
	coloredLine := fmt.Sprintf("%s %s %s\n", coloredPrefix, timestamp, msg)
	
	if level == "FAIL" || level == "CRITICAL" {
		fmt.Fprint(os.Stderr, coloredLine)
	} else {
		fmt.Fprint(os.Stdout, coloredLine)
	}
}

func getPrefixColor(level string) func(a ...interface{}) string {
	switch level {
	case "SUCCESS":
		return color.New(color.FgGreen).SprintFunc()
	case "WARN":
		return color.New(color.FgYellow).SprintFunc()
	case "FAIL":
		return color.New(color.FgRed).SprintFunc()
	case "CRITICAL":
		return color.New(color.FgHiRed).SprintFunc()
	default:
		return color.New(color.Reset).SprintFunc()
	}
}

func Info(format string, v ...interface{}) {
	writeLog("INFO", "[INFO]", format, v...)
}

func Succ(format string, v ...interface{}) {
	writeLog("SUCCESS", "[SUCCESS]", format, v...)
}

func Warn(format string, v ...interface{}) {
	writeLog("WARN", "[WARN]", format, v...)
}

func Fail(format string, v ...interface{}) {
	writeLog("FAIL", "[FAIL]", format, v...)
}

func Crit(format string, v ...interface{}) {
	writeLog("CRITICAL", "[CRITICAL]", format, v...)
}
