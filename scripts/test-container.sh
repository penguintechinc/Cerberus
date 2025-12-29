#!/bin/bash
##############################################################################
# Unified Container Test Runner
# Purpose: Execute build, run, API, health, and comprehensive tests
# Accepts: container name and test type (build, run, api, health, all)
# Usage: ./scripts/test-container.sh <container-name> <test-type>
#        ./scripts/test-container.sh all [test-type]  # Run all containers
##############################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_ROOT/tests"
LOG_DIR="/tmp/cerberus"
EPOCH_TS=$(date +%s)

# Detect docker compose command (plugin vs standalone)
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    echo "ERROR: Neither 'docker compose' nor 'docker-compose' found"
    exit 1
fi

# All container names
ALL_CONTAINERS=(
    "cerberus-api"
    "cerberus-webui"
    "cerberus-ips"
    "cerberus-filter"
    "cerberus-ssl-inspector"
    "cerberus-vpn-wireguard"
    "cerberus-vpn-ipsec"
    "cerberus-vpn-openvpn"
    "cerberus-xdp"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Current log file (set per-container in parallel mode)
CURRENT_LOG_FILE=""

##############################################################################
# Logging Functions
##############################################################################

# Setup log directory
setup_logging() {
    mkdir -p "$LOG_DIR"
}

# Log to both stdout and file (if set)
log_output() {
    local message="$1"
    if [ -n "$CURRENT_LOG_FILE" ]; then
        echo -e "$message" | tee -a "$CURRENT_LOG_FILE"
    else
        echo -e "$message"
    fi
}

# Log to file only (no color codes)
log_file_only() {
    local message="$1"
    if [ -n "$CURRENT_LOG_FILE" ]; then
        echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g' >> "$CURRENT_LOG_FILE"
    fi
}

log_info() {
    log_output "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log_output "${GREEN}[OK]${NC} $1"
}

log_error() {
    log_output "${RED}[ERROR]${NC} $1"
}

log_warn() {
    log_output "${YELLOW}[WARN]${NC} $1"
}

log_header() {
    log_output "${MAGENTA}══════════════════════════════════════════════════════════════${NC}"
    log_output "${MAGENTA}  $1${NC}"
    log_output "${MAGENTA}══════════════════════════════════════════════════════════════${NC}"
}

##############################################################################
# Validation Functions
##############################################################################

validate_container() {
    local container=$1

    # Check if container exists in docker-compose
    if ! grep -q "container_name: $container\|services:" "$PROJECT_ROOT/docker-compose.yml"; then
        log_error "Container '$container' not found in docker-compose.yml"
        return 1
    fi

    return 0
}

validate_test_type() {
    local test_type=$1

    case "$test_type" in
        build|run|api|health|page|all)
            return 0
            ;;
        *)
            log_error "Invalid test type: $test_type"
            log_info "Valid types: build, run, api, health, page, all"
            return 1
            ;;
    esac
}

##############################################################################
# Build Test
##############################################################################

test_build() {
    local container=$1

    log_info "Testing build for container: $container"

    local build_output
    if build_output=$($DOCKER_COMPOSE -f "$PROJECT_ROOT/docker-compose.yml" build "$container" 2>&1); then
        if [ -n "$CURRENT_LOG_FILE" ]; then
            echo "$build_output" >> "$CURRENT_LOG_FILE"
        fi
        log_success "Build test passed for $container"
        return 0
    else
        if [ -n "$CURRENT_LOG_FILE" ]; then
            echo "$build_output" >> "$CURRENT_LOG_FILE"
        fi
        log_error "Build test failed for $container"
        log_output "$build_output"
        return 1
    fi
}

##############################################################################
# Run Test
##############################################################################

test_run() {
    local container=$1

    log_info "Testing run for container: $container"

    # Check if container is running
    if docker ps --filter "name=$container" --format '{{.Names}}' | grep -q "$container"; then
        log_success "Container $container is running"
        return 0
    else
        log_warn "Container $container is not running"
        return 1
    fi
}

##############################################################################
# Health Check Test
##############################################################################

test_health() {
    local container=$1

    log_info "Testing health check for container: $container"

    # Check if container exists first
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        log_warn "Container $container does not exist"
        return 1
    fi

    # Get health status from docker inspect (trim whitespace)
    local health_status
    health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null | tr -d '[:space:]')

    # Handle empty response
    if [ -z "$health_status" ]; then
        health_status="none"
    fi

    case "$health_status" in
        healthy)
            log_success "Health check passed for $container"
            return 0
            ;;
        starting)
            log_warn "Health check in progress for $container"
            return 1
            ;;
        unhealthy)
            log_error "Health check failed for $container"
            docker inspect --format='{{.State.Health.Log}}' "$container" 2>/dev/null | tail -5
            return 1
            ;;
        none|"")
            log_warn "No health check configured for $container"
            return 0
            ;;
        *)
            log_error "Unknown health status: '$health_status'"
            return 1
            ;;
    esac
}

