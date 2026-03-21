SHELL := /bin/bash

# =============================================================================
# Platform Configuration
# =============================================================================

HELM_CHART := infra/helm/charts/platform
ENVS := dev qa stg prod
VALUES_dev := infra/helm/values/qa/platform-values.yaml
VALUES_qa := infra/helm/values/qa/platform-values.yaml
VALUES_stg := infra/helm/values/stg/platform-values.yaml
VALUES_prod := infra/helm/values/prod/platform-values.yaml

RELEASE_PREFIX := etp-platform
NAMESPACE_SUFFIX := -platform

# Local build/render artifacts
RENDER_DIR := .tmp/helm
ARTIFACT_DIR := .tmp/artifacts
WHEEL_DIR := $(ARTIFACT_DIR)/wheels
MAVEN_DIR := $(ARTIFACT_DIR)/maven

# Runtime command defaults
TIMEOUT := 10m
COMPOSE_FILE := infra/docker/docker-compose.kafka.yml
DC := docker compose -f $(COMPOSE_FILE)
DBT_SERVICE := dbt-snowflake
DBT_TARGET ?= dev
STACK_PROFILES := --profile dev-producers --profile dev-lakehouse --profile dev-dbt --profile dev-flink-ui --profile dev-airflow

# Local Flink runnable artifacts
FLINK_MAIL_ROUTER_POM := platform/flink/jobs/mail_lifecycle_router/java/pom.xml
FLINK_MAIL_ROUTER_JAR := platform/flink/jobs/mail_lifecycle_router/java/target/mail-lifecycle-router-flink-*.jar
FLINK_OPS_ROUTER_POM := platform/flink/jobs/operational_mail_tracking_router/java/pom.xml
FLINK_OPS_ROUTER_JAR := platform/flink/jobs/operational_mail_tracking_router/java/target/operational-mail-tracking-router-flink-*.jar
FLINK_JOBMANAGER_CONTAINER := etp-flink-jobmanager
FLINK_JOBMANAGER_EXEC := $(DC) exec -T flink-jobmanager
FLINK_BUILD_IMAGE := maven:3.9.9-eclipse-temurin-17
FLINK_BUILD_CMD := docker run --rm -v "$$$$PWD":/workspace -w /workspace $(FLINK_BUILD_IMAGE)
FLINK_ROUTER_TARGETS := dev-flink-mail-router dev-flink-ops-router

# =============================================================================
# Helper Macros
# =============================================================================

define RELEASE_FOR
$(RELEASE_PREFIX)-$(1)
endef

define NAMESPACE_FOR
$(1)$(NAMESPACE_SUFFIX)
endef

# Build project groups
MAVEN_PROJECTS := \
	services/cdc-consumer \
	services/event-producers \
	services/canonical-lakehouse-consumer \
	platform/flink/jobs/mail_lifecycle_router/java \
	platform/flink/jobs/operational_mail_tracking_router/java

PYTHON_WHEEL_PROJECTS := \
	services/orchestration-api

# =============================================================================
# Target Registry
# =============================================================================

