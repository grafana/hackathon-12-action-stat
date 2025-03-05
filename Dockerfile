FROM grafana/alloy:latest

LABEL org.opencontainers.image.source="https://github.com/grafana/hackathon-12-action-stat"

RUN (type -p wget >/dev/null || (apt update && apt-get install wget -y)) \
	&& mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt update \
	&& apt install gh -y

COPY upload-logs.alloy /etc/alloy/
COPY entrypoint.sh get-logs.sh /etc/bin/

RUN chmod +x /etc/bin/entrypoint.sh
RUN chmod +x /etc/bin/get-logs.sh

WORKDIR /github/workspace

ENTRYPOINT ["/etc/bin/entrypoint.sh"]
