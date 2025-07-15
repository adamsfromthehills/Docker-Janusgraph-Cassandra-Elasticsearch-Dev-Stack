#!/usr/bin/env bash
set -euo pipefail

CASSANDRA_HOST=${CASSANDRA_HOST:-cassandra}
CASSANDRA_PORT=${CASSANDRA_PORT:-9042}
ES_HOST=${ES_HOST:-elasticsearch}
ES_PORT=${ES_PORT:-9200}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-60}
MODE=${MODE:-server}

wait_for_port() {
  local host=$1 port=$2 timeout=$3
  echo ">>> Waiting for $host:$port (timeout ${timeout}s)…"
  for ((i=0;i<timeout;i++)); do
    if bash -c "</dev/tcp/$host/$port" &>/dev/null; then
      echo ">>> $host:$port is up"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: timed out after ${timeout}s waiting for $host:$port"
  exit 1
}

wait_for_port "$CASSANDRA_HOST" "$CASSANDRA_PORT" "$WAIT_TIMEOUT"
wait_for_port "$ES_HOST"        "$ES_PORT"        "$WAIT_TIMEOUT"

if [[ "$MODE" == "mgmt" ]]; then
  echo ">>> JanusGraph in MGMT mode – server will not start"

  # generate config files so you can open the graph from the console
  /usr/local/bin/docker-entrypoint.sh janusgraph show-config > /dev/null

  exec sleep infinity
fi

echo ">>> Starting JanusGraph Server"
exec /usr/local/bin/docker-entrypoint.sh janusgraph