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
STACK_PROFILES := --profile dev-producers --profile dev-lakehouse --profile dev-dbt --profile dev-flink-ui --profile dev-airflow

# Local Kafka/runtime endpoints and topic names
LOCAL_KAFKA_BOOTSTRAP := localhost:9092
DOCKER_KAFKA_BOOTSTRAP := kafka:29092
LOCAL_SCHEMA_REGISTRY_URL := http://localhost:8081
TRACKING_TOPIC := evt.mail.internal.tracking
DASHBOARD_TOPIC := evt.mail.internal.tracking.dashboard
ANALYTICS_TOPIC := evt.mail.customer.analytics

# Producer/bootstrap assets
BOOTSTRAP_REQUIREMENTS := scripts/bootstrap/requirements-kafka.txt
BOOTSTRAP_KAFKA_SCRIPT := scripts/bootstrap/kafka_bootstrap.py
BOOTSTRAP_SCHEMA_SCRIPT := scripts/bootstrap/schema_registry_maintainer.py
DEV_PRODUCER_SERVICES := cdc-event-producer mail-tracking-event-producer
CDC_BRIDGE_POM := services/cdc-consumer/pom.xml
CDC_BRIDGE_JAR := services/cdc-consumer/target/cdc-consumer-0.1.0-SNAPSHOT.jar

# Local observability endpoints and assets
ELASTICSEARCH_URL := http://localhost:9200
KIBANA_URL := http://localhost:5601
KAFKA_CONNECT_URL := http://localhost:8083
OBS_MAIN_INDEX := internal-mail-tracking
OBS_DLQ_INDEX := internal-mail-tracking-deadletter
OBS_MAIN_CONNECTOR := internal-mail-tracking-elasticsearch-sink
OBS_DLQ_CONNECTOR := internal-mail-tracking-deadletter-elasticsearch-sink
OBS_MAIN_CONNECTOR_CONFIG := platform/kafka/connect/elasticsearch/internal-mail-tracking-sink.json
OBS_DLQ_CONNECTOR_CONFIG := platform/kafka/connect/elasticsearch/internal-mail-tracking-deadletter-sink.json
OBS_INGEST_PIPELINE := storage/elasticsearch/ingest-pipelines/internal-mail-tracking-pipeline.json
OBS_MAIN_TEMPLATE := storage/elasticsearch/index-templates/internal-mail-tracking-template.json
OBS_DLQ_TEMPLATE := storage/elasticsearch/index-templates/internal-mail-tracking-deadletter-template.json
OBS_MAIN_DASHBOARD := storage/elasticsearch/kibana/internal-mail-tracking-operational-dashboard.json
OBS_DLQ_DASHBOARD := storage/elasticsearch/kibana/internal-mail-tracking-deadletter-dashboard.json
KIBANA_SO_CONVERTER := scripts/dev/kibana_saved_objects_json_to_ndjson.py

# Local Flink runnable artifacts and runtime wiring
FLINK_MAIL_ROUTER_POM := platform/flink/jobs/mail_lifecycle_router/java/pom.xml
FLINK_MAIL_ROUTER_JAR := platform/flink/jobs/mail_lifecycle_router/java/target/mail-lifecycle-router-flink-*.jar
FLINK_OPS_ROUTER_POM := platform/flink/jobs/operational_mail_tracking_router/java/pom.xml
FLINK_OPS_ROUTER_JAR := platform/flink/jobs/operational_mail_tracking_router/java/target/operational-mail-tracking-router-flink-*.jar
FLINK_JOBMANAGER_CONTAINER := etp-flink-jobmanager
FLINK_JOBMANAGER_EXEC := $(DC) exec -T flink-jobmanager
FLINK_BUILD_IMAGE := maven:3.9.9-eclipse-temurin-17
FLINK_BUILD_CMD := docker run --rm -v "$$$$PWD":/workspace -w /workspace $(FLINK_BUILD_IMAGE)
FLINK_ROUTER_TARGETS := dev-flink-mail-router dev-flink-ops-router
FLINK_KAFKA_BOOTSTRAP := $(DOCKER_KAFKA_BOOTSTRAP)
FLINK_UI_SERVICES := flink-jobmanager flink-taskmanager

