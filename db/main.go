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
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const (
	dbPort = ":80"
)

var (
	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "request_duration_seconds",
		Help:    "Time (in seconds) spent serving HTTP requests",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route", "status_code"})

	logger = kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr))
)

func main() {
	rand.Seed(time.Now().UnixNano())

	peers := getPeers()
	logger.Log("msg", "peer(s)", "num", len(peers))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("%x", h.Sum(nil))

	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", wrap(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "db-%s OK\n", id)
	}))

	errc := make(chan error)
	go func() { errc <- http.ListenAndServe(dbPort, nil) }()
	go func() { errc <- loop(peers) }()
	go func() { errc <- interrupt() }()
	log.Fatal(<-errc)
}

func loop(peers []*url.URL) error {
	var (
		count  = 0
		get    = time.Tick(time.Second)
		report = time.Tick(10 * time.Second)
	)
	for {
		select {
		case <-get:
			if len(peers) <= 0 {
				continue
			}
			resp, err := http.Get(peers[rand.Intn(len(peers))].String())
			if err != nil {
				log.Print(err)
				continue
			}
			resp.Body.Close()
			count++

		case <-report:
			logger.Log("msg", "successful GET(s)", "len", count)
		}
	}
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
		logger.Log("peer", u.String())
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
