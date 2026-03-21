# =============================================================================
# Observability (Elasticsearch + Kibana)
# =============================================================================

dev-observability-up:
	$(DC) --profile dev-observability up -d elasticsearch kibana

dev-observability-down:
	$(DC) --profile dev-observability stop elasticsearch kibana

# Registers the ingest pipeline and both index templates required by the sinks.
dev-es-setup:
	@set -euo pipefail; \
	printf '%s\n' 'Registering ingest pipeline...'; \
	curl --fail-with-body -sS -X PUT $(ELASTICSEARCH_URL)/_ingest/pipeline/internal-mail-tracking-pipeline \
	  -H 'Content-Type: application/json' \
	  --data @$(OBS_INGEST_PIPELINE); \
	printf '\n%s\n' 'Applying index templates...'; \
	curl --fail-with-body -sS -X PUT $(ELASTICSEARCH_URL)/_index_template/internal-mail-tracking-template \
	  -H 'Content-Type: application/json' \
	  --data @$(OBS_MAIN_TEMPLATE); \
	printf '\n'; \
	curl --fail-with-body -sS -X PUT $(ELASTICSEARCH_URL)/_index_template/internal-mail-tracking-deadletter-template \
	  -H 'Content-Type: application/json' \
	  --data @$(OBS_DLQ_TEMPLATE); \
	printf '\n%s\n' 'Elasticsearch setup complete.'

# Ensures target indices exist before registering sink connectors that map topics
# into explicit Elasticsearch index names.
dev-connect-setup: dev-es-setup
	@set -euo pipefail; \
	printf '%s\n' 'Ensuring Elasticsearch target indices exist...'; \
	if ! curl -fsS $(ELASTICSEARCH_URL)/$(OBS_MAIN_INDEX) >/dev/null 2>&1; then \
	  curl --fail-with-body -sS -X PUT $(ELASTICSEARCH_URL)/$(OBS_MAIN_INDEX); \
	  printf '\n'; \
	fi; \
	if curl -fsS $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX) >/dev/null 2>&1; then \
	  DLQ_SETTINGS=$$(curl -fsS $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX)/_settings); \
	  DLQ_MAPPING=$$(curl -fsS $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX)/_mapping); \
	  if echo "$$$$DLQ_SETTINGS" | grep -q '"default_pipeline":"internal-mail-tracking-pipeline"' || ! echo "$$$$DLQ_MAPPING" | grep -q '"raw_payload"'; then \
	    printf '%s\n' 'Recreating stale dead-letter index to pick up the corrected template...'; \
	    curl --fail-with-body -sS -X DELETE $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX); \
	    printf '\n'; \
	  fi; \
	fi; \
	if ! curl -fsS $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX) >/dev/null 2>&1; then \
	  curl --fail-with-body -sS -X PUT $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX); \
	  printf '\n'; \
	fi; \
	printf '%s\n' 'Registering Elasticsearch sink connectors...'; \
	curl --fail-with-body -sS -X PUT $(KAFKA_CONNECT_URL)/connectors/$(OBS_MAIN_CONNECTOR)/config \
	  -H 'Content-Type: application/json' \
	  --data @$(OBS_MAIN_CONNECTOR_CONFIG); \
	printf '\n'; \
	curl --fail-with-body -sS -X POST '$(KAFKA_CONNECT_URL)/connectors/$(OBS_MAIN_CONNECTOR)/restart?includeTasks=true&onlyFailed=false' >/dev/null; \
	curl --fail-with-body -sS -X PUT $(KAFKA_CONNECT_URL)/connectors/$(OBS_DLQ_CONNECTOR)/config \
	  -H 'Content-Type: application/json' \
	  --data @$(OBS_DLQ_CONNECTOR_CONFIG); \
	printf '\n'; \
	curl --fail-with-body -sS -X POST '$(KAFKA_CONNECT_URL)/connectors/$(OBS_DLQ_CONNECTOR)/restart?includeTasks=true&onlyFailed=false' >/dev/null; \
	printf '%s\n' 'Connector setup complete.'