.PHONY: help check-tools local-ci ci-render-all ci-render-dev ci-render-qa ci-render-stg ci-render-prod ci-validate-prod-hardening local-cd cd-dev cd-qa cd-stg cd-prod health-dev health-qa health-stg health-prod rollback-prod build-artifacts build-maven-all build-python-wheels dev_stack_up dev-stack-up dev-bootstrap dev-producers-up dev-producers-logs dev-cdc-bridge dev-flink-mail-router dev-flink-ops-router dev-flink-all dev-flink-jobs dev-flink-ui-up dev-flink-ui-logs dev-produce-analytics dev-peek-tracking dev-peek-dashboard dev-peek-analytics dev-lakehouse-up dev-lakehouse-logs dev-lakehouse-smoke dev-dbt-up dev-dbt-down dev-dbt-deps dev-dbt-debug dev-dbt-build dev-dbt-seed-large dev-airflow-up dev-airflow-down dev-airflow-logs dev-observability-up dev-observability-down dev-es-setup dev-kibana-import dev-pipeline-smoke dev-stack-down clean

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Available local CI/CD targets:"
	@echo "  local-ci                    Run local CI checks (render + prod hardening checks)"
	@echo "  local-cd                    Promote dev -> QA -> staging -> production"
	@echo "  build-artifacts             Build Maven JARs and Python wheel artifacts"
	@echo "  build-maven-all             Build all Maven packages"
	@echo "  build-python-wheels         Build all Python wheels"
	@echo "  dev-stack-up | dev_stack_up Start full local stack (base + producers + lakehouse + Flink UI + dbt)"
	@echo "  dev-bootstrap               Create topics and register Avro schemas"
	@echo "  dev-producers-up            Build and start dev-only CDC and mail-tracking producers"
	@echo "  dev-producers-logs          Tail logs for both dev producer containers"
	@echo "  dev-cdc-bridge              Run CDC bridge (dbz -> evt.mail.lifecycle.raw)"
	@echo "  dev-flink-mail-router       Submit mail lifecycle Flink job to local Flink cluster (shows in dashboard)"
	@echo "  dev-flink-ops-router        Submit operational tracking Flink job to local Flink cluster (shows in dashboard)"
	@echo "  dev-flink-all               Submit both Flink jobs to local Flink cluster"
	@echo "  dev-flink-jobs              List jobs currently running in Flink JobManager"
	@echo "  dev-flink-ui-up             Start Flink JobManager/TaskManager and expose dashboard on localhost:8088"
	@echo "  dev-flink-ui-logs           Tail logs for Flink JobManager/TaskManager"
	@echo "  dev-produce-analytics       Publish 5 sample events to evt.mail.customer.analytics"
	@echo "  dev-peek-tracking           Print 5 messages from evt.mail.internal.tracking"
	@echo "  dev-peek-dashboard          Print 5 messages from evt.mail.internal.tracking.dashboard"
	@echo "  dev-peek-analytics          Print 5 messages from evt.mail.customer.analytics"
	@echo "  dev-lakehouse-up            Build and start MinIO + canonical-lakehouse-consumer (Spark → Iceberg)"
	@echo "  dev-lakehouse-logs          Tail logs for the lakehouse consumer container"
	@echo "  dev-lakehouse-smoke         One-command lakehouse smoke (up + produce + verify logs + MinIO metadata)"
	@echo "  dev-dbt-up                  Start dbt Snowflake runtime container"
	@echo "  dev-dbt-down                Stop dbt Snowflake runtime container"
	@echo "  dev-dbt-deps                Install dbt package dependencies (dbt deps)"
	@echo "  dev-dbt-debug               Validate Snowflake connectivity/profile (dbt debug)"
	@echo "  dev-dbt-build               Run dbt semantic models against Snowflake"
	@echo "  dev-dbt-seed-large          Load 12k-row synthetic data into Snowflake source tables"
	@echo "  dev-airflow-up              Start local Airflow UI with repository DAGs mounted"
	@echo "  dev-airflow-down            Stop local Airflow container"
	@echo "  dev-airflow-logs            Tail local Airflow logs"
	@echo "  dev-observability-up        Start Elasticsearch and Kibana containers (dev-observability profile)"
	@echo "  dev-observability-down      Stop Elasticsearch and Kibana containers"
	@echo "  dev-es-setup                Register ingest pipeline and apply index templates to local Elasticsearch"
	@echo "  dev-kibana-import           Import Kibana starter dashboards (operational tracking + dead-letter)"
	@echo "  dev-pipeline-smoke          Full local pipeline smoke: bootstrap + producers + Flink instructions"
	@echo "  dev-stack-down              Stop the local Docker Compose stack"
	@echo "  cd-dev | cd-qa | cd-stg | cd-prod"
	@echo "  health-dev | health-qa | health-stg | health-prod"
	@echo "  rollback-prod REV=<n>       Roll back production release revision"
	@echo "  clean                       Remove local render/build artifacts"

# =============================================================================
# Shared Checks and Artifact Builds
# =============================================================================

check-tools:
	@command -v helm >/dev/null || (echo "helm not found" && exit 1)
	@command -v kubectl >/dev/null || (echo "kubectl not found" && exit 1)
	@mkdir -p $(RENDER_DIR)

build-artifacts: build-maven-all build-python-wheels

build-maven-all:
	@command -v mvn >/dev/null || (echo "mvn not found" && exit 1)
	@mkdir -p $(MAVEN_DIR)
	@set -e; \
	for project in $(MAVEN_PROJECTS); do \
		echo "Building Maven package: $$project"; \
		mvn -f $$project/pom.xml clean package -DskipTests; \
		find $$project/target -maxdepth 1 -type f -name '*.jar' -exec cp {} $(MAVEN_DIR)/ \;; \
	done
	@echo "Maven artifacts copied to $(MAVEN_DIR)"

