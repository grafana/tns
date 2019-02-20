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
	"sort"
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

	a := new(logger, databases)
	s.HTTP.HandleFunc("/", a.Index)
	s.HTTP.HandleFunc("/post", a.Post)

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
}

func new(logger log.Logger, databases []*url.URL) *app {
	c := client.New(logger)

	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("app-%x", h.Sum(nil))

	return &app{
		logger:    logger,
		databases: databases,

		id:     id,
		client: c,
	}
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
		Links []struct {
			ID    int
			Rank  string
			URL   string
			Title string
		}
	}

	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		level.Error(a.logger).Log("msg", "failed to parse db response", "err", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	sort.Slice(response.Links, func(i, j int) bool {
		return response.Links[i].Rank < response.Links[j].Rank
	})

	w.WriteHeader(http.StatusOK)
	if err := index.Execute(w, struct {
		Now   time.Time
		ID    string
		Links []struct {
			ID    int
			Rank  string
			URL   string
			Title string
		}
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

	url := strings.TrimSpace(r.PostForm.Get("url"))
	if url == "" {
		level.Error(a.logger).Log("msg", "empty url")
		http.Error(w, "empty url", http.StatusBadRequest)
		return
	}

	title := strings.TrimSpace(r.PostForm.Get("title"))
	if title == "" {
		level.Error(a.logger).Log("msg", "empty url")
		http.Error(w, "empty url", http.StatusBadRequest)
		return
	}

	hash := sha1.Sum([]byte(url))
	id := binary.BigEndian.Uint16(hash[:])

	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(struct {
		ID    int
		URL   string
		Title string
	}{
		ID:    int(id),
		URL:   url,
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

const indexTemplate = `
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>Grafana News</title>
	</head>
	<body>
		<h1>Grafana News</h1>
		<p>Current time: {{ .Now }}, App: {{ .ID }}</p>
		<table width="100%" border="1">
			<thead>
				<tr>
					<th>Rank</th>
					<th>Title</th>
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{{ range .Links }}
				<tr>
					<td>{{ .Rank }}</td>
					<td><a href="{{ .URL }}">{{ .Title }}</a></td>
					<td><button name="up" value="{{ .ID }}" type="submit">Up</button><button name="down" value="{{ .ID }}" type="submit">Down</button></td>
				</tr>
				{{ end }}
			</tbody>
		</table>

	  	<hr/>

		<form action="/post" method="post">
			Title: <input name="title" /><br/>
			URL: <input name="url" /><br/>
			<button name="submit" value="" type="submit">Submit</button>
		</form>

	</body>
</html>`

var index = template.Must(template.New("webpage").Parse(indexTemplate))
