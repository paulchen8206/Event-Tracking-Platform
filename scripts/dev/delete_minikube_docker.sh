#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: delete_minikube_docker.sh [--profile <name>]

Options:
  --profile <name>  Minikube profile name (default: etp-dev)
  -h, --help        Show this help message
EOF
}

profile="etp-dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v minikube >/dev/null 2>&1; then
  echo "Missing required command: minikube" >&2
  exit 1
fi

echo "Deleting Minikube profile '$profile'..."
minikube delete --profile "$profile"

echo "Done."
