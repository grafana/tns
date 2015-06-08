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
	dbPort  = ":9000"
	appPort = ":8080"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	databases := []*url.URL{}
	for _, host := range os.Args[1:] {
		if _, _, err := net.SplitHostPort(host); err != nil {
			host = host + dbPort
		}
		u, err := url.Parse(fmt.Sprintf("http://%s", host))
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("database %s", u.String())
		databases = append(databases, u)
	}
	log.Printf("%d peer(s)", len(databases))

	h := md5.New()
	fmt.Fprintf(h, "%d", rand.Int63())
	id := fmt.Sprintf("app-%x", h.Sum(nil))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		db := databases[rand.Intn(len(databases))].String()
		defer func(begin time.Time) {
			log.Printf("served request from %s via %s in %s", r.RemoteAddr, db, time.Since(begin))
		}(time.Now())

		resp, err := http.Get(db)
		if err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprintf(w, "%v\n", err)
			return
		}

		fmt.Fprintf(w, "%s via %s\n", id, db)
		io.Copy(w, resp.Body)
		resp.Body.Close()
	})

	errc := make(chan error)
	go func() { errc <- http.ListenAndServe(appPort, nil) }()
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
