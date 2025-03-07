FROM grafana/alloy:latest

LABEL org.opencontainers.image.source="https://github.com/grafana/hackathon-12-action-stat" \
	org.opencontainers.image.description="Multi-arch GitHub Action to upload telemetry data to an OTLP endpoint"

RUN (type -p wget >/dev/null || (apt update && apt-get install wget -y)) \
	&& mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt update \
	&& apt install gh jq -y

COPY version /version
COPY configs/gha-observability.alloy /etc/alloy/
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/collect-logs.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/collect-logs.sh

ENV LOGS_DIRECTORY="github-actions/logs"
RUN mkdir -p ${LOGS_DIRECTORY}

ENV METRICS_DIRECTORY="github-actions/metrics"
RUN mkdir -p ${METRICS_DIRECTORY}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
