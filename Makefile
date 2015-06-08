all: db/db app/app
	docker-compose kill || true
	docker-compose rm -f || true
	docker-compose build
	docker-compose up -d

db/db:
	env GOOS=linux GOARCH=amd64 go build -o $@ github.com/peterbourgon/tns/db

app/app:
	env GOOS=linux GOARCH=amd64 go build -o $@ github.com/peterbourgon/tns/app

clean:
	docker-compose kill || true
	docker-compose rm -f || true
	rm db/db app/app