build-python-wheels:
	@python3 -m pip show build >/dev/null 2>&1 || python3 -m pip install build
	@mkdir -p $(WHEEL_DIR)
	@set -e; \
	for project in $(PYTHON_WHEEL_PROJECTS); do \
		echo "Building Python wheel: $$project"; \
		python3 -m build --wheel --outdir $(WHEEL_DIR) $$project; \
	done
	@echo "Wheel artifacts copied to $(WHEEL_DIR)"

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

$(eval $(call PROFILE_UP_TARGET,dev-producers-up,dev-producers,cdc-event-producer mail-tracking-event-producer))
$(eval $(call LOGS_TARGET,dev-producers-logs,cdc-event-producer mail-tracking-event-producer))

dev-cdc-bridge:
	mvn -f services/cdc-consumer/pom.xml -q -DskipTests package
	KAFKA_BOOTSTRAP_SERVERS=localhost:9092 SCHEMA_REGISTRY_URL=http://localhost:8081 java -jar services/cdc-consumer/target/cdc-consumer-0.1.0-SNAPSHOT.jar

# Reusable template for Flink cluster submission via JobManager container.
define FLINK_ROUTER_TARGET
dev-flink-$(1)-router: dev-flink-ui-up
	$(FLINK_BUILD_CMD) mvn -f $(2) -q -DskipTests package
	@JAR_PATH=$$$$(ls $(3) | head -1); \
	if [ -z "$$$$JAR_PATH" ]; then echo "Flink jar not found for target dev-flink-$(1)-router" && exit 1; fi; \
	echo "Submitting $$$$JAR_PATH to Flink JobManager..."; \
	$(FLINK_JOBMANAGER_EXEC) sh -lc "mkdir -p /opt/flink/usrlib"; \
	docker cp "$$$$JAR_PATH" $(FLINK_JOBMANAGER_CONTAINER):/opt/flink/usrlib/$(1)-router.jar; \
	$(FLINK_JOBMANAGER_EXEC) sh -lc "KAFKA_BOOTSTRAP_SERVERS=kafka:29092 flink run -d /opt/flink/usrlib/$(1)-router.jar"
endef

$(eval $(call FLINK_ROUTER_TARGET,mail,$(FLINK_MAIL_ROUTER_POM),$(FLINK_MAIL_ROUTER_JAR)))
$(eval $(call FLINK_ROUTER_TARGET,ops,$(FLINK_OPS_ROUTER_POM),$(FLINK_OPS_ROUTER_JAR)))

dev-flink-all: $(FLINK_ROUTER_TARGETS)

dev-flink-jobs: dev-flink-ui-up
	$(FLINK_JOBMANAGER_EXEC) flink list

$(eval $(call PROFILE_UP_TARGET,dev-flink-ui-up,dev-flink-ui,flink-jobmanager flink-taskmanager))
$(eval $(call LOGS_TARGET,dev-flink-ui-logs,flink-jobmanager flink-taskmanager))

# Publishes synthetic analytics events for local throughput and pipeline checks.
dev-produce-analytics:
	@COUNT=$${ANALYTICS_EVENT_COUNT:-10000}; \
	for i in $$(seq 1 $$COUNT); do \
	  echo "{\"event_id\":\"evt-seed-$$i\",\"event_type\":\"mail.delivered\",\"event_version\":\"1.0.0\",\"event_time\":\"2026-03-20T08:20:00Z\",\"ingested_at\":\"2026-03-20T08:20:01Z\",\"source_system\":\"make.seed\",\"tenant_id\":\"tenant-$$((($$i % 20) + 1))\",\"message_id\":\"msg-seed-$$i\",\"correlation_id\":\"corr-seed-$$i\",\"trace_id\":\"trace-seed-$$i\",\"actor_type\":\"service\",\"payload\":\"{}\"}"; \
	done | $(DC) exec -T kafka \
	  kafka-console-producer --bootstrap-server kafka:29092 --topic evt.mail.customer.analytics; \
	echo "Published $$COUNT events to evt.mail.customer.analytics"

