#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup_minikube_docker.sh [options]

Options:
  --profile <name>         Minikube profile name (default: etp-dev)
  --cpus <count>           CPU count for cluster nodes (default: 4)
  --memory <mb>            Memory in MB (default: 8192)
  --disk-size <size>       Disk size (default: 40g)
  --k8s-version <version>  Kubernetes version (default: stable)
  --driver <driver>        Minikube driver (default: docker)
  --skip-addons            Skip enabling ingress and metrics-server addons
  --skip-overlay-apply     Skip applying infra/kubernetes base and dev overlay
  -h, --help               Show this help message
EOF
}

profile="etp-dev"
cpus="4"
memory="8192"
disk_size="40g"
k8s_version="stable"
driver="docker"
skip_addons=false
skip_overlay_apply=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="$2"
      shift 2
      ;;
    --cpus)
      cpus="$2"
      shift 2
      ;;
    --memory)
      memory="$2"
      shift 2
      ;;
    --disk-size)
      disk_size="$2"
      shift 2
      ;;
    --k8s-version)
      k8s_version="$2"
      shift 2
      ;;
    --driver)
      driver="$2"
      shift 2
      ;;
    --skip-addons)
      skip_addons=true
      shift
      ;;
    --skip-overlay-apply)
      skip_overlay_apply=true
      shift
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

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

assert_docker_ready() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker does not appear to be running. Start Docker Desktop and try again." >&2
    exit 1
  fi
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
apply_script="$repo_root/scripts/dev/apply_k8s_overlay.sh"

require_command docker
require_command kubectl
require_command minikube
assert_docker_ready

if [[ ! -x "$apply_script" ]]; then
  echo "Expected executable script not found: $apply_script" >&2
  exit 1
fi

echo "Starting Minikube profile '$profile' with driver '$driver'..."
minikube start \
  --profile "$profile" \
  --driver "$driver" \
  --cpus "$cpus" \
  --memory "$memory" \
  --disk-size "$disk_size" \
  --kubernetes-version "$k8s_version"

echo "Setting kubectl context to '$profile'..."
kubectl config use-context "$profile" >/dev/null

if [[ "$skip_addons" == false ]]; then
  echo "Enabling Minikube addons (ingress, metrics-server)..."
  minikube addons enable ingress --profile "$profile"
  minikube addons enable metrics-server --profile "$profile"
fi

echo "Waiting for nodes to become Ready..."
kubectl wait --for=condition=Ready node --all --timeout=180s

if [[ "$skip_overlay_apply" == false ]]; then
  echo "Applying Kubernetes base + dev overlay..."
  "$apply_script" dev
else
  echo "Skipping overlay apply by request."
fi

echo "Local dev environment is ready."
echo "Profile: $profile"
echo "Current context: $(kubectl config current-context)"
echo "Namespaces:"
kubectl get ns | awk 'NR==1 || /-platform-|-app-/'

echo "Tip: run 'minikube dashboard --profile $profile' for cluster UI."
