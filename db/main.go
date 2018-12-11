package main

import (
	"crypto/md5"
	"fmt"
	"log"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/felixge/httpsnoop"
	kitlog "github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/opentracing-contrib/go-stdlib/nethttp"
	opentracing "github.com/opentracing/opentracing-go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	jaegercfg "github.com/uber/jaeger-client-go/config"
)

const (
	dbPort = ":80"

	failPercent = 10
)

var (
	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "request_duration_seconds",
		Help:    "Time (in seconds) spent serving HTTP requests",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route", "status_code"})

	logger = level.NewFilter(kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr)), level.AllowDebug())

	fail = false
)

func main() {
	cfg, err := jaegercfg.FromEnv()
	if err != nil {
		log.Fatalln("err", err)
	}
	cfg.InitGlobalTracer("db")

	rand.Seed(time.Now().UnixNano())

	peers := getPeers()
	level.Info(logger).Log("msg", "peer(s)", "num", len(peers))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("%x", h.Sum(nil))

	http.HandleFunc("/fail", func(w http.ResponseWriter, r *http.Request) {
		fail = !fail

		fmt.Fprintf(w, "failing: %t\n", fail)
	})
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", wrap(func(w http.ResponseWriter, r *http.Request) {
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
	}))

	errc := make(chan error)
	go func() {
		errc <- http.ListenAndServe(dbPort, nethttp.Middleware(opentracing.GlobalTracer(), http.DefaultServeMux))
	}()
	go func() { errc <- interrupt() }()
	log.Fatal(<-errc)
}

func interrupt() error {
	c := make(chan os.Signal)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	return fmt.Errorf("%s", <-c)
}

func id() string {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown-host"
	}
	return hostname
}

func getPeers() []*url.URL {
	peers := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + dbPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		level.Info(logger).Log("peer", u.String())
		peers = append(peers, u)
	}

	return peers
}

func wrap(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := httpsnoop.CaptureMetrics(h, w, r)
		requestDuration.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(m.Code)).Observe(m.Duration.Seconds())
	}
}
