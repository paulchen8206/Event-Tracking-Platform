SHELL := /bin/bash

HELM_CHART := infra/helm/charts/platform
VALUES_DEV := infra/helm/values/qa/platform-values.yaml
VALUES_QA := infra/helm/values/qa/platform-values.yaml
VALUES_STG := infra/helm/values/stg/platform-values.yaml
VALUES_PROD := infra/helm/values/prod/platform-values.yaml

RELEASE_DEV := etp-platform-dev
RELEASE_QA := etp-platform-qa
RELEASE_STG := etp-platform-stg
RELEASE_PROD := etp-platform-prod

NAMESPACE_DEV := dev-platform
NAMESPACE_QA := qa-platform
NAMESPACE_STG := stg-platform
NAMESPACE_PROD := prod-platform

RENDER_DIR := .tmp/helm
ARTIFACT_DIR := .tmp/artifacts
WHEEL_DIR := $(ARTIFACT_DIR)/wheels
MAVEN_DIR := $(ARTIFACT_DIR)/maven
TIMEOUT := 10m
COMPOSE_FILE := infra/docker/docker-compose.kafka.yml

MAVEN_PROJECTS := \
	services/cdc-consumer \
	services/event-producers \
	services/canonical-lakehouse-consumer \
	platform/flink/jobs/mail_lifecycle_router/java \
	platform/flink/jobs/operational_mail_tracking_router/java

PYTHON_WHEEL_PROJECTS := \
	services/orchestration-api

.PHONY: help check-tools local-ci ci-render-all ci-render-dev ci-render-qa ci-render-stg ci-render-prod ci-validate-prod-hardening local-cd cd-dev cd-qa cd-stg cd-prod health-dev health-qa health-stg health-prod rollback-prod build-artifacts build-maven-all build-python-wheels dev-stack-up dev-bootstrap dev-producers-up dev-producers-logs dev-flink-mail-router dev-flink-ops-router dev-flink-ui-up dev-flink-ui-logs dev-produce-analytics dev-peek-tracking dev-peek-dashboard dev-peek-analytics dev-lakehouse-up dev-lakehouse-logs dev-lakehouse-smoke dev-pipeline-smoke dev-stack-down clean

help:
	@echo "Available local CI/CD targets:"
	@echo "  local-ci                    Run local CI checks (render + prod hardening checks)"
	@echo "  local-cd                    Promote dev -> QA -> staging -> production"
	@echo "  build-artifacts             Build Maven JARs and Python wheel artifacts"
	@echo "  build-maven-all             Build all Maven packages"
	@echo "  build-python-wheels         Build all Python wheels"
	@echo "  dev-stack-up                Start local Kafka/Schema Registry/Kafka UI/Connect"
	@echo "  dev-bootstrap               Create topics and register Avro schemas"
	@echo "  dev-producers-up            Build and start dev-only CDC and mail-tracking producers"
	@echo "  dev-producers-logs          Tail logs for both dev producer containers"
	@echo "  dev-flink-mail-router       Run the mail lifecycle Flink job locally against localhost Kafka"
	@echo "  dev-flink-ops-router        Run the operational mail tracking Flink job locally against localhost Kafka"
	@echo "  dev-flink-ui-up             Start Flink JobManager/TaskManager and expose dashboard on localhost:8088"
	@echo "  dev-flink-ui-logs           Tail logs for Flink JobManager/TaskManager"
	@echo "  dev-produce-analytics       Publish 5 sample events to evt.mail.customer.analytics"
	@echo "  dev-peek-tracking           Print 5 messages from evt.mail.internal.tracking"
	@echo "  dev-peek-dashboard          Print 5 messages from evt.mail.internal.tracking.dashboard"
	@echo "  dev-peek-analytics          Print 5 messages from evt.mail.customer.analytics"
	@echo "  dev-lakehouse-up            Build and start MinIO + canonical-lakehouse-consumer (Spark → Iceberg)"
	@echo "  dev-lakehouse-logs          Tail logs for the lakehouse consumer container"
	@echo "  dev-lakehouse-smoke         One-command lakehouse smoke (up + produce + verify logs + MinIO metadata)"
	@echo "  dev-pipeline-smoke          Full local pipeline smoke: bootstrap + producers + Flink instructions"
	@echo "  dev-stack-down              Stop the local Docker Compose stack"
	@echo "  cd-dev | cd-qa | cd-stg | cd-prod"
	@echo "  health-dev | health-qa | health-stg | health-prod"
	@echo "  rollback-prod REV=<n>       Roll back production release revision"
	@echo "  clean                       Remove local render/build artifacts"

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

