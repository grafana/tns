package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/weaveworks/common/logging"
	"github.com/weaveworks/common/server"
	"github.com/weaveworks/common/tracing"
)

const failPercent = 10

var fail = false

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
	trace := tracing.NewFromEnv("db")
	defer trace.Close()

	s, err := server.New(serverConfig)
	if err != nil {
		level.Error(logger).Log("msg", "error starting server", "err", err)
		os.Exit(1)
	}
	defer s.Shutdown()

	rand.Seed(time.Now().UnixNano())

	peers, err := getPeers(flag.Args())
	if err != nil {
		level.Error(logger).Log("msg", "error parsing peers", "err", err)
		os.Exit(1)
	}
	level.Info(logger).Log("msg", "peer(s)", "num", len(peers))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("%x", h.Sum(nil))

	s.HTTP.HandleFunc("/fail", func(w http.ResponseWriter, r *http.Request) {
		fail = !fail

		fmt.Fprintf(w, "failing: %t\n", fail)
	})
	s.HTTP.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		since := time.Now()
		defer func() {
			level.Debug(logger).Log("msg", "query executed OK", "duration", time.Since(since))
		}()

		// Randomly fail x% of the requests.
		if fail && rand.Intn(100) <= failPercent {
			time.Sleep(50 * time.Millisecond)
			// Log two different errors..
			if rand.Intn(10) <= 1 {
				level.Error(logger).Log("msg", "too many open connections")
			} else {
				level.Error(logger).Log("msg", "query lock timeout")
			}
			w.WriteHeader(http.StatusInternalServerError)

			return
		}

		fmt.Fprintf(w, "db-%s OK\n", id)
	})

	s.Run()
}

func getPeers(args []string) ([]*url.URL, error) {
	peers := []*url.URL{}
	for _, host := range args {
		u, err := url.Parse(host)
		if err != nil {
			return nil, err
		}
		peers = append(peers, u)
	}

	return peers, nil
}
