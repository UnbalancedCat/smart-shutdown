package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/kardianos/service"
	"github.com/spf13/cobra"
	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/daemon"
	"smart-shutdown/pkg/logger"
	"smart-shutdown/pkg/updater"
)

var AppVersion = "dev"

func main() {
	if err := logger.InitLogger(); err != nil {
		fmt.Printf("无法初始化日志系统: %v\n", err)
		os.Exit(1)
	}

	cfg, err := config.LoadConfig()
	if err != nil {
		logger.Crit("读取配置文件失败: %v", err)
		os.Exit(1)
	}

	svc, err := daemon.GetService(cfg)
	if err != nil {
		logger.Crit("构建后台服务实例失败: %v", err)
		os.Exit(1)
	}

	var showVersion bool

	var rootCommand = &cobra.Command{
		Use:   "smart-shutdown",
		Short: "智能网络状态检测与自动关机后台服务",
		Run: func(cmd *cobra.Command, args []string) {
			if showVersion {
				fmt.Printf("========== Smart Network Shutdown Monitor ==========\n")
				fmt.Printf("执行架构体基准: %s/%s\n", runtime.GOOS, runtime.GOARCH)
				updater.CheckAndPrintUpdate(AppVersion)
				return
			}

			err := svc.Run()
			if err != nil {
				logger.Fail("后台监控流崩溃: %v", err)
			}
		},
	}

	rootCommand.CompletionOptions.DisableDefaultCmd = true
	rootCommand.Flags().BoolVarP(&showVersion, "version", "V", false, "输出当前二进制内核版本并联网拉取发布树状态")

	cmds := []*cobra.Command{
		{
			Use:   "install",
			Short: "将执行文件拷贝至系统目录并全局注入环境变量体系",
			Run: func(cmd *cobra.Command, args []string) {
				targetDir, targetExe := getTargetSystemPath()
				currentExe, _ := os.Executable()

				if !strings.EqualFold(filepath.Clean(currentExe), filepath.Clean(targetExe)) {
					logger.Info("预备自动配置系统级全局环境，本体克隆下放目录: %s", targetExe)
					if err := os.MkdirAll(targetDir, 0755); err != nil {
						logger.Fail("创建系统目录核心区路径溃败 (请核查最高系统权限身份执行需求): %v", err)
						return
					}
					if err := copyFile(currentExe, targetExe); err != nil {
						logger.Fail("注入独立执行程序副本被拒: %v", err)
						return
					}
					
					if runtime.GOOS != "windows" {
						os.Chmod(targetExe, 0755)
					} else {
						envSetupCmd := fmt.Sprintf(`$p=[Environment]::GetEnvironmentVariable("Path","Machine");if(-not($p -split ';' -contains "%s")){[Environment]::SetEnvironmentVariable("Path",$p+";%s","Machine")}`, targetDir, targetDir)
						err := exec.Command("powershell", "-Command", envSetupCmd).Run()
						if err != nil {
							logger.Warn("改写操作系统的环境变量集合遭受阻拦: %v", err)
						} else {
							logger.Info("执行路径已完备挂载进 Windows Global PATH 域内，用户可通过全局指引调取 smart-shutdown。")
						}
					}
				}

				targetSvc, err := daemon.GetService(cfg, targetExe)
				if err != nil {
					logger.Crit("获取安装节点子域结构体构建回执失败: %v", err)
					return
				}
				handleServiceControl(targetSvc, "install")
			},
		},
		{
			Use:   "uninstall",
			Short: "废除并移除在册的后台服务、扫除环境关联残留",
			Run: func(cmd *cobra.Command, args []string) {
				service.Control(svc, "stop")
				handleServiceControl(svc, "uninstall")

				targetDir, targetExe := getTargetSystemPath()
				currentExe, _ := os.Executable()

				if !strings.EqualFold(filepath.Clean(currentExe), filepath.Clean(targetExe)) {
					if _, err := os.Stat(targetExe); err == nil {
						logger.Info("查明曾执行过部署注入逻辑，现在开始彻底摘毁并清理目录: %s", targetExe)
						os.Remove(targetExe)
						
						if runtime.GOOS == "windows" {
							os.Remove(targetDir)
							envClearCmd := fmt.Sprintf(`$p=[Environment]::GetEnvironmentVariable("Path","Machine");$np=($p -split ';' | Where-Object {$_ -ne "%s" -and $_ -ne ""}) -join ';';[Environment]::SetEnvironmentVariable("Path",$np,"Machine")`, targetDir)
							exec.Command("powershell", "-Command", envClearCmd).Run()
						}
					}
				}
			},
		},
		{
			Use:   "update",
			Short: "获取并免干预热部署在线的最新系统构建程序",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("当前内核架构版本: %s\n正在向全向节点请求效验最新发版记录...\n", AppVersion)
				hasNew, latestVer, dlURL := updater.CheckForUpdate(AppVersion)
				if !hasNew {
					fmt.Println("\n[核验完毕] 您当前的程序正处于主线分支顶点，无需任何更新动作。")
					return
				}

				fmt.Printf("\n[匹配成功] 查收最新稳定版释出包裹: %s\n", latestVer)
				fmt.Println("预备接管环境树并构建热更新映射管道...")

				status, _ := svc.Status()
				isRunningService := (status == service.StatusRunning)

				if isRunningService {
					fmt.Println("[生命周期管控] 已探明应用正交由系统守护树作为后台运行，正在为其下放休眠截停指派以退换抢驻的内核独占锁...")
					service.Control(svc, "stop")
				}

				fmt.Println("[数据流传输] 正在拉取远端预编译二进制核心封包...")
				if err := updater.DownloadAndReplace(dlURL); err != nil {
					fmt.Printf("[中断] 内核代码层执行热重载遭挫回滚: %v\n", err)
					if isRunningService {
						service.Control(svc, "start")
					}
					return
				}

				fmt.Println("[实体部署] 核心节点原子级替换覆写完成，系统块检验通过！")

				if isRunningService {
					fmt.Println("[后端苏醒] 重新挂载启动系统最高级权限守护网络接驳中心...")
					service.Control(svc, "start")
					fmt.Println("============ 热更新无感流闭环执行彻底成功！ ============")
				} else {
					fmt.Println("============ 热更核心接替执行完毕！============\n(注: 您的当前终端并不作为真正的宿存执行体。如目前您另行开启了 CMD 窗格在死循环执行此包前台，请人工叉掉那个窗口使其重新载入新版本！)")
				}
			},
		},
		{
			Use:   "start",
			Short: "唤起执行守护后台",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "start")
			},
		},
		{
			Use:   "stop",
			Short: "停机系统守护状态流",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "stop")
			},
		},
		{
			Use:   "restart",
			Short: "阻断并复用重新起跳服务控制主程",
			Run: func(cmd *cobra.Command, args []string) {
				handleServiceControl(svc, "restart")
			},
		},
		{
			Use:   "status",
			Short: "展示全向服务参数结构、后端存活性报告与探针汇集",
			Run: func(cmd *cobra.Command, args []string) {
				status, err := svc.Status()

				fmt.Println("\n========== 运行状态 ==========")
				if err != nil {
					fmt.Printf("特权访问受抵 (查验核算需要系统特权根源准允): %v\n", err)
				} else {
					switch status {
					case service.StatusRunning:
						fmt.Println("全向系统基石服务: [运转值守中]")
					case service.StatusStopped:
						fmt.Println("全向系统基石服务: [已被静默挂起]")
					default:
						fmt.Println("全向系统基石服务: [尚未注册落位 / 孤儿状态]")
					}
				}

				fmt.Println("\n========== 核心配置 ==========")
				fmt.Printf("探测标的机器 IP   : %s\n", cfg.TargetIP)
				fmt.Printf("脱网迟滞容忍 (秒) : %d\n", cfg.MonitorWindowSeconds)
				fmt.Printf("临危核准倒计 (秒) : %d\n", cfg.ShutdownCountdown)
				fmt.Printf("静默发包跳频 (秒) : %d\n", cfg.NormalPingInterval)

				logFilePath := filepath.Join(config.GetLogDir(), "network_monitor.log")
				if fi, fileErr := os.Stat(logFilePath); fileErr == nil {
					fmt.Println("\n========== 日志系统 ==========")
					fmt.Printf("硬盘归档落点: %s\n", logFilePath)
					fmt.Printf("现时容量尺寸: %.2f KB\n", float64(fi.Size())/1024)
				}

				printLastLogLines(10)
			},
		},
	}

	var configCmd = &cobra.Command{
		Use:   "config",
		Short: "提供运行参数结构的修载校验准入系统",
	}

	var configSetCmd = &cobra.Command{
		Use:   "set [键] [值]",
		Short: "安全的对 JSON 属性执行改写封装验证 (如 config set TargetIP 192.168.3.1)",
		Args:  cobra.ExactArgs(2),
		Run: func(cmd *cobra.Command, args []string) {
			key := args[0]
			val := args[1]
			err := config.UpdateConfig(key, val)
			if err != nil {
				fmt.Printf("基于硬编码的防呆数据验证发回抵拦截口指令: %v\n", err)
			} else {
				fmt.Printf("系统确认承接了新的设参: [%s] 指标结构被赋予了 [%s] 新制规格 \n(附留: 更易此配置文件必须人为发起 'smart-shutdown restart' 才能覆盖常驻内存的解析图谱。)\n", key, val)
			}
		},
	}

	configCmd.AddCommand(configSetCmd)
	rootCommand.AddCommand(configCmd)

	for _, c := range cmds {
		rootCommand.AddCommand(c)
	}

	rootCommand.InitDefaultHelpCmd()
	for _, cmd := range rootCommand.Commands() {
		if cmd.Name() == "help" {
			cmd.Short = "按需展示其它操作指令及其详情"
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
			logger.Fail("管控流程 [%s] 触发越级防卫！无核准身份特设记录。请开具含有全 Root 及高配权限窗格承接口径。", action)
			return
		}
		logger.Crit("后台执行流程组块阻断报错 [%s] : %v", action, err)
		return
	}
	logger.Succ("指令动作 [%s] 解析下发执行完毕，无阻断警告。", action)
}

func printLastLogLines(n int) {
	logFilePath := filepath.Join(config.GetLogDir(), "network_monitor.log")
	file, err := os.Open(logFilePath)
	if err != nil {
		fmt.Printf("\n(排障辅录: 获取探针断联记录池为空，全空栈态)\n")
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

	fmt.Printf("\n========== 最新沿线抓取探测轨迹尾部排 %d 行 ==========\n", n)
	for i := start; i < len(validLines); i++ {
		fmt.Println(validLines[i])
	}
}

func getTargetSystemPath() (dir string, exe string) {
	if runtime.GOOS == "windows" {
		dir = filepath.Join(os.Getenv("ProgramFiles"), "SmartShutdown")
		exe = filepath.Join(dir, "smart-shutdown.exe")
	} else {
		dir = "/usr/local/bin"
		exe = filepath.Join(dir, "smart-shutdown")
	}
	return dir, exe
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}
