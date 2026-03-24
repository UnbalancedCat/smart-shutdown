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
	logger.Info("启动系统监控后台服务")

	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel
	p.exit = make(chan struct{})

	go p.run(ctx)
	return nil
}

func (p *program) run(ctx context.Context) {
	monitor.Run(ctx, p.cfg)
	close(p.exit)
}

func (p *program) Stop(s service.Service) error {
	logger.Info("停止系统监控后台服务")
	if p.cancel != nil {
		p.cancel()
	}
	<-p.exit
	return nil
}

func GetService(cfg *config.Config, execPath ...string) (service.Service, error) {
	svcConfig := &service.Config{
		Name:        "SmartNetworkMonitor",
		DisplayName: "Smart Network Shutdown Monitor",
		Description: "A reliable daemon that periodically monitors network states and triggers node suspension logically.",
	}

	if len(execPath) > 0 && execPath[0] != "" {
		svcConfig.Executable = execPath[0]
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
