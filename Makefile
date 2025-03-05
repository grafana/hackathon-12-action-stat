VERSION := $(shell cat version)
MAJOR_VERSION := "v0"

lint:
	shellcheck -x entrypoint.sh get-logs.sh

build: Dockerfile entrypoint.sh get-logs.sh
	docker build -t ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) .
	docker tag ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) ghcr.io/grafana/hackathon-12-action-stat:$(MAJOR_VERSION)

push:
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(VERSION)
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(MAJOR_VERSION)

release:
	git tag -a -m "Release $(VERSION)" $(VERSION)
	git push origin tag $(VERSION)
	git tag -f $(MAJOR_VERSION)
	git push -f origin tag $(MAJOR_VERSION)
	gh release create $(VERSION) --generate-notes
