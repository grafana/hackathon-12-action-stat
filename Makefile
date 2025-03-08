VERSION := $(shell if [ -f version ]; then cat version; else echo "Error: version file not found"; exit 1; fi)  # e.g. v0.11.0
MINOR_VERSION := $(shell echo $(VERSION) | cut -d. -f1,2)  # e.g. v0.11
MAJOR_VERSION := $(shell echo $(VERSION) | cut -d. -f1)  # e.g. v0

export DOCKER_BUILDKIT=1

.PHONY: check-buildx check-arch check-docker build lint push release run-local run-shell ghcr-login versions

versions:
	@echo sem_var:	$(VERSION)
	@echo minor:		$(MINOR_VERSION)
	@echo major:		$(MAJOR_VERSION)

ghcr-login:
		source .env && echo $$CR_PAT | docker login ghcr.io -u $$USERNAME --password-stdin

check-docker:
	@if ! docker info &> /dev/null; then \
		echo "Error: Docker daemon is not running. Please start Docker first."; \
		exit 1; \
	fi

check-buildx: check-docker
	@if ! command -v docker buildx &> /dev/null; then \
		echo "Error: docker buildx is not installed. Please install it first."; \
		exit 1; \
	fi
	@if ! docker buildx ls | grep -q "multiarch"; then \
		echo "Creating multi-arch builder..."; \
		docker buildx create --name multiarch --driver docker-container --bootstrap; \
	fi
	@docker buildx use multiarch
	@if ! docker buildx ls | grep -q "linux/amd64.*linux/arm64"; then \
		echo "Error: No buildx builder found supporting both linux/amd64 and linux/arm64."; \
		echo "Please create a multi-arch builder using: docker buildx create --name multiarch --driver docker-container --bootstrap"; \
		exit 1; \
	fi

check-arch: check-docker
	@if ! docker buildx inspect | grep -q "linux/amd64"; then \
		echo "Error: linux/amd64 architecture not supported by current builder."; \
		exit 1; \
	fi
	@if ! docker buildx inspect | grep -q "linux/arm64"; then \
		echo "Error: linux/arm64 architecture not supported by current builder."; \
		exit 1; \
	fi

lint: scripts/entrypoint.sh scripts/collect-logs.sh
	shellcheck -x $<

build-push-image: check-docker check-buildx check-arch \
	Dockerfile scripts/entrypoint.sh scripts/collect-logs.sh version configs/gha-observability.alloy
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag ghcr.io/grafana/hackathon-12-action-stat:latest \
		--tag ghcr.io/grafana/hackathon-12-action-stat:$(VERSION) \
		--tag ghcr.io/grafana/hackathon-12-action-stat:$(MAJOR_VERSION) \
		--tag ghcr.io/grafana/hackathon-12-action-stat:$(MINOR_VERSION) \
		--push \
		.

release:
	git tag -a -m "Release $(VERSION)" $(VERSION)
	git push origin tag $(VERSION)
	gh release create $(VERSION) --generate-notes

	git tag -f $(MINOR_VERSION)
	git push -f origin tag $(MINOR_VERSION)

	git tag -f $(MAJOR_VERSION)
	git push -f origin tag $(MAJOR_VERSION)

build-push-release: build-push-image release

run-local: check-docker
	docker run -it \
		--platform linux/$(shell uname -m) \
		-e GITHUB_REPOSITORY=grafana/k8s-monitoring-helm \
		-e GITHUB_WORKSPACE=/github/workspace \
		-e LOGS_DIRECTORY=/var/log/gha/logs \
		-e METRICS_DIRECTORY=/var/log/gha/metrics \
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

run-shell: check-docker
	docker run -it \
		--platform linux/$(shell uname -m) \
		-e GITHUB_REPOSITORY=grafana/k8s-monitoring-helm \
		-e GITHUB_WORKSPACE=/github/workspace \
		-e LOGS_DIRECTORY=/var/log/gha/logs \
		-e METRICS_DIRECTORY=/var/log/gha/metrics \
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