# dbt runtime configuration and assets
DBT_SERVICE := dbt-snowflake
DBT_TARGET ?= dev
DBT_CONTAINER := etp-dbt-snowflake
DBT_BUILD_SELECT := staging.customer_analytics+ marts.customer_analytics
SEED_LARGE_SQL := storage/snowflake/schemas/sf_tuts_customer_analytics_generate_large_data.sql

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
# Included Target Files
# =============================================================================

include make/local-runtime.mk
include make/observability.mk

# =============================================================================
# Target Registry
# =============================================================================

.PHONY: help check-tools local-ci ci-render-all ci-render-dev ci-render-qa ci-render-stg ci-render-prod ci-validate-prod-hardening local-cd cd-dev cd-qa cd-stg cd-prod health-dev health-qa health-stg health-prod rollback-prod build-artifacts build-maven-all build-python-wheels dev_stack_up dev-stack-up dev-bootstrap dev-producers-up dev-producers-logs dev-cdc-bridge dev-flink-mail-router dev-flink-ops-router dev-flink-all dev-flink-jobs dev-flink-ui-up dev-flink-ui-logs dev-produce-analytics dev-peek-tracking dev-peek-dashboard dev-peek-analytics dev-lakehouse-up dev-lakehouse-logs dev-lakehouse-smoke dev-dbt-up dev-dbt-down dev-dbt-deps dev-dbt-debug dev-dbt-build dev-dbt-seed-large dev-airflow-up dev-airflow-down dev-airflow-logs dev-observability-up dev-observability-down dev-observability-setup dev-es-setup dev-connect-setup dev-connect-status dev-connect-logs dev-connect-health dev-connect-dlq-smoke dev-kibana-import dev-pipeline-smoke dev-stack-down clean

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Available local CI/CD targets:"
	@echo ""
	@echo "Core build and CI:"
	@echo "  local-ci                    Run local CI checks (render + prod hardening checks)"
	@echo "  local-cd                    Promote dev -> QA -> staging -> production"
	@echo "  build-artifacts             Build Maven JARs and Python wheel artifacts"
	@echo "  build-maven-all             Build all Maven packages"
	@echo "  build-python-wheels         Build all Python wheels"
	@echo ""
	@echo "Local stack and producers:"
	@echo "  dev-stack-up | dev_stack_up Start full local stack (base + producers + lakehouse + Flink UI + dbt)"
	@echo "  dev-bootstrap               Create topics and register Avro schemas"
	@echo "  dev-producers-up            Build and start dev-only CDC and mail-tracking producers"
	@echo "  dev-producers-logs          Tail logs for both dev producer containers"
	@echo "  dev-cdc-bridge              Run CDC bridge (dbz -> evt.mail.lifecycle.raw)"
	@echo ""
	@echo "Flink and topic inspection:"
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
	@echo ""
	@echo "Lakehouse, dbt, and Airflow:"
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
	@echo ""
	@echo "Observability:"
	@echo "  dev-observability-up        Start Elasticsearch and Kibana containers (dev-observability profile)"
	@echo "  dev-observability-down      Stop Elasticsearch and Kibana containers"
	@echo "  dev-observability-setup     Start observability services, register Elasticsearch assets/connectors, and import Kibana dashboards"
	@echo "  dev-es-setup                Register ingest pipeline and apply index templates to local Elasticsearch"
	@echo "  dev-connect-setup           Create observability indices and register Elasticsearch sink connectors"
	@echo "  dev-connect-status          Show Kafka Connect connector/task status for Elasticsearch sinks"
	@echo "  dev-connect-logs            Tail Kafka Connect logs"
	@echo "  dev-connect-health          Show connector status plus Elasticsearch document counts"
	@echo "  dev-connect-dlq-smoke       Publish a malformed dashboard record and verify it lands in the DLQ index"
	@echo "  dev-kibana-import           Import Kibana starter dashboards (operational tracking + dead-letter)"
	@echo ""
	@echo "Pipeline and release:"
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
