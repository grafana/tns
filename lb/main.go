package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"os"
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

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("lb-%x", h.Sum(nil))

	c := client.New(logger)

	s.HTTP.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		app := apps[rand.Intn(len(apps))].String()

		defer func(begin time.Time) {
			level.Debug(logger).Log("msg", "served request", "from", r.RemoteAddr, "via", app, "duration", time.Since(begin))
		}(time.Now())

		req, err := http.NewRequest("GET", app, nil)
		if err != nil {
			level.Error(logger).Log("msg", "error making http request", "err", err)
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprintf(w, "%v\n", err)
			return
		}
		req = req.WithContext(r.Context())

		resp, err := c.Do(req)
		if err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprintf(w, "%v\n", err)
			return
		}
		defer resp.Body.Close()

		w.WriteHeader(resp.StatusCode)
		fmt.Fprintf(w, "%s via %s\n", id, app)
		io.Copy(w, resp.Body)
	})

	go func() {
		// Simulate traffic.
		for range time.Tick(100 * time.Millisecond) {
			go func() {
				resp, err := http.Get("http://localhost")
				if err != nil {
					level.Error(logger).Log("msg", err)
				}
				resp.Body.Close()
			}()
		}
	}()

	s.Run()
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
