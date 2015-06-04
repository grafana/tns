package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

func main() {
	var (
		addr = flag.String("addr", ":8080", "listen address")
		db   = flag.String("db", "db.weave.local", "database address")
	)
	flag.Parse()

	id := makeID()
	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "%s\n%s\n", id, catNodes(*db))
	})

	errc := make(chan error)
	go func() { errc <- http.ListenAndServe(*addr, nil) }()
	go func() { errc <- interrupt() }()
	log.Print(<-errc)
}

func makeID() string {
	rand.Seed(time.Now().UnixNano())
	h := md5.New()
	fmt.Fprint(h, rand.Int63())
	return fmt.Sprintf("%x", h.Sum(nil)[:8])
}

func catNodes(db string) string {
	if !strings.HasPrefix(db, "http") {
		db = "http://" + db
	}
	u, err := url.Parse(db)
	if err != nil {
		return err.Error()
	}
	if _, port, err := net.SplitHostPort(u.Host); err != nil || port == "" {
		u.Host = u.Host + ":9200"
	}
	u.Path = "_cat/nodes"

	resp, err := http.Get(u.String())
	if err != nil {
		return err.Error()
	}
	defer resp.Body.Close()

	buf, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err.Error()
	}

	return string(buf)
}

func interrupt() error {
	c := make(chan os.Signal)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	return fmt.Errorf("%s", <-c)
}
