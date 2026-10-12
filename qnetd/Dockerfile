FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      corosync-qnetd openssh-server jq \
    && rm -rf /var/lib/apt/lists/*
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
