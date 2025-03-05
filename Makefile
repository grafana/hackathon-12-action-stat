VERSION := $(shell cat version)																									# e.g. v1.2.3
MINOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9].[0-9]\).[0-9]/\1/')  # e.g. v1.2
MAJOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9]\).[0-9].[0-9]/\1/')  # e.g. v1

lint:
	shellcheck -x entrypoint.sh get-logs.sh

build: Dockerfile entrypoint.sh get-logs.sh
	docker build \
		--platform linux/amd64 \
		--tag ghcr.io/grafana/hackathon-12-action-stat:latest \
		.

	docker tag \
		ghcr.io/grafana/hackathon-12-action-stat:latest \
		ghcr.io/grafana/hackathon-12-action-stat:$(VERSION)

	docker tag \
		ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) \
		ghcr.io/grafana/hackathon-12-action-stat:$(MAJOR_VERSION)

	docker tag \
		ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) \
		ghcr.io/grafana/hackathon-12-action-stat:$(MINOR_VERSION)

push:
	docker push ghcr.io/grafana/hackathon-12-action-stat:latest
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(VERSION)
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(MINOR_VERSION)
	docker push ghcr.io/grafana/hackathon-12-action-stat:$(MAJOR_VERSION)

release:
	git tag -a -m "Release $(VERSION)" $(VERSION)
	git push origin tag $(VERSION)
	gh release create $(VERSION) --generate-notes

	git tag -f $(MINOR_VERSION)
	git push -f origin tag $(MINOR_VERSION)

	git tag -f $(MAJOR_VERSION)
	git push -f origin tag $(MAJOR_VERSION)
