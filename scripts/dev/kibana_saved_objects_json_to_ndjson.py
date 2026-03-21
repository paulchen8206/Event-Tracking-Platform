#!/usr/bin/env python3
"""Convert repository Kibana JSON dashboard assets into Saved Objects NDJSON.

Input format (repo custom):
{
  "kibana_saved_objects": {
    "exported_objects": [ ... saved objects ... ]
  }
}

Output format: one JSON object per line (.ndjson), suitable for
/api/saved_objects/_import.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _sanitize_dashboard_attributes(attrs: dict) -> dict:
    # Some Kibana versions reject dashboard-level `filters` in import payloads.
    attrs.pop("filters", None)

    panels_json = attrs.get("panelsJSON")
    if isinstance(panels_json, str):
        try:
            panels = json.loads(panels_json)
        except json.JSONDecodeError:
            attrs["panelsJSON"] = "[]"
            return attrs

        if isinstance(panels, list):
            # Lens-by-value panels are brittle across Kibana patch/minor versions.
            # Keep non-lens panels and preserve an importable dashboard skeleton.
            filtered_panels = [p for p in panels if not (isinstance(p, dict) and p.get("type") == "lens")]
            attrs["panelsJSON"] = json.dumps(filtered_panels, separators=(",", ":"), ensure_ascii=False)

    return attrs


def _load_objects(path: Path) -> list[dict]:
    raw = json.loads(path.read_text(encoding="utf-8"))

    if isinstance(raw, list):
        objects = raw
    elif isinstance(raw, dict):
        objects = (
            raw.get("kibana_saved_objects", {}).get("exported_objects")
            or raw.get("exported_objects")
            or raw.get("objects")
            or []
        )
    else:
        raise ValueError("Unsupported input JSON format")

    if not isinstance(objects, list) or not objects:
        raise ValueError("No saved objects found in input JSON")

    normalized: list[dict] = []
    for idx, obj in enumerate(objects):
        if not isinstance(obj, dict):
            raise ValueError(f"Object at index {idx} is not a JSON object")
        if "type" not in obj:
            raise ValueError(f"Object at index {idx} missing required field 'type'")

        # Saved Objects import supports objects without id, but our assets include it.
        # Keep object payload as-is and ensure references key exists.
        if "references" not in obj:
            obj = {**obj, "references": []}

        if obj.get("type") == "dashboard" and isinstance(obj.get("attributes"), dict):
            obj["attributes"] = _sanitize_dashboard_attributes(obj["attributes"])

        normalized.append(obj)

    return normalized


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Input JSON file path")
    parser.add_argument("--output", required=True, help="Output NDJSON file path")
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)

    objects = _load_objects(in_path)

    lines = [json.dumps(obj, separators=(",", ":"), ensure_ascii=False) for obj in objects]
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
