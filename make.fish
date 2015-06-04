#!/usr/bin/env fish

function usage
	echo (basename (status -f)) "(build, clean)"
end

if set -q $argv
	usage
	exit 1
end

if test (uname) = "Darwin"
	boot2docker shellinit 2>/dev/null | while read line ; eval $line ; end
end

set prefix "peterbourgon/tns"

switch $argv
	case clean
		docker ps -a | grep $prefix | awk '{print $1}' | xargs docker stop
		docker ps -a | grep $prefix | awk '{print $1}' | xargs docker rm
		docker images | grep $prefix | awk '{print $3}' | xargs docker rmi

	case build
		docker build -t $prefix-db elasticsearch
		cd app ; env GOOS=linux GOARCH=amd64 go build ; cd ..
		docker build -t $prefix-app app
		docker build -t $prefix-lb nginx

	case run
		weave run --with-dns --hostname=db.weave.local $prefix-db
		weave run --with-dns --hostname=db.weave.local $prefix-db
		weave run --with-dns --hostname=app.weave.local $prefix-app
		weave run --with-dns --hostname=app.weave.local $prefix-app
		weave run --with-dns --hostname=lb.weave.local $prefix-lb
		weave run --with-dns --hostname=lb.weave.local $prefix-lb

	case '*'
		usage
		exit 2
end

