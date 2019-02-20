package main

import (
	"flag"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/grafana/tns/client"
	"github.com/weaveworks/common/logging"
	"github.com/weaveworks/common/server"
	"github.com/weaveworks/common/tracing"
)

func main() {
	serverConfig := server.Config{
		MetricsNamespace:    "tns",
		ExcludeRequestInLog: true,
	}
	serverConfig.RegisterFlags(flag.CommandLine)
	flag.Parse()

	// Use a gokit logger, and tell the server to use it.
	logger := level.NewFilter(log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout)), serverConfig.LogLevel.Gokit)
	serverConfig.Log = logging.GoKit(logger)

	// Setting the environment variable JAEGER_AGENT_HOST enables tracing
	trace := tracing.NewFromEnv("lb")
	defer trace.Close()

	s, err := server.New(serverConfig)
	if err != nil {
		level.Error(logger).Log("msg", "error starting server", "err", err)
		os.Exit(1)
	}
	defer s.Shutdown()

	rand.Seed(time.Now().UnixNano())

	apps, err := getApps(flag.Args())
	if err != nil {
		level.Error(logger).Log("msg", "error parsing peers", "err", err)
		os.Exit(1)
	}
	level.Info(logger).Log("msg", "peer(s)", "num", len(apps))

	c := client.New(logger)

	quit := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(10)
	for i := 0; i < 10; i++ {
		go func() {
			defer wg.Done()
			ticker := time.NewTicker(1 * time.Second)

			for {
				select {
				case <-quit:
					return
				case <-ticker.C:
					req, err := http.NewRequest("GET", apps[0].String(), nil)
					if err != nil {
						level.Error(logger).Log("msg", "error building request", "err", err)
						continue
					}

					resp, err := c.Do(req)
					if err != nil {
						level.Error(logger).Log("msg", "error doing request", "err", err)
						continue
					}
					resp.Body.Close()
				}
			}
		}()
	}

	s.Run()
	close(quit)
	wg.Wait()
}

func getApps(args []string) ([]*url.URL, error) {
	apps := []*url.URL{}
	for _, host := range args {
		u, err := url.Parse(host)
		if err != nil {
			return nil, err
		}
		apps = append(apps, u)
	}
	return apps, nil
}
