# =============================================================================
# Local Stack Lifecycle
# =============================================================================

dev-stack-up:
	$(DC) $(STACK_PROFILES) up -d --build

# Reusable target templates for profile-scoped up/log operations.
define PROFILE_UP_TARGET
$(1):
	$(DC) --profile $(2) up -d --build $(3)
endef

define LOGS_TARGET
$(1):
	$(DC) logs -f $(2)
endef

$(eval $(call PROFILE_UP_TARGET,dev-producers-up,dev-producers,$(DEV_PRODUCER_SERVICES)))
$(eval $(call LOGS_TARGET,dev-producers-logs,$(DEV_PRODUCER_SERVICES)))

# Builds the CDC bridge locally and publishes Debezium-style events into Kafka.
dev-cdc-bridge:
	mvn -f $(CDC_BRIDGE_POM) -q -DskipTests package
	KAFKA_BOOTSTRAP_SERVERS=$(LOCAL_KAFKA_BOOTSTRAP) SCHEMA_REGISTRY_URL=$(LOCAL_SCHEMA_REGISTRY_URL) java -jar $(CDC_BRIDGE_JAR)

# Reusable template for Flink cluster submission via JobManager container.
define FLINK_ROUTER_TARGET
dev-flink-$(1)-router: dev-flink-ui-up
	$(FLINK_BUILD_CMD) mvn -f $(2) -q -DskipTests package
	@JAR_PATH=$$$$(ls $(3) | head -1); \
	if [ -z "$$$$JAR_PATH" ]; then echo "Flink jar not found for target dev-flink-$(1)-router" && exit 1; fi; \
	echo "Submitting $$$$JAR_PATH to Flink JobManager..."; \
	$(FLINK_JOBMANAGER_EXEC) sh -lc "mkdir -p /opt/flink/usrlib"; \
	docker cp "$$$$JAR_PATH" $(FLINK_JOBMANAGER_CONTAINER):/opt/flink/usrlib/$(1)-router.jar; \
	$(FLINK_JOBMANAGER_EXEC) sh -lc "KAFKA_BOOTSTRAP_SERVERS=$(FLINK_KAFKA_BOOTSTRAP) flink run -d /opt/flink/usrlib/$(1)-router.jar"
endef

$(eval $(call FLINK_ROUTER_TARGET,mail,$(FLINK_MAIL_ROUTER_POM),$(FLINK_MAIL_ROUTER_JAR)))
$(eval $(call FLINK_ROUTER_TARGET,ops,$(FLINK_OPS_ROUTER_POM),$(FLINK_OPS_ROUTER_JAR)))

dev-flink-all: $(FLINK_ROUTER_TARGETS)

dev-flink-jobs: dev-flink-ui-up
	$(FLINK_JOBMANAGER_EXEC) flink list

$(eval $(call PROFILE_UP_TARGET,dev-flink-ui-up,dev-flink-ui,$(FLINK_UI_SERVICES)))
$(eval $(call LOGS_TARGET,dev-flink-ui-logs,$(FLINK_UI_SERVICES)))

# Publishes synthetic analytics events for local throughput and pipeline checks.
dev-produce-analytics:
	@COUNT=$${ANALYTICS_EVENT_COUNT:-10000}; \
	for i in $$(seq 1 $$COUNT); do \
	  echo "{\"event_id\":\"evt-seed-$$i\",\"event_type\":\"mail.delivered\",\"event_version\":\"1.0.0\",\"event_time\":\"2026-03-20T08:20:00Z\",\"ingested_at\":\"2026-03-20T08:20:01Z\",\"source_system\":\"make.seed\",\"tenant_id\":\"tenant-$$((($$i % 20) + 1))\",\"message_id\":\"msg-seed-$$i\",\"correlation_id\":\"corr-seed-$$i\",\"trace_id\":\"trace-seed-$$i\",\"actor_type\":\"service\",\"payload\":\"{}\"}"; \
	done | $(DC) exec -T kafka \
	  kafka-console-producer --bootstrap-server $(DOCKER_KAFKA_BOOTSTRAP) --topic $(ANALYTICS_TOPIC); \
	echo "Published $$COUNT events to $(ANALYTICS_TOPIC)"

