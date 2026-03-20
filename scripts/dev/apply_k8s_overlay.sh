#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apply_k8s_overlay.sh [--dry-run] [--check-only] <dev|staging|prod>

Options:
  --dry-run     Validate manifests with kubectl apply --dry-run=client.
  --check-only  Run preflight checks only and do not apply manifests.
EOF
}

dry_run=false
check_only=false
overlay=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --check-only)
      check_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    dev|staging|prod)
      if [[ -n "$overlay" ]]; then
        echo "Overlay already set to: $overlay"
        usage
        exit 1
      fi
      overlay="$1"
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$overlay" ]]; then
  usage
  exit 1
fi

if [[ "$dry_run" == true && "$check_only" == true ]]; then
  echo "--dry-run and --check-only cannot be used together"
  exit 1
fi

case "$overlay" in
  dev|staging|prod)
    ;;
  *)
    echo "Invalid overlay: $overlay"
    echo "Expected one of: dev, staging, prod"
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
base_dir="$repo_root/infra/kubernetes/base"
overlay_dir="$repo_root/infra/kubernetes/overlays/$overlay"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "Preflight failed: $message"
    echo "Missing pattern: $needle"
    exit 1
  fi
}

run_preflight_checks() {
  local rendered
  rendered="$(kubectl kustomize "$overlay_dir")"

  assert_contains "$rendered" "kind: Namespace" "overlay must include namespaces"

  assert_contains "$rendered" "name: ${overlay}-platform-kafka" "missing kafka namespace"
  assert_contains "$rendered" "name: ${overlay}-platform-flink" "missing flink namespace"
  assert_contains "$rendered" "name: ${overlay}-app-ingestion-api" "missing ingestion-api namespace"
  assert_contains "$rendered" "name: ${overlay}-app-serving-api" "missing serving-api namespace"

  assert_contains "$rendered" "kind: RoleBinding" "overlay must include role bindings"
  assert_contains "$rendered" "name: ${overlay}-platform-kafka-admins" "missing kafka team role binding"
  assert_contains "$rendered" "name: ${overlay}-app-team-writers-serving" "missing serving team role binding"

  assert_contains "$rendered" "kind: NetworkPolicy" "overlay must include network policies"
  assert_contains "$rendered" "name: allow-ingestion-api-to-kafka" "missing ingestion-to-kafka allowlist"
  assert_contains "$rendered" "name: allow-flink-to-kafka" "missing flink-to-kafka allowlist"
  assert_contains "$rendered" "name: allow-serving-api-to-kafka" "missing serving-to-kafka allowlist"

  echo "Preflight checks passed for overlay: $overlay"
}

require_command kubectl

echo "Running preflight checks..."
run_preflight_checks

if [[ "$check_only" == true ]]; then
  echo "Check-only mode complete. No manifests applied."
  exit 0
fi

if [[ "$dry_run" == true ]]; then
  echo "Dry-run: validating base manifests..."
  kubectl apply --dry-run=client -k "$base_dir"

  echo "Dry-run: validating $overlay overlay..."
  kubectl apply --dry-run=client -k "$overlay_dir"

  echo "Dry-run complete. No manifests applied."
  exit 0
fi

echo "Applying base manifests..."
kubectl apply -k "$base_dir"

echo "Applying $overlay overlay..."
kubectl apply -k "$overlay_dir"

echo "Done. Applied base + $overlay overlay."