package client

import (
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
	"github.com/opentracing-contrib/go-stdlib/nethttp"
	"github.com/opentracing/opentracing-go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/weaveworks/common/tracing"
)

var requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
	Namespace: "tns",
	Name:      "client_request_duration_seconds",
	Help:      "Time (in seconds) spent doing client HTTP requests",
	Buckets:   prometheus.DefBuckets,
}, []string{"method", "status_code"})

// Client implements a fully-instrumented HTTP client.
type Client struct {
	logger log.Logger
	http.Client
}

// New makes a new Client.
func New(logger log.Logger) *Client {
	return &Client{
		logger: logger,

		Client: http.Client{
			Transport: &nethttp.Transport{
				RoundTripper: &http.Transport{
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
			},
		},
	}
}

// Do "overrides" http.Client.Do
func (c *Client) Do(req *http.Request) (*http.Response, error) {
	start := time.Now()
	req, ht := nethttp.TraceRequest(opentracing.GlobalTracer(), req)
	defer ht.Finish()

	resp, err := c.Client.Do(req)
	duration := time.Since(start)

	id, _ := tracing.ExtractTraceID(req.Context())

	if err != nil {
		level.Error(c.logger).Log("msg", "HTTP client error", "error", err, "url", req.URL, "duration", duration, "traceID", id)
		requestDuration.WithLabelValues(req.Method, "error").Observe(duration.Seconds())
	} else {
		level.Info(c.logger).Log("msg", "HTTP client success", "status_code", resp.StatusCode, "url", req.URL, "duration", duration, "traceID", id)
		requestDuration.WithLabelValues(req.Method, strconv.Itoa(resp.StatusCode)).Observe(duration.Seconds())
	}

	return resp, err
}