# =============================================================================
# Bootstrap
# =============================================================================

# Installs local Kafka bootstrap dependencies, creates topics, and syncs schemas.
dev-bootstrap:
	@echo "==> Installing bootstrap Python deps..."
	pip3 install -q -r $(BOOTSTRAP_REQUIREMENTS)
	@echo "==> Creating Kafka topics..."
	python3 $(BOOTSTRAP_KAFKA_SCRIPT) \
	  --bootstrap-servers $(LOCAL_KAFKA_BOOTSTRAP) \
	  --schema-registry-url $(LOCAL_SCHEMA_REGISTRY_URL)
	@echo "==> Registering Avro schemas..."
	python3 $(BOOTSTRAP_SCHEMA_SCRIPT) \
	  --schema-registry-url $(LOCAL_SCHEMA_REGISTRY_URL)
	@echo "==> Bootstrap complete."

# =============================================================================
# Topic Peek Helpers
# =============================================================================

# Each target prints up to 5 messages from the named topic and exits.
# Requires the Compose stack to be running (make dev-stack-up).

define PEEK_TARGET
dev-peek-$(1):
	$(DC) exec kafka \
	  kafka-console-consumer \
	    --bootstrap-server $(DOCKER_KAFKA_BOOTSTRAP) \
	    --topic $(2) \
	    --from-beginning --max-messages 5 \
	    --timeout-ms 10000
endef

$(eval $(call PEEK_TARGET,tracking,$(TRACKING_TOPIC)))
$(eval $(call PEEK_TARGET,dashboard,$(DASHBOARD_TOPIC)))
$(eval $(call PEEK_TARGET,analytics,$(ANALYTICS_TOPIC)))

# =============================================================================
# Lakehouse Runtime
# =============================================================================

$(eval $(call PROFILE_UP_TARGET,dev-lakehouse-up,dev-lakehouse,minio minio-init canonical-lakehouse-consumer))
$(eval $(call LOGS_TARGET,dev-lakehouse-logs,canonical-lakehouse-consumer))

# Runs a lightweight local validation of the Spark-to-Iceberg path.
dev-lakehouse-smoke: dev-lakehouse-up dev-produce-analytics
	@echo "==> Waiting for lakehouse consumer to process a batch..."
	@sleep 10
	@$(DC) logs --tail=200 canonical-lakehouse-consumer 2>&1 \
	  | egrep -i "Processed micro-batch|Started customer analytics consumer" \
	  | tail -5
	@echo "==> Checking Iceberg metadata in MinIO..."
	@$(DC) exec minio sh -lc \
	  "ls -1 /data/event-tracking-lakehouse/warehouse/customer_analytics/tableau_reporting_events/metadata | tail -5"
	@echo "==> Lakehouse smoke check passed."

# =============================================================================
# dbt Semantic Layer (Snowflake)
# =============================================================================

# Reusable template for dbt commands executed inside the container.
define DBT_CMD_TARGET
$(1): dev-dbt-up
	$(DC) exec $(DBT_SERVICE) dbt $(2)
endef

# Keeps the dbt runtime container available for iterative local commands.
dev-dbt-up:
	$(DC) --profile dev-dbt up -d $(DBT_SERVICE)

dev-dbt-down:
	$(DC) --profile dev-dbt stop $(DBT_SERVICE)

# Starts both Airflow and the orchestration-api sidecar it depends on.
dev-airflow-up:
	$(DC) --profile dev-airflow up -d --build airflow orchestration-api

$(eval $(call LOGS_TARGET,dev-airflow-logs,airflow))
$(eval $(call LOGS_TARGET,dev-orchestration-api-logs,orchestration-api))

# Confirms orchestration-api is reachable from the host (host port 8091).
dev-orchestration-api-health:
	curl -fsS http://localhost:8091/health

