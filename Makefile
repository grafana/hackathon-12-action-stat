VERSION := $(shell cat version)

build: Dockerfile entrypoint.sh get-logs.sh
	docker build -t ghcr.io/grafana/action-stats:$(VERSION) .

push:
	docker push ghcr.io/grafana/action-stats:$(VERSION)

release:
	git tag -a -m "Release $(VERSION)" $(VERSION)
	git push --follow-tags
	gh release create $(VERSION) --generate-notes
