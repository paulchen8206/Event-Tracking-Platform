from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
from typing import Any

import requests
import yaml
from confluent_kafka.schema_registry import Schema, SchemaRegistryClient


DEFAULT_SCHEMA_REGISTRY_URL = "http://localhost:8081"
DEFAULT_SUBJECT_MAP = Path("platform/kafka/schemas/canonical-subjects.yaml")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Maintain canonical schema subjects in Schema Registry from repository-managed contracts."
    )
    parser.add_argument(
        "--schema-registry-url",
        default=DEFAULT_SCHEMA_REGISTRY_URL,
        help=f"Schema Registry URL. Default: {DEFAULT_SCHEMA_REGISTRY_URL}",
    )
    parser.add_argument(
        "--subject-map",
        type=Path,
        default=DEFAULT_SUBJECT_MAP,
        help=f"Path to canonical subject map YAML. Default: {DEFAULT_SUBJECT_MAP}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show planned compatibility and registration operations without making changes.",
    )
    return parser.parse_args()


def load_subject_map(path: Path) -> list[dict[str, Any]]:
    document = yaml.safe_load(path.read_text()) or {}
    subjects = document.get("subjects", [])
    if not isinstance(subjects, list):
        raise ValueError("Expected 'subjects' to be a list in canonical subject map.")
    return subjects


def _inline_refs(schema_obj: Any, schema_dir: Path, _depth: int = 0) -> Any:
    """Recursively replace local ``{"$ref": "./some.schema.json"}`` with the
    referenced schema's inline content.  Only relative file references (those
    starting with ``./`` or ``../``) are resolved; URI ``$ref`` values are left
    alone.  Recursion is capped at 10 levels to guard against circular files.
    """
    if _depth > 10:
        return schema_obj

    if isinstance(schema_obj, dict):
        ref = schema_obj.get("$ref")
        if ref and isinstance(ref, str) and re.match(r"^\.\.?/", ref):
            ref_path = (schema_dir / ref).resolve()
            ref_schema = json.loads(ref_path.read_text())
            # Inline the referenced schema instead of the $ref object, then
            # recurse in case the referenced schema itself has $refs.
            return _inline_refs(ref_schema, ref_path.parent, _depth + 1)
        return {k: _inline_refs(v, schema_dir, _depth + 1) for k, v in schema_obj.items()}

    if isinstance(schema_obj, list):
        return [_inline_refs(item, schema_dir, _depth + 1) for item in schema_obj]

    return schema_obj


def set_subject_compatibility(base_url: str, subject: str, compatibility: str) -> None:
    response = requests.put(
        f"{base_url}/config/{subject}",
        headers={"Content-Type": "application/vnd.schemaregistry.v1+json"},
        json={"compatibility": compatibility},
        timeout=10,
    )
    response.raise_for_status()


def register_subjects(
    schema_registry: SchemaRegistryClient,
    schema_registry_url: str,
    subject_configs: list[dict[str, Any]],
    repository_root: Path,
) -> None:
    for item in subject_configs:
        subject = item.get("subject")
        schema_file = item.get("schema_file")
        schema_type = item.get("schema_type", "JSON")
        compatibility = item.get("compatibility", "BACKWARD")
        if not subject or not schema_file:
            raise ValueError("Each subject entry requires subject and schema_file fields.")

        set_subject_compatibility(schema_registry_url, subject, compatibility)

        schema_path = (repository_root / schema_file).resolve()
        schema_obj = json.loads(schema_path.read_text())
        schema_obj = _inline_refs(schema_obj, schema_path.parent)
        schema_text = json.dumps(schema_obj)
        schema = Schema(schema_str=schema_text, schema_type=schema_type)
        schema_id = schema_registry.register_schema(subject_name=subject, schema=schema)
        print(f"Canonical schema synced: {subject} -> id {schema_id} ({compatibility})")


def print_plan(subject_configs: list[dict[str, Any]]) -> None:
    for item in subject_configs:
        print(
            "Plan subject "
            f"{item['subject']}: schema_type={item.get('schema_type', 'JSON')} "
            f"compatibility={item.get('compatibility', 'BACKWARD')} "
            f"schema_file={item['schema_file']}"
        )


def main() -> int:
    args = parse_args()
    repository_root = Path(__file__).resolve().parents[2]
    subject_map = args.subject_map
    if not subject_map.is_absolute():
        subject_map = repository_root / subject_map

    subject_configs = load_subject_map(subject_map)
    if args.dry_run:
        print_plan(subject_configs)
        return 0

    schema_registry = SchemaRegistryClient({"url": args.schema_registry_url})
    register_subjects(
        schema_registry=schema_registry,
        schema_registry_url=args.schema_registry_url,
        subject_configs=subject_configs,
        repository_root=repository_root,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"Schema maintainer failed: {exc}", file=sys.stderr)
        raise SystemExit(1)