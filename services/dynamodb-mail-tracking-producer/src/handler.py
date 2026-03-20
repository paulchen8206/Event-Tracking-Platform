from __future__ import annotations

import base64
import io
import json
import os
import time
import uuid
from typing import Any

from aws_lambda_powertools import Logger
from confluent_kafka import Producer
from fastavro import parse_schema, schemaless_writer


logger = Logger(service="dynamodb-mail-tracking-producer")

KAFKA_BOOTSTRAP_SERVERS = os.environ["KAFKA_BOOTSTRAP_SERVERS"]
KAFKA_TOPIC = os.environ.get("KAFKA_TOPIC", "evt.mail.operational.raw")
SCHEMA_ID = int(os.environ.get("KAFKA_SCHEMA_ID", "1"))


def _load_schema() -> dict[str, Any]:
    schema_path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "..",
        "..",
        "platform",
        "kafka",
        "schemas",
        "avro",
        "mail-operational-status-event.avsc",
    )
    with open(schema_path, "r", encoding="utf-8") as schema_file:
        return parse_schema(json.load(schema_file))


SCHEMA = _load_schema()
PRODUCER = Producer({"bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS})


def serialize_confluent_avro(record: dict[str, Any]) -> bytes:
    buffer = io.BytesIO()
    buffer.write(b"\x00")
    buffer.write(SCHEMA_ID.to_bytes(4, byteorder="big", signed=False))
    schemaless_writer(buffer, SCHEMA, record)
    return buffer.getvalue()


def dynamodb_attribute_value_to_python(value: dict[str, Any]) -> Any:
    if "S" in value:
        return value["S"]
    if "N" in value:
        number = value["N"]
        return int(number) if number.isdigit() else float(number)
    if "BOOL" in value:
        return value["BOOL"]
    if "NULL" in value:
        return None
    if "M" in value:
        return {key: dynamodb_attribute_value_to_python(item) for key, item in value["M"].items()}
    if "L" in value:
        return [dynamodb_attribute_value_to_python(item) for item in value["L"]]
    return value


def unmarshall_dynamodb_image(image: dict[str, Any]) -> dict[str, Any]:
    return {key: dynamodb_attribute_value_to_python(value) for key, value in image.items()}


def build_operational_event(record: dict[str, Any]) -> dict[str, Any] | None:
    dynamodb = record.get("dynamodb", {})
    new_image = dynamodb.get("NewImage")
    if not new_image:
        return None

    item = unmarshall_dynamodb_image(new_image)
    event_time_ms = int(time.time() * 1000)
    message_id = item.get("message_id") or item.get("mail_id") or str(uuid.uuid4())
    correlation_id = item.get("correlation_id") or message_id

    payload = {
        "status": item.get("status", "unknown"),
        "mailbox_id": item.get("mailbox_id", "unknown"),
        "processing_stage": item.get("processing_stage", "unknown"),
        "error_code": item.get("error_code"),
        "error_message": item.get("error_message"),
        "provider": item.get("provider"),
        "updated_at": item.get("updated_at") or item.get("last_updated_at") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    return {
        "event_id": str(uuid.uuid4()),
        "event_type": "mail.operational.status_changed",
        "event_version": "1.0.0",
        "event_time": event_time_ms,
        "ingested_at": event_time_ms,
        "source_system": "dynamodb.mail_tracking",
        "tenant_id": item.get("tenant_id"),
        "message_id": str(message_id),
        "correlation_id": str(correlation_id),
        "trace_id": item.get("trace_id"),
        "actor_type": "system",
        "status": str(payload["status"]),
        "mailbox_id": str(payload["mailbox_id"]),
        "processing_stage": str(payload["processing_stage"]),
        "error_code": payload["error_code"],
        "error_message": payload["error_message"],
        "provider": payload["provider"],
        "payload_json": json.dumps(payload),
    }


@logger.inject_lambda_context(log_event=True)
def handler(event: dict[str, Any], _context: Any) -> dict[str, int]:
    produced = 0
    for stream_record in event.get("Records", []):
        operational_event = build_operational_event(stream_record)
        if operational_event is None:
            continue

        producer_key = operational_event["message_id"]
        producer_value = serialize_confluent_avro(operational_event)
        PRODUCER.produce(KAFKA_TOPIC, key=producer_key.encode("utf-8"), value=producer_value)
        produced += 1

    PRODUCER.flush()
    return {"produced": produced}