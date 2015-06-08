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
	"syscall"
	"time"
)

const (
	dbPort = ":9000"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	peers := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + dbPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("peer %s", u.String())
		peers = append(peers, u)
	}
	log.Printf("%d peer(s)", len(peers))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("%x", h.Sum(nil))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "db-%s OK\n", id)
	})

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
			log.Printf("%d successful GET(s)", count)
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