# Prints the registered sink connectors and their current task state.
dev-connect-status:
	@set -euo pipefail; \
	printf '%s\n' 'Registered connectors:'; \
	curl --fail-with-body -sS $(KAFKA_CONNECT_URL)/connectors; \
	printf '\n\n%s\n' '$(OBS_MAIN_CONNECTOR) status:'; \
	curl --fail-with-body -sS $(KAFKA_CONNECT_URL)/connectors/$(OBS_MAIN_CONNECTOR)/status; \
	printf '\n\n%s\n' '$(OBS_DLQ_CONNECTOR) status:'; \
	curl --fail-with-body -sS $(KAFKA_CONNECT_URL)/connectors/$(OBS_DLQ_CONNECTOR)/status; \
	printf '\n'

dev-connect-logs:
	$(DC) logs -f kafka-connect

# Combines connector task status with document counts to show end-to-end sink
# health at a glance.
dev-connect-health: dev-connect-status
	@set -euo pipefail; \
	printf '\n%s\n' 'Elasticsearch document counts:'; \
	printf '%s\n' '$(OBS_MAIN_INDEX):'; \
	curl --fail-with-body -sS $(ELASTICSEARCH_URL)/$(OBS_MAIN_INDEX)/_count; \
	printf '\n\n%s\n' '$(OBS_DLQ_INDEX):'; \
	curl --fail-with-body -sS $(ELASTICSEARCH_URL)/$(OBS_DLQ_INDEX)/_count; \
	printf '\n'

# Publishes a malformed dashboard record and verifies that Kafka Connect routes
# it into the dead-letter Elasticsearch index.
dev-connect-dlq-smoke:
	./scripts/dev/smoke_test_kafka_connect_dlq.sh

# Converts repository dashboard JSON into NDJSON and imports it through the
# Kibana Saved Objects API.
dev-kibana-import:
	@command -v python3 >/dev/null || (echo "python3 not found" && exit 1)
	@test -f $(KIBANA_SO_CONVERTER) || (echo "missing converter script: $(KIBANA_SO_CONVERTER)" && exit 1)
	@set -euo pipefail; \
	TMP_DIR=$$(mktemp -d /tmp/kibana-import.XXXXXX); \
	OP_TMP=$$$$TMP_DIR/internal-mail-tracking-operational-dashboard.ndjson; \
	DLQ_TMP=$$$$TMP_DIR/internal-mail-tracking-deadletter-dashboard.ndjson; \
	trap 'rm -rf $$$$TMP_DIR' EXIT; \
	python3 $(KIBANA_SO_CONVERTER) \
	  --input $(OBS_MAIN_DASHBOARD) \
	  --output $$$$OP_TMP; \
	python3 $(KIBANA_SO_CONVERTER) \
	  --input $(OBS_DLQ_DASHBOARD) \
	  --output $$$$DLQ_TMP; \
	test -s $$$$OP_TMP; \
	test -s $$$$DLQ_TMP; \
	echo "Importing operational tracking dashboard..."; \
	curl --fail-with-body -sS -X POST "$(KIBANA_URL)/api/saved_objects/_import?overwrite=true" \
	  -H "kbn-xsrf: true" \
	  -F "file=@$$$$OP_TMP;type=application/x-ndjson;filename=internal-mail-tracking-operational-dashboard.ndjson"; \
	echo ""; \
	echo "Importing dead-letter dashboard..."; \
	curl --fail-with-body -sS -X POST "$(KIBANA_URL)/api/saved_objects/_import?overwrite=true" \
	  -H "kbn-xsrf: true" \
	  -F "file=@$$$$DLQ_TMP;type=application/x-ndjson;filename=internal-mail-tracking-deadletter-dashboard.ndjson"; \
	echo ""; \
	echo "Kibana import complete. Open $(KIBANA_URL) to view dashboards."

# One-command bootstrap for the full local observability path.
dev-observability-setup: dev-observability-up dev-connect-setup
	@set -euo pipefail; \
	printf '%s\n' 'Waiting for Kibana to become ready...'; \
	until curl -fsS $(KIBANA_URL)/api/status >/dev/null; do \
	  sleep 2; \
	done; \
	$(MAKE) dev-kibana-import