##############################################################################
# API Test
##############################################################################

test_api() {
    local container=$1
    local test_script="$TESTS_DIR/api/test-${container}.sh"

    log_info "Testing API endpoints for container: $container"

    # Check if test script exists for this container
    if [ -f "$test_script" ]; then
        bash "$test_script"
        return $?
    else
        log_warn "No API test script found at: $test_script"
        return 0
    fi
}

##############################################################################
# Page Load Test (for WebUI)
##############################################################################

test_page() {
    local container=$1

    log_info "Testing page loads for container: $container"

    # Only applicable to webui container
    if [ "$container" != "cerberus-webui" ]; then
        log_warn "Page tests only apply to cerberus-webui container"
        return 0
    fi

    local webui_url="${WEBUI_URL:-http://localhost:3000}"
    local pages=("/" "/login" "/dashboard" "/firewall" "/ips" "/vpn" "/filter" "/settings")
    local failed=0

    for page in "${pages[@]}"; do
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$webui_url$page" 2>/dev/null)
        if [ "$status" = "200" ] || [ "$status" = "304" ]; then
            log_success "Page $page loaded (HTTP $status)"
        else
            log_error "Page $page failed (HTTP $status)"
            ((failed++))
        fi
    done

    # Test static assets
    local assets_status=$(curl -s -o /dev/null -w "%{http_code}" "$webui_url/static/js/main.js" 2>/dev/null || echo "000")
    if [ "$assets_status" = "200" ] || [ "$assets_status" = "304" ]; then
        log_success "Static assets accessible"
    else
        log_warn "Static assets check returned HTTP $assets_status"
    fi

    return $failed
}

##############################################################################
# Comprehensive Test (All)
##############################################################################

test_all() {
    local container=$1
    local failed=0

    log_info "Running all tests for container: $container"
    echo ""

    # Run all tests in sequence
    test_build "$container" || ((failed++))
    echo ""

    test_run "$container" || ((failed++))
    echo ""

    test_health "$container" || ((failed++))
    echo ""

    test_api "$container" || ((failed++))
    echo ""

    # Page tests only for webui
    if [ "$container" = "cerberus-webui" ]; then
        test_page "$container" || ((failed++))
    fi

    return $failed
}

##############################################################################
# Run Single Container Test (with logging)
##############################################################################

run_container_test() {
    local container=$1
    local test_type=$2
    local log_file="$LOG_DIR/${container}-${test_type}-${EPOCH_TS}.log"

    # Set the current log file for this process
    CURRENT_LOG_FILE="$log_file"

    # Write header to log
    {
        echo "============================================================"
        echo "Container: $container"
        echo "Test Type: $test_type"
        echo "Timestamp: $(date -Iseconds)"
        echo "Epoch: $EPOCH_TS"
        echo "============================================================"
        echo ""
    } > "$log_file"

    log_header "Testing: $container ($test_type)"

    local exit_code=0

    # Run requested test(s)
    case "$test_type" in
        build)
            test_build "$container" || exit_code=$?
            ;;
        run)
            test_run "$container" || exit_code=$?
            ;;
        health)
            test_health "$container" || exit_code=$?
            ;;
        api)
            test_api "$container" || exit_code=$?
            ;;
        page)
            test_page "$container" || exit_code=$?
            ;;
        all)
            test_all "$container" || exit_code=$?
            ;;
    esac

    # Write footer to log
    {
        echo ""
        echo "============================================================"
        echo "Completed: $(date -Iseconds)"
        echo "Exit Code: $exit_code"
        echo "============================================================"
    } >> "$log_file"

    if [ $exit_code -eq 0 ]; then
        log_success "Completed $container ($test_type) - Log: $log_file"
    else
        log_error "Failed $container ($test_type) - Log: $log_file"
    fi

    return $exit_code
}

##############################################################################
# Run All Containers in Parallel
##############################################################################

