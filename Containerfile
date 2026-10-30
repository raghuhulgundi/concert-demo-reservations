FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server.py config.json VERSION ./
COPY static ./static
# Data and certificates live on the /data volume so they survive container rebuilds.
ENV RESERVE_DB=/data/reservations.db \
    RESERVE_TLS_CERT=/data/certs/server.crt \
    RESERVE_TLS_KEY=/data/certs/server.key \
    RESERVE_PORT=8443
VOLUME ["/data"]
EXPOSE 8443
CMD ["python3", "server.py"]
