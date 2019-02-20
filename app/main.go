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
	opentracing "github.com/opentracing/opentracing-go"
	otlog "github.com/opentracing/opentracing-go/log"
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
	trace := tracing.NewFromEnv("app")
	defer trace.Close()

	s, err := server.New(serverConfig)
	if err != nil {
		level.Error(logger).Log("msg", "error starting server", "err", err)
		os.Exit(1)
	}
	defer s.Shutdown()

	databases, err := getDatabases(flag.Args())
	if err != nil {
		level.Error(logger).Log("msg", "error parsing databases", "err", err)
		os.Exit(1)
	}
	level.Info(logger).Log("database(s)", len(databases))

	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("app-%x", h.Sum(nil))

	c := client.New(logger)

	s.HTTP.HandleFunc("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		db := databases[rand.Intn(len(databases))].String()
		defer func(begin time.Time) {
			level.Debug(logger).Log("msg", "served request", "from", r.RemoteAddr, "via", db, "duration", time.Since(begin))
		}(time.Now())

		req, err := http.NewRequest("GET", db, nil)
		if err != nil {
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

		if resp.StatusCode/100 == 5 {
			span := opentracing.SpanFromContext(r.Context())
			if span != nil {
				span.LogFields(otlog.String("msg", "db responded with error, backing off 500ms before retrying"))
			}

			level.Info(logger).Log("msg", "db responded with error, backing off before retrying")
			time.Sleep(500 * time.Millisecond)

			resp, err = c.Do(req)
			if err != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				fmt.Fprintf(w, "%v\n", err)
				return
			}
			defer resp.Body.Close()
		}

		w.WriteHeader(resp.StatusCode)
		fmt.Fprintf(w, "%s via %s\n", id, db)
		io.Copy(w, resp.Body)
	}))

	s.Run()
}

func makeID() string {
	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprint(h, rand.Int63())
	return fmt.Sprintf("%x", h.Sum(nil)[:8])
}

func getDatabases(args []string) ([]*url.URL, error) {
	databases := []*url.URL{}
	for _, host := range args {
		u, err := url.Parse(host)
		if err != nil {
			return nil, err
		}
		databases = append(databases, u)
	}

	return databases, nil
}
