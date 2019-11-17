package main

import (
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"text/template"
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
		MetricsNamespace: "tns",
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

	app, err := new(logger, databases)
	if err != nil {
		level.Error(logger).Log("msg", "error initialising app", "err", err)
		os.Exit(1)
	}

	s.HTTP.HandleFunc("/", app.Index)
	s.HTTP.HandleFunc("/post", app.Post)
	s.HTTP.HandleFunc("/vote", app.Vote)

	s.Run()
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

type app struct {
	logger    log.Logger
	databases []*url.URL

	id     string
	client *client.Client
	tmpl   *template.Template
}

type Link struct {
	ID     int
	Rank   int
	Points int
	URL    string
	Title  string
}

func new(logger log.Logger, databases []*url.URL) (*app, error) {
	c := client.New(logger)

	tmpl, err := template.ParseFiles("/index.html.tmpl")
	if err != nil {
		return nil, err
	}

	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("app-%x", h.Sum(nil))

	return &app{
		logger:    logger,
		databases: databases,

		tmpl:   tmpl,
		id:     id,
		client: c,
	}, nil
}

func (a *app) Index(w http.ResponseWriter, r *http.Request) {
	db := a.databases[rand.Intn(len(a.databases))].String()
	req, err := http.NewRequest("GET", db, nil)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "%v\n", err)
		return
	}
	req = req.WithContext(r.Context())

	resp, err := a.client.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "%v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode/100 != 2 {
		body, _ := ioutil.ReadAll(io.LimitReader(resp.Body, 1024))
		level.Error(a.logger).Log("msg", "HTTP request faild", "status", resp.StatusCode, "body", body)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "%s\n", body)
		return
	}

	var response struct {
		Links []Link
	}

	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		level.Error(a.logger).Log("msg", "failed to parse db response", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	for i := range response.Links {
		response.Links[i].Rank = i + 1
	}

	w.WriteHeader(http.StatusOK)
	if err := a.tmpl.Execute(w, struct {
		Now   time.Time
		ID    string
		Links []Link
	}{
		Now:   time.Now(),
		ID:    a.id,
		Links: response.Links,
	}); err != nil {
		level.Error(a.logger).Log("msg", "failed to execute template", "err", err)
	}
}

func (a *app) Post(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		level.Error(a.logger).Log("msg", "error parsing form", "err", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	u := strings.TrimSpace(r.PostForm.Get("url"))
	if u == "" {
		level.Error(a.logger).Log("msg", "empty url")
		http.Error(w, "empty url", http.StatusBadRequest)
		return
	}

	parsed, err := url.Parse(u)
	if err != nil {
		level.Error(a.logger).Log("msg", "invalid url", "url", u, "err", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		parsed.Scheme = "http"
	}

	title := strings.TrimSpace(r.PostForm.Get("title"))
	if title == "" {
		level.Error(a.logger).Log("msg", "empty url")
		http.Error(w, "empty title", http.StatusBadRequest)
		return
	}

	hash := sha1.Sum([]byte(parsed.String()))
	id := binary.BigEndian.Uint16(hash[:])

	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(struct {
		ID    int
		URL   string
		Title string
	}{
		ID:    int(id),
		URL:   parsed.String(),
		Title: title,
	}); err != nil {
		level.Error(a.logger).Log("msg", "error encoding post", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	db := a.databases[rand.Intn(len(a.databases))].String()
	req, err := http.NewRequest("POST", db+"/post", &buf)
	if err != nil {
		level.Error(a.logger).Log("msg", "error building request", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	req = req.WithContext(r.Context())
	resp, err := a.client.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "%v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode/100 != 2 {
		body, _ := ioutil.ReadAll(io.LimitReader(resp.Body, 1024))
		level.Error(a.logger).Log("msg", "HTTP request faild", "status", resp.StatusCode, "body", body)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "%s\n", body)
		return
	}

	// Implement PRG pattern to prevent double-POST.
	newURL := strings.TrimSuffix(req.RequestURI, "/post")
	http.Redirect(w, req, newURL, http.StatusFound)
	return
}

func (a *app) Vote(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		level.Error(a.logger).Log("msg", "error parsing form", "err", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	id, err := strconv.Atoi(r.Form.Get("id"))
	if err != nil {
		level.Error(a.logger).Log("msg", "invalid id", "err", err)
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(struct {
		ID int
	}{
		ID: id,
	}); err != nil {
		level.Error(a.logger).Log("msg", "error encoding post", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	db := a.databases[rand.Intn(len(a.databases))].String()
	req, err := http.NewRequest("POST", db+"/vote", &buf)
	if err != nil {
		level.Error(a.logger).Log("msg", "error building request", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	req = req.WithContext(r.Context())
	resp, err := a.client.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "%v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode/100 != 2 {
		body, _ := ioutil.ReadAll(io.LimitReader(resp.Body, 1024))
		level.Error(a.logger).Log("msg", "HTTP request faild", "status", resp.StatusCode, "body", body)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "%s\n", body)
		return
	}

	// Implement PRG pattern to prevent double-POST.
	newURL := strings.TrimSuffix(req.RequestURI, "/vote")
	http.Redirect(w, req, newURL, http.StatusFound)
	return
}
