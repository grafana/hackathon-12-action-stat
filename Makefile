VERSION := $(shell cat version)																									# e.g. v1.2.3
MINOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9].[0-9]\).[0-9]/\1/')  # e.g. v1.2
MAJOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9]\).[0-9].[0-9]/\1/')  # e.g. v1

lint: scripts/entrypoint.sh scripts/get-logs.sh
	shellcheck -x $<

build: Dockerfile scripts/entrypoint.sh scripts/get-logs.sh version configs/upload-logs.alloy
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


run-local:
ifndef WORKFLOW_RUN_ID
	$(error WORKFLOW_RUN_ID is not set)
endif
	docker run -it \
		-e GITHUB_REPOSITORY=grafana/k8s-monitoring-helm \
		-e GITHUB_WORKSPACE=/github/workspace \
		-e GH_TOKEN \
		-e TELEMETRY_URL \
		-e TELEMETRY_USERNAME \
		-e TELEMETRY_PASSWORD \
		-e UPLOAD_TIMEOUT=300 \
		-e WORKFLOW_RUN_ID \
		-v $(shell pwd)/../k8s-monitoring-helm:/github/workspace:ro \
		-v $(shell pwd)/scripts:/usr/local/bin \
		-v $(shell pwd)/configs:/etc/alloy \
		ghcr.io/grafana/hackathon-12-action-stat:latest

run-shell:
ifndef WORKFLOW_RUN_ID
	$(error WORKFLOW_RUN_ID is not set)
endif
	docker run -it \
		-e GITHUB_REPOSITORY=grafana/k8s-monitoring-helm \
		-e GITHUB_WORKSPACE=/github/workspace \
		-e GH_TOKEN \
		-e TELEMETRY_URL \
		-e TELEMETRY_USERNAME \
		-e TELEMETRY_PASSWORD \
		-e UPLOAD_TIMEOUT=300 \
		-e WORKFLOW_RUN_ID \
		-v $(shell pwd)/../k8s-monitoring-helm:/github/workspace:ro \
		-v $(shell pwd)/scripts:/usr/local/bin \
		-v $(shell pwd)/configs:/etc/alloy \
		--entrypoint /bin/bash \
		ghcr.io/grafana/hackathon-12-action-stat:latest