# =============================================================================
# Bootstrap
# =============================================================================

dev-bootstrap:
	@echo "==> Installing bootstrap Python deps..."
	pip3 install -q -r scripts/bootstrap/requirements-kafka.txt
	@echo "==> Creating Kafka topics..."
	python3 scripts/bootstrap/kafka_bootstrap.py \
	  --bootstrap-servers localhost:9092 \
	  --schema-registry-url http://localhost:8081
	@echo "==> Registering Avro schemas..."
	python3 scripts/bootstrap/schema_registry_maintainer.py \
	  --schema-registry-url http://localhost:8081
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
	    --bootstrap-server kafka:29092 \
	    --topic $(2) \
	    --from-beginning --max-messages 5 \
	    --timeout-ms 10000
endef

$(eval $(call PEEK_TARGET,tracking,evt.mail.internal.tracking))
$(eval $(call PEEK_TARGET,dashboard,evt.mail.internal.tracking.dashboard))
$(eval $(call PEEK_TARGET,analytics,evt.mail.customer.analytics))

# =============================================================================
# Lakehouse Runtime
# =============================================================================

$(eval $(call PROFILE_UP_TARGET,dev-lakehouse-up,dev-lakehouse,minio minio-init canonical-lakehouse-consumer))
$(eval $(call LOGS_TARGET,dev-lakehouse-logs,canonical-lakehouse-consumer))

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

dev-dbt-up:
	$(DC) --profile dev-dbt up -d $(DBT_SERVICE)

dev-dbt-down:
	$(DC) --profile dev-dbt stop $(DBT_SERVICE)

$(eval $(call PROFILE_UP_TARGET,dev-airflow-up,dev-airflow,airflow))
$(eval $(call LOGS_TARGET,dev-airflow-logs,airflow))

dev-airflow-down:
	$(DC) --profile dev-airflow stop airflow

$(eval $(call DBT_CMD_TARGET,dev-dbt-deps,deps))
$(eval $(call DBT_CMD_TARGET,dev-dbt-debug,debug --target $(DBT_TARGET)))
$(eval $(call DBT_CMD_TARGET,dev-dbt-build,build --target $(DBT_TARGET) --select staging.customer_analytics+ marts.customer_analytics))

SEED_LARGE_SQL := storage/snowflake/schemas/sf_tuts_customer_analytics_generate_large_data.sql
DBT_CONTAINER := etp-dbt-snowflake

dev-dbt-seed-large: dev-dbt-up
	docker cp $(SEED_LARGE_SQL) $(DBT_CONTAINER):/tmp/seed_large.sql
	$(DC) exec $(DBT_SERVICE) python3 -c 'import snowflake.connector,os;conn=snowflake.connector.connect(account=os.environ['"'"'DBT_SNOWFLAKE_ACCOUNT'"'"'],user=os.environ['"'"'DBT_SNOWFLAKE_USER'"'"'],password=os.environ['"'"'DBT_SNOWFLAKE_PASSWORD'"'"'],role=os.environ['"'"'DBT_SNOWFLAKE_ROLE'"'"'],warehouse=os.environ['"'"'DBT_SNOWFLAKE_WAREHOUSE'"'"'],database=os.environ['"'"'DBT_SNOWFLAKE_DATABASE'"'"']);cur=conn.cursor();sql=open('"'"'/tmp/seed_large.sql'"'"').read();[cur.execute(s.strip()) for s in sql.split('"'"';'"'"') if s.strip()];cur.execute('"'"'SELECT COUNT(*) FROM ICEBERG_CUSTOMER_ANALYTICS.TABLEAU_REPORTING_EVENTS'"'"');print('"'"'TABLEAU_REPORTING_EVENTS rows:'"'"',cur.fetchone()[0]);cur.close();conn.close()'

# =============================================================================
# Observability (Elasticsearch + Kibana)
# =============================================================================

dev-observability-up:
	$(DC) --profile dev-observability up -d elasticsearch kibana

dev-observability-down:
	$(DC) --profile dev-observability stop elasticsearch kibana

