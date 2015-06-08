all: db/db app/app lb/lb
	docker-compose build

run:
	docker-compose up -d

db/db:
	env GOOS=linux GOARCH=amd64 go build -o $@ github.com/peterbourgon/tns/db

app/app:
	env GOOS=linux GOARCH=amd64 go build -o $@ github.com/peterbourgon/tns/app

lb/lb:
	env GOOS=linux GOARCH=amd64 go build -o $@ github.com/peterbourgon/tns/lb

clean:
	docker-compose kill || true
	docker-compose rm -f || true
	rm -f db/db app/app lb/lb