dev-airflow-down:
	$(DC) --profile dev-airflow stop airflow orchestration-api

$(eval $(call DBT_CMD_TARGET,dev-dbt-deps,deps))
$(eval $(call DBT_CMD_TARGET,dev-dbt-debug,debug --target $(DBT_TARGET)))
$(eval $(call DBT_CMD_TARGET,dev-dbt-build,build --target $(DBT_TARGET) --select $(DBT_BUILD_SELECT)))

# Copies the large Snowflake seed SQL into the dbt container and executes it
# through the Snowflake Python connector bundled with the runtime image.
dev-dbt-seed-large: dev-dbt-up
	docker cp $(SEED_LARGE_SQL) $(DBT_CONTAINER):/tmp/seed_large.sql
	$(DC) exec $(DBT_SERVICE) python3 -c 'import snowflake.connector,os;conn=snowflake.connector.connect(account=os.environ['"'"'DBT_SNOWFLAKE_ACCOUNT'"'"'],user=os.environ['"'"'DBT_SNOWFLAKE_USER'"'"'],password=os.environ['"'"'DBT_SNOWFLAKE_PASSWORD'"'"'],role=os.environ['"'"'DBT_SNOWFLAKE_ROLE'"'"'],warehouse=os.environ['"'"'DBT_SNOWFLAKE_WAREHOUSE'"'"'],database=os.environ['"'"'DBT_SNOWFLAKE_DATABASE'"'"']);cur=conn.cursor();sql=open('"'"'/tmp/seed_large.sql'"'"').read();[cur.execute(s.strip()) for s in sql.split('"'"';'"'"') if s.strip()];cur.execute('"'"'SELECT COUNT(*) FROM ICEBERG_CUSTOMER_ANALYTICS.TABLEAU_REPORTING_EVENTS'"'"');print('"'"'TABLEAU_REPORTING_EVENTS rows:'"'"',cur.fetchone()[0]);cur.close();conn.close()'

# =============================================================================
# End-to-End Pipeline Smoke
# =============================================================================

# Bootstraps topics, starts dev producer containers, and then prints the two
# Flink job commands that must be run in separate terminals to complete the
# end-to-end pipeline.
dev-pipeline-smoke: dev-stack-up dev-bootstrap dev-producers-up
	@echo ""
	@echo "================================================================="
	@echo " Dev pipeline smoke test: infrastructure + producers are running."
	@echo "================================================================="
	@echo ""
	@echo "Now open TWO additional terminal tabs and run one command per tab:"
	@echo ""
	@echo "  Tab 1 — mail lifecycle router (CDC -> evt.mail.internal.tracking + analytics):"
	@echo "    make dev-flink-mail-router"
	@echo ""
	@echo "  Tab 2 — operational tracking router (evt.mail.operational.raw -> dashboard):"
	@echo "    make dev-flink-ops-router"
	@echo ""
	@echo "While the Flink jobs are running you can inspect output topics:"
	@echo "    make dev-peek-tracking      # $(TRACKING_TOPIC)"
	@echo "    make dev-peek-dashboard     # $(DASHBOARD_TOPIC)"
	@echo "    make dev-peek-analytics     # $(ANALYTICS_TOPIC)"
	@echo ""
	@echo "  NOTE: the CDC pipeline also requires the cdc-consumer bridge:"
	@echo "    cd services/cdc-consumer && KAFKA_BOOTSTRAP_SERVERS=$(LOCAL_KAFKA_BOOTSTRAP) \\" 
	@echo "      SCHEMA_REGISTRY_URL=$(LOCAL_SCHEMA_REGISTRY_URL) \\" 
	@echo "      mvn -q -DskipTests exec:java \\" 
	@echo "        -Dexec.mainClass=com.eventtracking.cdc.DebeziumPostgresCdcProducer \\" 
	@echo "        -Dexec.classpathScope=compile"
	@echo ""
	@echo "Tail producer logs at any time:  make dev-producers-logs"
	@echo "Tear down everything:            make dev-stack-down"
	@echo "================================================================="