dev-stack-up:
	docker compose -f $(COMPOSE_FILE) up -d

dev-producers-up:
	docker compose -f $(COMPOSE_FILE) --profile dev-producers up -d --build cdc-event-producer mail-tracking-event-producer

dev-producers-logs:
	docker compose -f $(COMPOSE_FILE) logs -f cdc-event-producer mail-tracking-event-producer

dev-flink-mail-router:
	mvn -f platform/flink/jobs/mail_lifecycle_router/java/pom.xml -q -DskipTests -Plocal-run package
	KAFKA_BOOTSTRAP_SERVERS=localhost:9092 java -jar platform/flink/jobs/mail_lifecycle_router/java/target/mail-lifecycle-router-flink-*.jar

dev-flink-ops-router:
	mvn -f platform/flink/jobs/operational_mail_tracking_router/java/pom.xml -q -DskipTests -Plocal-run package
	KAFKA_BOOTSTRAP_SERVERS=localhost:9092 java -jar platform/flink/jobs/operational_mail_tracking_router/java/target/operational-mail-tracking-router-flink-*.jar

dev-flink-ui-up:
	docker compose -f $(COMPOSE_FILE) --profile dev-flink-ui up -d flink-jobmanager flink-taskmanager

dev-flink-ui-logs:
	docker compose -f $(COMPOSE_FILE) logs -f flink-jobmanager flink-taskmanager

dev-produce-analytics:
	@COUNT=$${ANALYTICS_EVENT_COUNT:-10000}; \
	for i in $$(seq 1 $$COUNT); do \
	  echo "{\"event_id\":\"evt-seed-$$i\",\"event_type\":\"mail.delivered\",\"event_version\":\"1.0.0\",\"event_time\":\"2026-03-20T08:20:00Z\",\"ingested_at\":\"2026-03-20T08:20:01Z\",\"source_system\":\"make.seed\",\"tenant_id\":\"tenant-$$((($$i % 20) + 1))\",\"message_id\":\"msg-seed-$$i\",\"correlation_id\":\"corr-seed-$$i\",\"trace_id\":\"trace-seed-$$i\",\"actor_type\":\"service\",\"payload\":\"{}\"}"; \
	done | docker compose -f $(COMPOSE_FILE) exec -T kafka \
	  kafka-console-producer --bootstrap-server kafka:29092 --topic evt.mail.customer.analytics; \
	echo "Published $$COUNT events to evt.mail.customer.analytics"

# ── Bootstrap ────────────────────────────────────────────────────────────────

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

# ── Consume / peek output topics ─────────────────────────────────────────────
# Each target prints up to 5 messages from the named topic and exits.
# Requires the Compose stack to be running (make dev-stack-up).

dev-peek-tracking:
	docker compose -f $(COMPOSE_FILE) exec kafka \
	  kafka-console-consumer \
	    --bootstrap-server kafka:29092 \
	    --topic evt.mail.internal.tracking \
	    --from-beginning --max-messages 5 \
	    --timeout-ms 10000

dev-peek-dashboard:
	docker compose -f $(COMPOSE_FILE) exec kafka \
	  kafka-console-consumer \
	    --bootstrap-server kafka:29092 \
	    --topic evt.mail.internal.tracking.dashboard \
	    --from-beginning --max-messages 5 \
	    --timeout-ms 10000

dev-peek-analytics:
	docker compose -f $(COMPOSE_FILE) exec kafka \
	  kafka-console-consumer \
	    --bootstrap-server kafka:29092 \
	    --topic evt.mail.customer.analytics \
	    --from-beginning --max-messages 5 \
	    --timeout-ms 10000

# ── Canonical lakehouse consumer (Spark Structured Streaming → Iceberg/MinIO) ─

dev-lakehouse-up:
	docker compose -f $(COMPOSE_FILE) --profile dev-lakehouse up -d --build \
	  minio minio-init canonical-lakehouse-consumer

dev-lakehouse-logs:
	docker compose -f $(COMPOSE_FILE) logs -f canonical-lakehouse-consumer

