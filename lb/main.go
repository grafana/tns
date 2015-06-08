package main

import (
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
	"syscall"
	"time"
)

const (
	appPort = ":8080"
	lbPort  = ":80"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	apps := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + appPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("database %s", u.String())
		apps = append(apps, u)
	}
	log.Printf("%d peer(s)", len(apps))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("lb-%x", h.Sum(nil))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		app := apps[rand.Intn(len(apps))].String()
		defer func(begin time.Time) {
			log.Printf("served request from %s via %s in %s", r.RemoteAddr, app, time.Since(begin))
		}(time.Now())

		resp, err := http.Get(app)
		if err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprintf(w, "%v\n", err)
			return
		}

		fmt.Fprintf(w, "%s via %s\n", id, app)
		io.Copy(w, resp.Body)
		resp.Body.Close()
	})

	errc := make(chan error)
	go func() { errc <- http.ListenAndServe(lbPort, nil) }()
	go func() { errc <- loop(apps) }()
	go func() { errc <- interrupt() }()
	log.Fatal(<-errc)
}

func loop(apps []*url.URL) error {
	// Simulate traffic.
	for range time.Tick(time.Second) {
		resp, err := http.Get("http://localhost" + lbPort)
		if err != nil {
			log.Print(err)
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
