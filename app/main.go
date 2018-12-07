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
	"github.com/go-kit/kit/log/level"
	"github.com/opentracing-contrib/go-stdlib/nethttp"
	opentracing "github.com/opentracing/opentracing-go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	jaegercfg "github.com/uber/jaeger-client-go/config"
)

const (
	dbPort  = ":80"
	appPort = ":80"
)

var (
	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "request_duration_seconds",
		Help:    "Time (in seconds) spent serving HTTP requests",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route", "status_code"})

	logger = level.NewFilter(kitlog.NewLogfmtLogger(kitlog.NewSyncWriter(os.Stderr)), level.AllowDebug())
)

func main() {
	cfg, err := jaegercfg.FromEnv()
	if err != nil {
		log.Fatalln("err", err)
	}
	cfg.InitGlobalTracer("app")

	rand.Seed(time.Now().UnixNano())

	databases := getDatabases()
	level.Info(logger).Log("database(s)", len(databases))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("app-%x", h.Sum(nil))

	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", wrap(func(w http.ResponseWriter, r *http.Request) {
		db := databases[rand.Intn(len(databases))].String()
		defer func(begin time.Time) {
			level.Debug(logger).Log("msg", "served request", "from", r.RemoteAddr, "via", db, "duration", time.Since(begin))
		}(time.Now())

		resp, err := tracedGet(r.Context(), db)
		if err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			level.Error(logger).Log("msg", err)
			fmt.Fprintf(w, "%v\n", err)
			return
		}
		w.WriteHeader(resp.StatusCode)

		fmt.Fprintf(w, "%s via %s\n", id, db)
		io.Copy(w, resp.Body)
		resp.Body.Close()
	}))

	errc := make(chan error)
	go func() {
		errc <- http.ListenAndServe(appPort, nethttp.Middleware(opentracing.GlobalTracer(), http.DefaultServeMux))
	}()
	go func() { errc <- interrupt() }()
	log.Fatal(<-errc)
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

func getDatabases() []*url.URL {
	databases := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + dbPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		level.Info(logger).Log("database", u.String())
		databases = append(databases, u)
	}

	return databases
}

func wrap(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := httpsnoop.CaptureMetrics(h, w, r)
		requestDuration.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(m.Code)).Observe(m.Duration.Seconds())
	}
}

func tracedGet(ctx context.Context, url string) (*http.Response, error) {
	client := &http.Client{Transport: &nethttp.Transport{
		&http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   30 * time.Second,
				KeepAlive: 30 * time.Second,
				DualStack: true,
			}).DialContext,
			MaxIdleConns:          1,
			IdleConnTimeout:       10 * time.Millisecond,
			TLSHandshakeTimeout:   10 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
			DisableKeepAlives:     true,
		},
	}}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	req = req.WithContext(ctx)
	req, ht := nethttp.TraceRequest(opentracing.GlobalTracer(), req)
	defer ht.Finish()

	return client.Do(req)
}
