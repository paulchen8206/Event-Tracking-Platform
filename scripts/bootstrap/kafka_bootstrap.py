from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
from typing import Any

import yaml
from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka.schema_registry import Schema, SchemaRegistryClient


DEFAULT_BOOTSTRAP_SERVERS = "localhost:9092"
DEFAULT_SCHEMA_REGISTRY_URL = "http://localhost:8081"
DEFAULT_TOPIC_MAP = Path("platform/kafka/topics/topic-map.yaml")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create Kafka topics and register Avro schemas from repository-managed config."
    )
    parser.add_argument(
        "--bootstrap-servers",
        default=DEFAULT_BOOTSTRAP_SERVERS,
        help=f"Kafka bootstrap servers. Default: {DEFAULT_BOOTSTRAP_SERVERS}",
    )
    parser.add_argument(
        "--schema-registry-url",
        default=DEFAULT_SCHEMA_REGISTRY_URL,
        help=f"Schema Registry URL. Default: {DEFAULT_SCHEMA_REGISTRY_URL}",
    )
    parser.add_argument(
        "--topic-map",
        type=Path,
        default=DEFAULT_TOPIC_MAP,
        help=f"Path to the topic map YAML. Default: {DEFAULT_TOPIC_MAP}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the actions that would be taken without calling Kafka or Schema Registry.",
    )
    return parser.parse_args()


def load_topic_map(path: Path) -> list[dict[str, Any]]:
    document = yaml.safe_load(path.read_text()) or {}
    topics = document.get("topics", [])
    if not isinstance(topics, list):
        raise ValueError("Expected 'topics' to be a list in the topic map.")
    return topics


def retention_to_ms(value: str) -> str:
    match = re.fullmatch(r"(\d+)([smhd])", value.strip())
    if not match:
        raise ValueError(f"Unsupported retention format: {value}")

    amount = int(match.group(1))
    unit = match.group(2)
    multipliers = {
        "s": 1000,
        "m": 60 * 1000,
        "h": 60 * 60 * 1000,
        "d": 24 * 60 * 60 * 1000,
    }
    return str(amount * multipliers[unit])


def build_topic(topic_config: dict[str, Any]) -> NewTopic:
    config = {
        "retention.ms": retention_to_ms(topic_config["retention"]),
        "cleanup.policy": topic_config.get("cleanup_policy", "delete"),
    }
    return NewTopic(
        topic=topic_config["name"],
        num_partitions=int(topic_config["partitions"]),
        replication_factor=int(topic_config.get("replication_factor", 1)),
        config=config,
    )


def create_topics(admin: AdminClient, topics: list[dict[str, Any]]) -> None:
    metadata = admin.list_topics(timeout=10)
    existing_names = set(metadata.topics.keys())

    new_topics = []
    for topic_config in topics:
        if topic_config["name"] in existing_names:
            print(f"Topic already exists: {topic_config['name']}")
            continue
        new_topics.append(build_topic(topic_config))

    if not new_topics:
        print("No topics to create.")
        return

    futures = admin.create_topics(new_topics)
    for topic_name, future in futures.items():
        try:
            future.result()
            print(f"Created topic: {topic_name}")
        except Exception as exc:  # pragma: no cover - dependent on broker state
            raise RuntimeError(f"Failed to create topic {topic_name}: {exc}") from exc


def register_schemas(
    schema_registry: SchemaRegistryClient,
    topics: list[dict[str, Any]],
    repository_root: Path,
) -> None:
    for topic_config in topics:
        serialization = topic_config.get("serialization") or {}
        if serialization.get("value_format", "").lower() != "avro":
            continue

        subject = serialization.get("schema_subject")
        schema_path = serialization.get("schema_file")
        schema_type = serialization.get("schema_type", "AVRO")
        if not subject or not schema_path:
            raise ValueError(
                f"Topic {topic_config['name']} is missing schema_subject or schema_file metadata."
            )

        schema_text = (repository_root / schema_path).read_text()
        schema_id = schema_registry.register_schema(
            subject_name=subject,
            schema=Schema(schema_str=schema_text, schema_type=schema_type),
        )
        print(f"Registered schema: {subject} -> id {schema_id}")


def print_plan(topics: list[dict[str, Any]]) -> None:
    for topic_config in topics:
        print(
            f"Plan topic {topic_config['name']}: partitions={topic_config['partitions']} "
            f"replication_factor={topic_config.get('replication_factor', 1)} "
            f"retention={topic_config['retention']}"
        )
        serialization = topic_config.get("serialization") or {}
        if serialization.get("value_format", "").lower() == "avro":
            print(
                f"  register {serialization['schema_subject']} from {serialization['schema_file']}"
            )


def main() -> int:
    args = parse_args()
    repository_root = Path(__file__).resolve().parents[2]
    topic_map_path = args.topic_map
    if not topic_map_path.is_absolute():
        topic_map_path = repository_root / topic_map_path

    topics = load_topic_map(topic_map_path)
    if args.dry_run:
        print_plan(topics)
        return 0

    admin = AdminClient({"bootstrap.servers": args.bootstrap_servers})
    schema_registry = SchemaRegistryClient({"url": args.schema_registry_url})

    create_topics(admin, topics)
    register_schemas(schema_registry, topics, repository_root)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"Bootstrap failed: {exc}", file=sys.stderr)
        raise SystemExit(1)