default: run

build: db/db app/app lb/lb

run:
	docker-compose up -d

db/db:
	env GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/peterbourgon/tns/db
	docker build -t gouthamve/tns-db db/

app/app:
	env GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/peterbourgon/tns/app
	docker build -t gouthamve/tns-app app/

lb/lb:
	env GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o $@ github.com/peterbourgon/tns/lb
	docker build -t gouthamve/tns-lb lb/

clean:
	docker-compose kill || true
	docker-compose rm -f || true
	rm -f db/db app/app lb/lb
