package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"sort"
	"sync"
	"time"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/weaveworks/common/logging"
	"github.com/weaveworks/common/middleware"
	"github.com/weaveworks/common/server"
	"github.com/weaveworks/common/tracing"
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
	trace, err := tracing.NewFromEnv("db")
	if err != nil {
		level.Error(logger).Log("msg", "error initializing tracing", "err", err)
		os.Exit(1)
	}
	defer trace.Close()

	db := New(logger, prometheus.DefaultRegisterer)
	serverConfig.HTTPMiddleware = []middleware.Interface{middleware.Func(db.handlePanic)}

	s, err := server.New(serverConfig)
	if err != nil {
		level.Error(logger).Log("msg", "error starting server", "err", err)
		os.Exit(1)
	}
	defer s.Shutdown()

	s.HTTP.HandleFunc("/", db.Fetch)
	s.HTTP.HandleFunc("/fail", db.Fail)
	s.HTTP.HandleFunc("/post", db.Post)
	s.HTTP.HandleFunc("/vote", db.Vote)

	s.Run()
}

type db struct {
	logger  log.Logger
	fetches prometheus.Counter
	posts   prometheus.Histogram
	votes   prometheus.Histogram

	mtx   sync.Mutex
	fail  bool
	links map[int]*Link
}

type Link struct {
	ID     int
	Points int
	URL    string
	Title  string
}

func New(logger log.Logger, reg prometheus.Registerer) *db {
	return &db{
		logger: logger,
		fetches: promauto.With(reg).NewCounter(prometheus.CounterOpts{
			Name: "tns_db_fetches_total",
			Help: "Number of fetch requests handled by the database",
		}),
		posts: promauto.With(reg).NewHistogram(prometheus.HistogramOpts{
			Name: "tns_db_post_time_seconds",
			Help: "Time taken to submit new links to the database",
			Buckets: prometheus.DefBuckets,
			NativeHistogramBucketFactor: 1.1,
			NativeHistogramMaxBucketNumber: 100,
			NativeHistogramMinResetDuration: 1*time.Hour,
		}),
		votes: promauto.With(reg).NewHistogram(prometheus.HistogramOpts{
			Name: "tns_db_vote_time_seconds",
			Help: "Time taken to vote on links in the database",
		}),
		links: map[int]*Link{},
	}
}

func (db *db) Fail(w http.ResponseWriter, r *http.Request) {
	db.mtx.Lock()
	defer db.mtx.Unlock()

	db.fail = !db.fail
	level.Info(db.logger).Log("msg", "toggled fail flag", "fail", db.fail)

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "failing: %t\n", db.fail)
}

func (db *db) handlePanic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				level.Error(db.logger).Log("err", r)
				w.WriteHeader(http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func (db *db) Fetch(w http.ResponseWriter, r *http.Request) {
	traceId, _ := tracing.ExtractTraceID(r.Context())
	if c, ok := db.fetches.(prometheus.ExemplarAdder); ok {
		c.AddWithExemplar(1, prometheus.Labels{"traceID": traceId})
	}

	db.mtx.Lock()
	defer db.mtx.Unlock()

	// Every 5mins, randomly fail 40% of requests for 30 seconds.
	if time.Now().Unix()%(5*60) < 30 && rand.Intn(10) <= 8 {
		time.Sleep(50 * time.Millisecond)
		if rand.Intn(10) <= 4 {
			panic("too many open connections")
		} else {
			panic("query lock timeout")
		}
	}

	if db.fail {
		level.Error(db.logger).Log("err", "spline matriculation failed", "traceID", traceId)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	links := make([]*Link, 0, len(db.links))
	for _, link := range db.links {
		links = append(links, link)
	}

	sort.Slice(links, func(i, j int) bool {
		if links[i].Points != links[j].Points {
			return links[i].Points > links[j].Points
		}
		return links[i].ID > links[j].ID
	})

	max := 10
	if len(links) < max {
		max = len(links)
	}
	links = links[:max]

	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(struct {
		Links []*Link
	}{
		Links: links,
	}); err != nil {
		level.Error(db.logger).Log("msg", "error encoding response", "err", err, "traceID", traceId)
	}
}

func (db *db) Post(w http.ResponseWriter, r *http.Request) {
	traceId, _ := tracing.ExtractTraceID(r.Context())
	start := time.Now()
	defer func() {
		elapsed := time.Since(start)
		if h, ok := db.posts.(prometheus.ExemplarObserver); ok {
			h.ObserveWithExemplar(elapsed.Seconds(), prometheus.Labels{"traceID": traceId})
		}
	}()

	var link Link
	if err := json.NewDecoder(r.Body).Decode(&link); err != nil {
		level.Error(db.logger).Log("msg", "error decoding link", "err", err, "traceID", traceId)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	db.mtx.Lock()
	defer db.mtx.Unlock()

	if _, ok := db.links[link.ID]; ok {
		http.Error(w, "post exists", http.StatusAlreadyReported)
		return
	}

	db.links[link.ID] = &link
	w.WriteHeader(http.StatusNoContent)
}

func (db *db) Vote(w http.ResponseWriter, r *http.Request) {
	traceId, _ := tracing.ExtractTraceID(r.Context())
	start := time.Now()
	defer func() {
		elapsed := time.Since(start)
		if h, ok := db.votes.(prometheus.ExemplarObserver); ok {
			h.ObserveWithExemplar(elapsed.Seconds(), prometheus.Labels{"traceID": traceId})
		}
	}()

	var req struct {
		ID int
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		level.Error(db.logger).Log("msg", "error decoding link", "err", err, "traceID", traceId)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	db.mtx.Lock()
	defer db.mtx.Unlock()
	db.links[req.ID].Points++

	w.WriteHeader(http.StatusNoContent)
}
