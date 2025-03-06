VERSION := $(shell cat version)																									# e.g. v1.2.3
MINOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9].[0-9]\).[0-9]/\1/')  # e.g. v1.2
MAJOR_VERSION := $(shell echo $(VERSION) | sed 's/\(v[0-9]\).[0-9].[0-9]/\1/')  # e.g. v1
export DOCKER_BUILDKIT=1

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

lint: scripts/entrypoint.sh scripts/get-logs.sh
	shellcheck -x $<

build-push-image: check-docker check-buildx check-arch \
	Dockerfile scripts/entrypoint.sh scripts/get-logs.sh version configs/upload-logs.alloy
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


run-local: check-docker
	docker run -it \
		--platform linux/$(shell uname -m) \
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

run-shell: check-docker
	docker run -it \
		--platform linux/$(shell uname -m) \
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
