package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
	"github.com/weaveworks/common/logging"
	"github.com/weaveworks/common/server"
	"github.com/weaveworks/common/tracing"

	"github.com/grafana/tns/client"
)

func main() {
	serverConfig := server.Config{
		MetricsNamespace: "tns",
	}
	serverConfig.RegisterFlags(flag.CommandLine)
	flag.Parse()

	// Use a gokit logger, and tell the server to use it.
	logger := level.NewFilter(log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout)), serverConfig.LogLevel.Gokit)
	serverConfig.Log = logging.GoKit(logger)

	// Setting the environment variable JAEGER_AGENT_HOST enables tracing
	trace, err := tracing.NewFromEnv("lb")
	if err != nil {
		level.Error(logger).Log("msg", "error initializing tracing", "err", err)
		os.Exit(1)
	}
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

			for {
				// Random pause from 0-2s; expected 1s.
				timer := time.NewTimer(time.Duration(rand.Intn(2e3)) * time.Millisecond)

				select {
				case <-quit:
					return
				case <-timer.C:
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

	wg.Add(1)
	go func() {
		defer wg.Done()

		buf, err := ioutil.ReadFile("/stories.json")
		if err != nil {
			level.Error(logger).Log("msg", "failed to read stories", "err", err)
			return
		}

		var stories struct {
			Stories []struct {
				Title, URL string
			}
		}
		if err := json.Unmarshal(buf, &stories); err != nil {
			level.Error(logger).Log("msg", "failed to parse stories", "err", err)
			return
		}

		ticker := time.NewTicker(1 * time.Second)
		for {
			select {
			case <-quit:
				return
			case <-ticker.C:
				story := stories.Stories[rand.Intn(len(stories.Stories))]
				fmt.Println(story)
				form := url.Values{}
				form.Add("title", story.Title)
				form.Add("url", story.URL)
				fmt.Println(form.Encode())

				req, err := http.NewRequest("POST", apps[0].String()+"/post", strings.NewReader(form.Encode()))
				if err != nil {
					level.Error(logger).Log("msg", "error building request", "err", err)
					continue
				}
				req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

				resp, err := c.Do(req)
				if err != nil {
					level.Error(logger).Log("msg", "error doing request", "err", err)
					continue
				}
				resp.Body.Close()
			}
		}
	}()

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
