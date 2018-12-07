package main

import (
	"context"
	"crypto/md5"
	"fmt"
	"io"
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
	"github.com/opentracing-contrib/go-stdlib/nethttp"
	opentracing "github.com/opentracing/opentracing-go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	jaegercfg "github.com/uber/jaeger-client-go/config"
)

const (
	appPort = ":80"
	lbPort  = ":80"
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
	cfg, err := jaegercfg.FromEnv()
	if err != nil {
		log.Fatalln("err", err)
	}
	cfg.InitGlobalTracer("lb")

	rand.Seed(time.Now().UnixNano())

	apps := getApps()
	logger.Log("msg", "peer(s)", "num", len(apps))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("lb-%x", h.Sum(nil))

	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", wrap(func(w http.ResponseWriter, r *http.Request) {
		app := apps[rand.Intn(len(apps))].String()

		defer func(begin time.Time) {
			logger.Log("msg", "served request", "from", r.RemoteAddr, "via", app, "duration", time.Since(begin))
		}(time.Now())

		resp, err := tracedGet(r.Context(), app)
		if err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprintf(w, "%v\n", err)
			return
		}

		w.WriteHeader(resp.StatusCode)
		fmt.Fprintf(w, "%s via %s\n", id, app)
		io.Copy(w, resp.Body)
		resp.Body.Close()
	}))

	errc := make(chan error)
	go func() {
		errc <- http.ListenAndServe(lbPort, nethttp.Middleware(opentracing.GlobalTracer(), http.DefaultServeMux))
	}()
	go func() { errc <- loop(apps) }()
	go func() { errc <- interrupt() }()
	log.Fatal(<-errc)
}

func loop(apps []*url.URL) error {
	// Simulate traffic.
	for range time.Tick(100 * time.Millisecond) {
		resp, err := http.Get("http://localhost" + lbPort)
		if err != nil {
			logger.Log("error", err)
			continue
		}
		resp.Body.Close()
	}
	return nil
}

func makeID() string {
	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprint(h, rand.Int63())
	return fmt.Sprintf("%x", h.Sum(nil)[:8])
}

func interrupt() error {
	c := make(chan os.Signal)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	return fmt.Errorf("%s", <-c)
}

func getApps() []*url.URL {
	apps := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + appPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		logger.Log("app", u.String())
		apps = append(apps, u)
	}

	return apps
}

func wrap(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := httpsnoop.CaptureMetrics(h, w, r)
		requestDuration.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(m.Code)).Observe(m.Duration.Seconds())
	}
}

func tracedGet(ctx context.Context, url string) (*http.Response, error) {
	client := &http.Client{Transport: &nethttp.Transport{}}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	req = req.WithContext(ctx)
	req, ht := nethttp.TraceRequest(opentracing.GlobalTracer(), req)
	defer ht.Finish()

	return client.Do(req)
}
