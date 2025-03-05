VERSION := $(shell cat version)
MAJOR_VERSION := "v0"

lint:
	shellcheck -x entrypoint.sh get-logs.sh

build: Dockerfile entrypoint.sh get-logs.sh
	docker build -t ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) .

push:
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(VERSION)

release:
	git tag -a -m "Release $(VERSION)" $(VERSION)
	git tag -f $(MAJOR_VERSION)
	git push origin tag $(MAJOR_VERSION)
	gh release create $(VERSION) --generate-notes
