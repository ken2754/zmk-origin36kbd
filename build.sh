#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ZMK Local Build Script for origin36 (Docker-based)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

DOCKER_IMAGE="zmkfirmware/zmk-build-arm:3.5-branch"
CONTAINER_WORKSPACE="/workspace"
OUTPUT_DIR="${SCRIPT_DIR}/firmware"
BUILD_DIR="${SCRIPT_DIR}/build"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
Usage: ./build.sh [TARGET] [OPTIONS]

Targets:
  all            Build left, right, and settings_reset (default)
  left           Build left half (shield: origin36_left)
  right          Build right half (shield: origin36_right)
  reset          Build settings reset firmware (shield: settings_reset)
  clean          Remove build artifacts (build/ and firmware/ directories)
  init           Initialize or update West workspace dependencies

Options:
  -p, --pristine Force pristine CMake configure (clean build cache)
  -h, --help     Show this help message

Output:
  Compiled .uf2 files will be placed into the 'firmware/' directory.
EOF
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not found in PATH."
        exit 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running or current user does not have permission to run docker."
        exit 1
    fi
}

check_workspace() {
    if [[ ! -d "${SCRIPT_DIR}/.west" || ! -d "${SCRIPT_DIR}/zmk" || ! -d "${SCRIPT_DIR}/zephyr" ]]; then
        log_warn "West workspace not fully initialized. Initializing now..."
        init_workspace
    fi
}

init_workspace() {
    if [[ -x "${SCRIPT_DIR}/setup.sh" ]]; then
        "${SCRIPT_DIR}/setup.sh"
    else
        check_docker
        log_info "Initializing West workspace (ZMK v0.3.0 / Zephyr 3.5)..."

        if [[ ! -d "${SCRIPT_DIR}/.west" ]]; then
            docker run --rm \
                --user "$(id -u):$(id -g)" \
                -v "${SCRIPT_DIR}:${CONTAINER_WORKSPACE}" \
                -w "${CONTAINER_WORKSPACE}" \
                "${DOCKER_IMAGE}" \
                bash -c "west init -m https://github.com/zmkfirmware/zmk --mr main --mf app/west.yml"
        fi

        git -C "${SCRIPT_DIR}/zmk" checkout v0.3.0 2>/dev/null || true

        log_info "Fetching West dependencies (west update)..."
        docker run --rm \
            --user "$(id -u):$(id -g)" \
            -v "${SCRIPT_DIR}:${CONTAINER_WORKSPACE}" \
            -w "${CONTAINER_WORKSPACE}" \
            "${DOCKER_IMAGE}" \
            bash -c "west update --fetch-opt=--filter=tree:0 && west zephyr-export"

        log_success "Workspace initialized successfully."
    fi
}

build_target() {
    local target_name="$1"
    local board="$2"
    local shield="$3"
    local pristine_flag="$4"
    local target_build_dir="${BUILD_DIR}/${target_name}"

    log_info "----------------------------------------------------"
    log_info "Building target: ${target_name} (board: ${board}, shield: ${shield})"
    log_info "----------------------------------------------------"

    local pristine_arg=""
    if [[ "${pristine_flag}" == "true" ]]; then
        pristine_arg="-p"
    fi

    # Build inside container
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "${SCRIPT_DIR}:${CONTAINER_WORKSPACE}" \
        -w "${CONTAINER_WORKSPACE}" \
        "${DOCKER_IMAGE}" \
        bash -c "west zephyr-export >/dev/null 2>&1 && \
                 west build -s zmk/app -d build/${target_name} -b ${board} ${pristine_arg} -- \
                 -DSHIELD=${shield} \
                 -DZMK_CONFIG=${CONTAINER_WORKSPACE}/config"

    # Copy output uf2
    local src_uf2="${target_build_dir}/zephyr/zmk.uf2"
    local dest_uf2="${OUTPUT_DIR}/${shield}-${board}-zmk.uf2"

    if [[ -f "${src_uf2}" ]]; then
        mkdir -p "${OUTPUT_DIR}"
        cp "${src_uf2}" "${dest_uf2}"
        log_success "Generated: firmware/$(basename "${dest_uf2}")"
    else
        log_error "Build succeeded but ${src_uf2} not found."
        return 1
    fi
}

clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${OUTPUT_DIR}"
    log_success "Cleaned build/ and firmware/ directories."
}

# Parse arguments
TARGET="all"
PRISTINE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        all|left|right|reset|clean|init)
            TARGET="$1"
            shift
            ;;
        -p|--pristine)
            PRISTINE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option or target: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "${TARGET}" == "clean" ]]; then
    clean_build
    exit 0
fi

if [[ "${TARGET}" == "init" ]]; then
    init_workspace
    exit 0
fi

check_docker
check_workspace

mkdir -p "${OUTPUT_DIR}"

case "${TARGET}" in
    left)
        build_target "left" "nice_nano_v2" "origin36_left" "${PRISTINE}"
        ;;
    right)
        build_target "right" "nice_nano_v2" "origin36_right" "${PRISTINE}"
        ;;
    reset)
        build_target "settings_reset" "nice_nano_v2" "settings_reset" "${PRISTINE}"
        ;;
    all)
        build_target "left" "nice_nano_v2" "origin36_left" "${PRISTINE}"
        build_target "right" "nice_nano_v2" "origin36_right" "${PRISTINE}"
        build_target "settings_reset" "nice_nano_v2" "settings_reset" "${PRISTINE}"
        ;;
esac

echo ""
log_success "All requested builds completed successfully!"
log_info "Firmware files are available in: ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}"/*.uf2 2>/dev/null || true