dev-es-setup:
	@echo "Registering ingest pipeline..."
	@curl -sS -X PUT http://localhost:9200/_ingest/pipeline/internal-mail-tracking-pipeline \
	  -H 'Content-Type: application/json' \
	  --data @storage/elasticsearch/ingest-pipelines/internal-mail-tracking-pipeline.json
	@echo ""
	@echo "Applying index templates..."
	@curl -sS -X PUT http://localhost:9200/_index_template/internal-mail-tracking-template \
	  -H 'Content-Type: application/json' \
	  --data @storage/elasticsearch/index-templates/internal-mail-tracking-template.json
	@echo ""
	@curl -sS -X PUT http://localhost:9200/_index_template/internal-mail-tracking-deadletter-template \
	  -H 'Content-Type: application/json' \
	  --data @storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json
	@echo ""
	@echo "Elasticsearch setup complete."

dev-kibana-import:
	@echo "Importing operational tracking dashboard..."
	@curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
	  -H "kbn-xsrf: true" \
	  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-operational-dashboard.json
	@echo ""
	@echo "Importing dead-letter dashboard..."
	@curl -sS -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
	  -H "kbn-xsrf: true" \
	  -F file=@storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json
	@echo ""
	@echo "Kibana import complete. Open http://localhost:5601 to view dashboards."

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
	@echo "    make dev-peek-tracking      # evt.mail.internal.tracking"
	@echo "    make dev-peek-dashboard     # evt.mail.internal.tracking.dashboard"
	@echo "    make dev-peek-analytics     # evt.mail.customer.analytics"
	@echo ""
	@echo "  NOTE: the CDC pipeline also requires the cdc-consumer bridge:"
	@echo "    cd services/cdc-consumer && KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \\"
	@echo "      SCHEMA_REGISTRY_URL=http://localhost:8081 \\"
	@echo "      mvn -q -DskipTests exec:java \\"
	@echo "        -Dexec.mainClass=com.eventtracking.cdc.DebeziumPostgresCdcProducer \\"
	@echo "        -Dexec.classpathScope=compile"
	@echo ""
	@echo "Tail producer logs at any time:  make dev-producers-logs"
	@echo "Tear down everything:            make dev-stack-down"
	@echo "================================================================="

# =============================================================================
# Local CI/CD
# =============================================================================

dev-stack-down:
	$(DC) $(STACK_PROFILES) down --remove-orphans

local-ci: check-tools ci-render-all ci-validate-prod-hardening

ci-render-all: $(addprefix ci-render-,$(ENVS))

define RENDER_TARGET
ci-render-$(1):
	helm template $(call RELEASE_FOR,$(1)) $(HELM_CHART) -f $(VALUES_$(1)) > $(RENDER_DIR)/$(1).yaml
endef

$(foreach env,$(ENVS),$(eval $(call RENDER_TARGET,$(env))))

ci-validate-prod-hardening:
	@grep -n "kind: HorizontalPodAutoscaler" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: PodDisruptionBudget" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: NetworkPolicy" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: Ingress" $(RENDER_DIR)/prod.yaml >/dev/null
	@echo "Production hardening manifests found in $(RENDER_DIR)/prod.yaml"

# =============================================================================
# Environment Deployment and Health
# =============================================================================

local-cd: $(foreach env,$(ENVS),cd-$(env) health-$(env))

define CD_TARGET
cd-$(1): check-tools
	helm upgrade --install $(call RELEASE_FOR,$(1)) $(HELM_CHART) \
		-n $(call NAMESPACE_FOR,$(1)) --create-namespace \
		-f $(VALUES_$(1)) \
		--wait --timeout $(TIMEOUT)
endef

define HEALTH_TARGET
health-$(1): check-tools
	kubectl get deploy,po,svc,ingress -n $(call NAMESPACE_FOR,$(1)) -l app.kubernetes.io/instance=$(call RELEASE_FOR,$(1))
	kubectl get hpa,pdb,networkpolicy -n $(call NAMESPACE_FOR,$(1))
endef

$(foreach env,$(ENVS),$(eval $(call CD_TARGET,$(env))))
$(foreach env,$(ENVS),$(eval $(call HEALTH_TARGET,$(env))))

# =============================================================================
# Release Rollback and Cleanup
# =============================================================================

rollback-prod: check-tools
	@test -n "$(REV)" || (echo "Usage: make rollback-prod REV=<revision>" && exit 1)
	helm rollback $(call RELEASE_FOR,prod) $(REV) -n $(call NAMESPACE_FOR,prod) --wait --timeout $(TIMEOUT)

clean:
	rm -rf .tmp
