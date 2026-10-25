#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ZMK Local Build Environment Setup Script for origin36
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

DOCKER_IMAGE="zmkfirmware/zmk-build-arm:3.5-branch"
CONTAINER_WORKSPACE="/workspace"
ZMK_VERSION="v0.3.0"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: ./setup.sh [OPTIONS]

Set up the local ZMK build environment inside this working directory using Docker.

Options:
  -f, --force    Clean existing West workspace (.west, zmk, zephyr, modules, etc.)
                 and reinitialize from scratch.
  -h, --help     Show this help message.
EOF
}

check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not found in PATH."
        exit 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running or current user does not have permission to run docker."
        exit 1
    fi

    # Check if Docker image is available locally; pull if not
    if ! docker image inspect "${DOCKER_IMAGE}" &>/dev/null; then
        log_info "Docker image '${DOCKER_IMAGE}' not found locally. Pulling..."
        docker pull "${DOCKER_IMAGE}"
    else
        log_info "Docker image '${DOCKER_IMAGE}' is already available."
    fi
}

FORCE="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "${FORCE}" == "true" ]]; then
    log_warn "Force mode enabled: removing existing workspace..."
    rm -rf "${SCRIPT_DIR}/.west" \
           "${SCRIPT_DIR}/bootloader" \
           "${SCRIPT_DIR}/modules" \
           "${SCRIPT_DIR}/optional" \
           "${SCRIPT_DIR}/tools" \
           "${SCRIPT_DIR}/zephyr" \
           "${SCRIPT_DIR}/zmk"
fi

check_docker

# 1. Initialize west workspace if not already done
if [[ ! -d "${SCRIPT_DIR}/.west" ]]; then
    log_info "Initializing West workspace..."
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "${SCRIPT_DIR}:${CONTAINER_WORKSPACE}" \
        -w "${CONTAINER_WORKSPACE}" \
        "${DOCKER_IMAGE}" \
        bash -c "west init -m https://github.com/zmkfirmware/zmk --mr main --mf app/west.yml"
else
    log_info "West workspace already initialized (.west exists)."
fi

# 2. Pin ZMK to target stable release version
if [[ -d "${SCRIPT_DIR}/zmk" ]]; then
    log_info "Setting ZMK repository to ${ZMK_VERSION}..."
    git -C "${SCRIPT_DIR}/zmk" checkout "${ZMK_VERSION}" 2>/dev/null || true
fi

# 3. Update West dependencies
log_info "Fetching West dependencies (west update)... This may take a few minutes."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "${SCRIPT_DIR}:${CONTAINER_WORKSPACE}" \
    -w "${CONTAINER_WORKSPACE}" \
    "${DOCKER_IMAGE}" \
    bash -c "west update --fetch-opt=--filter=tree:0 && west zephyr-export"

echo ""
log_success "ZMK local build environment setup is complete!"
log_info "You can now build firmware using:"
echo -e "  ${GREEN}./build.sh${NC}        # Build all targets (left, right, reset)"
echo -e "  ${GREEN}./build.sh left${NC}   # Build left half only"
echo -e "  ${GREEN}./build.sh right${NC}  # Build right half only"
echo -e "  ${GREEN}./build.sh reset${NC}  # Build settings reset only"
