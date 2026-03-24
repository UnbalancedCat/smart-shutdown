package daemon

import (
	"context"

	"github.com/kardianos/service"
	"smart-shutdown/pkg/config"
	"smart-shutdown/pkg/logger"
	"smart-shutdown/pkg/monitor"
)

type program struct {
	exit   chan struct{}
	cancel context.CancelFunc
	cfg    *config.Config
}

func (p *program) Start(s service.Service) error {
	// Start should not block. Do the actual work async.
	logger.Info("准备在后台启动服务监控...")

	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel
	p.exit = make(chan struct{})

	go p.run(ctx)
	return nil
}

func (p *program) run(ctx context.Context) {
	// 挂载执行核心循环逻辑
	monitor.Run(ctx, p.cfg)
	close(p.exit)
}

func (p *program) Stop(s service.Service) error {
	// Stop should not block. Return within a few seconds.
	logger.Info("正在平滑停止后台服务监控...")
	if p.cancel != nil {
		p.cancel()
	}
	<-p.exit
	return nil
}

// GetService 构建 service 实例供 CLI 控制（安装，启动，停止，卸载）和前台直接 Run。
func GetService(cfg *config.Config) (service.Service, error) {
	svcConfig := &service.Config{
		Name:        "SmartNetworkMonitor",
		DisplayName: "Smart Network Shutdown Monitor",
		Description: "A daemon that pings target IP periodically and shuts down the computer if disconnected for too long.",
	}

	prg := &program{
		cfg: cfg,
	}

	s, err := service.New(prg, svcConfig)
	if err != nil {
		return nil, err
	}
	return s, nil
}
