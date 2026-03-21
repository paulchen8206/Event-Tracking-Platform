#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://localhost:9200}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-etp-kafka}"
KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-kafka:29092}"
SOURCE_TOPIC="${SOURCE_TOPIC:-evt.mail.internal.tracking.dashboard}"
DLQ_INDEX="${DLQ_INDEX:-internal-mail-tracking-deadletter}"
PRIMARY_CONNECTOR_NAME="${PRIMARY_CONNECTOR_NAME:-internal-mail-tracking-elasticsearch-sink}"
DLQ_CONNECTOR_NAME="${DLQ_CONNECTOR_NAME:-internal-mail-tracking-deadletter-elasticsearch-sink}"
CONNECT_TIMEOUT_SECONDS="${CONNECT_TIMEOUT_SECONDS:-60}"
ES_TIMEOUT_SECONDS="${ES_TIMEOUT_SECONDS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

PRIMARY_CONNECTOR_CONFIG="${ROOT_DIR}/platform/kafka/connect/elasticsearch/internal-mail-tracking-sink.json"
DLQ_CONNECTOR_CONFIG="${ROOT_DIR}/platform/kafka/connect/elasticsearch/internal-mail-tracking-deadletter-sink.json"
DLQ_TEMPLATE_FILE="${ROOT_DIR}/storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local timeout="$2"
  local label="$3"
  local elapsed=0

  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "Ready: $label"
      return 0
    fi
    if [[ "$elapsed" -ge "$timeout" ]]; then
      echo "Timed out waiting for $label at $url" >&2
      return 1
    fi
    sleep "$SLEEP_SECONDS"
    elapsed=$((elapsed + SLEEP_SECONDS))
  done
}

register_connector() {
  local connector_name="$1"
  local config_file="$2"

  echo "Registering connector: $connector_name"
  curl -fsS -X PUT \
    "${CONNECT_URL}/connectors/${connector_name}/config" \
    -H 'Content-Type: application/json' \
    --data @"$config_file" >/dev/null

  curl -fsS -X POST \
    "${CONNECT_URL}/connectors/${connector_name}/restart?includeTasks=true&onlyFailed=false" >/dev/null
}

ensure_dlq_index() {
  local recreate_index=false

  if curl -fsS "${ELASTICSEARCH_URL}/${DLQ_INDEX}" >/dev/null 2>&1; then
    local settings
    local mapping
    settings="$(curl -fsS "${ELASTICSEARCH_URL}/${DLQ_INDEX}/_settings")"
    mapping="$(curl -fsS "${ELASTICSEARCH_URL}/${DLQ_INDEX}/_mapping")"

    if [[ "$settings" == *'"default_pipeline":"internal-mail-tracking-pipeline"'* ]] || [[ "$mapping" != *'"raw_payload"'* ]]; then
      recreate_index=true
    fi
  fi

  if [[ "$recreate_index" == true ]]; then
    echo "Recreating stale dead-letter index: ${DLQ_INDEX}"
    curl -fsS -X DELETE "${ELASTICSEARCH_URL}/${DLQ_INDEX}" >/dev/null
  fi

  if ! curl -fsS "${ELASTICSEARCH_URL}/${DLQ_INDEX}" >/dev/null 2>&1; then
    echo "Creating dead-letter index: ${DLQ_INDEX}"
    curl -fsS -X PUT "${ELASTICSEARCH_URL}/${DLQ_INDEX}" >/dev/null
  fi
}

assert_connector_running() {
  local connector_name="$1"
  local elapsed=0

  while true; do
    local state
    state="$(curl -fsS "${CONNECT_URL}/connectors/${connector_name}/status" | sed -n 's/.*"state":"\([A-Z]*\)".*/\1/p' | head -n1)"

    if [[ "$state" == "RUNNING" ]]; then
      echo "Connector RUNNING: $connector_name"
      return 0
    fi

    if [[ "$elapsed" -ge "$CONNECT_TIMEOUT_SECONDS" ]]; then
      echo "Connector is not RUNNING: $connector_name (state=$state)" >&2
      exit 1
    fi

    sleep "$SLEEP_SECONDS"
    elapsed=$((elapsed + SLEEP_SECONDS))
  done
}

publish_malformed_record() {
  local marker="$1"
  local payload="MALFORMED_NON_JSON_${marker}"

  echo "Publishing malformed record to ${SOURCE_TOPIC}: ${payload}"
  docker exec -i "$KAFKA_CONTAINER" kafka-console-producer \
    --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" \
    --topic "$SOURCE_TOPIC" >/dev/null <<<"$payload"
}

wait_for_dlq_document() {
  local marker="$1"
  local elapsed=0

  echo "Waiting for dead-letter document in index: ${DLQ_INDEX}"
  while true; do
    local hits
    hits="$(curl -fsS -X POST "${ELASTICSEARCH_URL}/${DLQ_INDEX}/_search" \
      -H 'Content-Type: application/json' \
      -d "{\"size\":0,\"query\":{\"match_phrase\":{\"raw_payload\":\"MALFORMED_NON_JSON_${marker}\"}}}" \
      | sed -n 's/.*"value":\([0-9][0-9]*\).*/\1/p' | head -n1)"

    if [[ -n "$hits" && "$hits" -ge 1 ]]; then
      echo "Verified: malformed record reached dead-letter index (${hits} hit(s))."
      return 0
    fi

    if [[ "$elapsed" -ge "$ES_TIMEOUT_SECONDS" ]]; then
      echo "Timed out waiting for dead-letter document in ${DLQ_INDEX}." >&2
      return 1
    fi

    sleep "$SLEEP_SECONDS"
    elapsed=$((elapsed + SLEEP_SECONDS))
  done
}

main() {
  require_command curl
  require_command docker
  require_command sed

  if [[ ! -f "$PRIMARY_CONNECTOR_CONFIG" || ! -f "$DLQ_CONNECTOR_CONFIG" || ! -f "$DLQ_TEMPLATE_FILE" ]]; then
    echo "Expected connector/template files are missing under repository root." >&2
    exit 1
  fi

  wait_for_http "${CONNECT_URL}/connectors" "$CONNECT_TIMEOUT_SECONDS" "Kafka Connect"
  wait_for_http "${ELASTICSEARCH_URL}" "$ES_TIMEOUT_SECONDS" "Elasticsearch"

  echo "Applying dead-letter index template"
  curl -fsS -X PUT \
    "${ELASTICSEARCH_URL}/_index_template/internal-mail-tracking-deadletter-template" \
    -H 'Content-Type: application/json' \
    --data @"$DLQ_TEMPLATE_FILE" >/dev/null

  ensure_dlq_index

  register_connector "$PRIMARY_CONNECTOR_NAME" "$PRIMARY_CONNECTOR_CONFIG"
  register_connector "$DLQ_CONNECTOR_NAME" "$DLQ_CONNECTOR_CONFIG"

  assert_connector_running "$PRIMARY_CONNECTOR_NAME"
  assert_connector_running "$DLQ_CONNECTOR_NAME"

  local marker
  marker="$(date +%s)"
  publish_malformed_record "$marker"
  wait_for_dlq_document "$marker"

  echo "Smoke test passed."
}

main "$@"