run_all_containers_parallel() {
    local test_type=${1:-all}
    local pids=()
    local containers=()
    local exit_codes=()
    local summary_log="$LOG_DIR/summary-${EPOCH_TS}.log"

    setup_logging

    log_header "Running All Container Tests in Parallel"
    log_info "Test type: $test_type"
    log_info "Log directory: $LOG_DIR"
    log_info "Summary log: $summary_log"
    echo ""

    # Write summary header
    {
        echo "============================================================"
        echo "Cerberus Container Test Summary"
        echo "Test Type: $test_type"
        echo "Started: $(date -Iseconds)"
        echo "Epoch: $EPOCH_TS"
        echo "============================================================"
        echo ""
    } > "$summary_log"

    # Fork tests for each container
    for container in "${ALL_CONTAINERS[@]}"; do
        log_info "Forking test for: $container"

        # Run in background subshell
        (
            run_container_test "$container" "$test_type"
        ) &

        pids+=($!)
        containers+=("$container")
    done

    log_info "Launched ${#pids[@]} parallel tests"
    echo ""
    log_info "Waiting for all tests to complete..."
    echo ""

    # Wait for all processes and collect exit codes
    local failed_count=0
    local passed_count=0

    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local container=${containers[$i]}

        if wait "$pid"; then
            exit_codes+=("0")
            ((passed_count++))
            echo "$container: PASSED" >> "$summary_log"
        else
            local code=$?
            exit_codes+=("$code")
            ((failed_count++))
            echo "$container: FAILED (exit code: $code)" >> "$summary_log"
        fi
    done

    echo "" >> "$summary_log"

    # Print summary
    echo ""
    log_header "Test Summary"
    echo ""

    for i in "${!containers[@]}"; do
        local container=${containers[$i]}
        local code=${exit_codes[$i]}
        local log_file="$LOG_DIR/${container}-${test_type}-${EPOCH_TS}.log"

        if [ "$code" = "0" ]; then
            log_success "$container: PASSED"
        else
            log_error "$container: FAILED (exit code: $code)"
        fi
        log_info "  Log: $log_file"
    done

    echo ""
    log_info "═══════════════════════════════════════════"
    log_info "  Total: ${#containers[@]} | Passed: $passed_count | Failed: $failed_count"
    log_info "═══════════════════════════════════════════"
    echo ""

    # Write summary footer
    {
        echo "============================================================"
        echo "Completed: $(date -Iseconds)"
        echo "Total: ${#containers[@]}"
        echo "Passed: $passed_count"
        echo "Failed: $failed_count"
        echo "============================================================"
    } >> "$summary_log"

    log_info "Summary log: $summary_log"
    log_info "Individual logs: $LOG_DIR/<container>-${test_type}-${EPOCH_TS}.log"

    # Return failure if any test failed
    if [ $failed_count -gt 0 ]; then
        return 1
    fi
    return 0
}

##############################################################################
# Usage
##############################################################################

usage() {
    cat << EOF
${BLUE}Unified Container Test Runner${NC}

Usage: $0 <container-name> <test-type>
       $0 all [test-type]              Run all containers in parallel

Container Names:
  - all                     Run ALL containers in parallel (with forking)
  - cerberus-api            Flask backend API
  - cerberus-webui          React frontend
  - cerberus-ips            Suricata IPS/IDS
  - cerberus-filter         Content filter (Go)
  - cerberus-ssl-inspector  SSL/TLS inspection (Go)
  - cerberus-vpn-wireguard  WireGuard VPN
  - cerberus-vpn-ipsec      IPSec/IKEv2 VPN (StrongSwan)
  - cerberus-vpn-openvpn    OpenVPN server
  - go-backend              Go high-performance backend

Test Types:
  - build                 Build container image
  - run                   Check if container is running
  - health                Check health status
  - api                   Run API endpoint tests
  - page                  Run page load tests (webui only)
  - all                   Run all tests in sequence

Logging:
  All test output is logged to: /tmp/cerberus/<container>-<test>-<epoch>.log
  Summary log: /tmp/cerberus/summary-<epoch>.log

Examples:
  $0 cerberus-api all           # Run all tests for cerberus-api
  $0 cerberus-api health        # Run health check for cerberus-api
  $0 cerberus-webui page        # Run page load tests for webui
  $0 cerberus-ips api           # Run API tests for IPS
  $0 cerberus-vpn-wireguard build

  $0 all                        # Run ALL containers with ALL tests (parallel)
  $0 all build                  # Build ALL containers (parallel)
  $0 all health                 # Health check ALL containers (parallel)
  $0 all api                    # API test ALL containers (parallel)

EOF
}

##############################################################################
# Main
##############################################################################

main() {
    # Handle no arguments
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi

    local container=$1
    local test_type=${2:-all}

    # Setup log directory
    setup_logging

    # Change to project root
    cd "$PROJECT_ROOT"

    # Handle "all" containers (parallel execution)
    if [ "$container" = "all" ]; then
        # Validate test type if provided
        if [ $# -ge 2 ] && ! validate_test_type "$test_type"; then
            exit 1
        fi

        run_all_containers_parallel "$test_type"
        exit $?
    fi

    # Single container mode requires both arguments
    if [ $# -lt 2 ]; then
        usage
        exit 1
    fi

    # Validate inputs for single container
    if ! validate_container "$container"; then
        exit 1
    fi

    if ! validate_test_type "$test_type"; then
        exit 1
    fi

    # Run single container test with logging
    run_container_test "$container" "$test_type"
    exit $?
}

main "$@"