dev-lakehouse-smoke: dev-lakehouse-up dev-produce-analytics
	@echo "==> Waiting for lakehouse consumer to process a batch..."
	@sleep 10
	@docker compose -f $(COMPOSE_FILE) logs --tail=200 canonical-lakehouse-consumer 2>&1 \
	  | egrep -i "Processed micro-batch|Started customer analytics consumer" \
	  | tail -5
	@echo "==> Checking Iceberg metadata in MinIO..."
	@docker compose -f $(COMPOSE_FILE) exec minio sh -lc \
	  "ls -1 /data/event-tracking-lakehouse/warehouse/customer_analytics/tableau_reporting_events/metadata | tail -5"
	@echo "==> Lakehouse smoke check passed."

# ── End-to-end pipeline smoke ─────────────────────────────────────────────────
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

dev-stack-down:
	docker compose -f $(COMPOSE_FILE) --profile dev-producers --profile dev-lakehouse down

local-ci: check-tools ci-render-all ci-validate-prod-hardening

ci-render-all: ci-render-dev ci-render-qa ci-render-stg ci-render-prod

ci-render-dev:
	helm template $(RELEASE_DEV) $(HELM_CHART) -f $(VALUES_DEV) > $(RENDER_DIR)/dev.yaml

ci-render-qa:
	helm template $(RELEASE_QA) $(HELM_CHART) -f $(VALUES_QA) > $(RENDER_DIR)/qa.yaml

ci-render-stg:
	helm template $(RELEASE_STG) $(HELM_CHART) -f $(VALUES_STG) > $(RENDER_DIR)/stg.yaml

ci-render-prod:
	helm template $(RELEASE_PROD) $(HELM_CHART) -f $(VALUES_PROD) > $(RENDER_DIR)/prod.yaml

ci-validate-prod-hardening:
	@grep -n "kind: HorizontalPodAutoscaler" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: PodDisruptionBudget" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: NetworkPolicy" $(RENDER_DIR)/prod.yaml >/dev/null
	@grep -n "kind: Ingress" $(RENDER_DIR)/prod.yaml >/dev/null
	@echo "Production hardening manifests found in $(RENDER_DIR)/prod.yaml"

local-cd: cd-dev health-dev cd-qa health-qa cd-stg health-stg cd-prod health-prod

cd-dev: check-tools
	helm upgrade --install $(RELEASE_DEV) $(HELM_CHART) \
		-n $(NAMESPACE_DEV) --create-namespace \
		-f $(VALUES_DEV) \
		--wait --timeout $(TIMEOUT)

cd-qa: check-tools
	helm upgrade --install $(RELEASE_QA) $(HELM_CHART) \
		-n $(NAMESPACE_QA) --create-namespace \
		-f $(VALUES_QA) \
		--wait --timeout $(TIMEOUT)

cd-stg: check-tools
	helm upgrade --install $(RELEASE_STG) $(HELM_CHART) \
		-n $(NAMESPACE_STG) --create-namespace \
		-f $(VALUES_STG) \
		--wait --timeout $(TIMEOUT)

cd-prod: check-tools
	helm upgrade --install $(RELEASE_PROD) $(HELM_CHART) \
		-n $(NAMESPACE_PROD) --create-namespace \
		-f $(VALUES_PROD) \
		--wait --timeout $(TIMEOUT)

health-dev: check-tools
	kubectl get deploy,po,svc,ingress -n $(NAMESPACE_DEV) -l app.kubernetes.io/instance=$(RELEASE_DEV)
	kubectl get hpa,pdb,networkpolicy -n $(NAMESPACE_DEV)

health-qa: check-tools
	kubectl get deploy,po,svc,ingress -n $(NAMESPACE_QA) -l app.kubernetes.io/instance=$(RELEASE_QA)
	kubectl get hpa,pdb,networkpolicy -n $(NAMESPACE_QA)

health-stg: check-tools
	kubectl get deploy,po,svc,ingress -n $(NAMESPACE_STG) -l app.kubernetes.io/instance=$(RELEASE_STG)
	kubectl get hpa,pdb,networkpolicy -n $(NAMESPACE_STG)

health-prod: check-tools
	kubectl get deploy,po,svc,ingress -n $(NAMESPACE_PROD) -l app.kubernetes.io/instance=$(RELEASE_PROD)
	kubectl get hpa,pdb,networkpolicy -n $(NAMESPACE_PROD)

rollback-prod: check-tools
	@test -n "$(REV)" || (echo "Usage: make rollback-prod REV=<revision>" && exit 1)
	helm rollback $(RELEASE_PROD) $(REV) -n $(NAMESPACE_PROD) --wait --timeout $(TIMEOUT)

clean:
	rm -rf .tmp
