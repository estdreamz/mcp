#!/bin/bash
# ============================================================================
# Docker Build Script - MariaDB MCP Server
# ============================================================================
# Purpose:
#   Build a slim production Docker image with multi-stage optimization
#
# Features:
#   - Multi-stage build for minimal image size
#   - Dependency caching via uv for faster rebuilds
#   - Security scanning with Trivy (optional)
#   - Build metrics and validation
#
# Usage:
#   ./scripts/build-docker.sh                    # Build with defaults
#   IMAGE_NAME=myapp IMAGE_TAG=v1.0.0 ./scripts/build-docker.sh
#   DOCKERFILE=Dockerfile.prod ./scripts/build-docker.sh
#
# Environment Variables:
#   IMAGE_NAME    - Docker image name (default: mariadb-mcp)
#   IMAGE_TAG     - Docker image tag (default: latest)
#   DOCKERFILE    - Dockerfile to use (default: Dockerfile)
#   SKIP_TRIVY    - Skip security scan (default: false)
#   BUILD_ARGS    - Additional docker build arguments
#
# Requirements:
#   - Docker installed and running
#   - Sufficient disk space for build cache
#
# Output:
#   Docker image: ${IMAGE_NAME}:${IMAGE_TAG}
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================

# Default values
IMAGE_NAME="${IMAGE_NAME:-mariadb-mcp}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
SKIP_TRIVY="${SKIP_TRIVY:-false}"
BUILD_ARGS="${BUILD_ARGS:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi

    # Check if Dockerfile exists
    if [[ ! -f "${DOCKERFILE}" ]]; then
        log_error "Dockerfile not found: ${DOCKERFILE}"
        exit 1
    fi

    # Check if we're in the project root
    if [[ ! -f "pyproject.toml" ]]; then
        log_error "pyproject.toml not found. Please run this script from the project root."
        exit 1
    fi

    log_success "Pre-flight checks passed"
}

# ============================================================================
# Main Build Process
# ============================================================================

print_header "Building MariaDB MCP Server"

log_info "Build Configuration:"
echo "  Image Name:    ${IMAGE_NAME}"
echo "  Image Tag:     ${IMAGE_TAG}"
echo "  Dockerfile:    ${DOCKERFILE}"
echo "  Build Args:    ${BUILD_ARGS:-none}"
echo ""

# Run pre-flight checks
preflight_checks

# Record start time
START_TIME=$(date +%s)

# ============================================================================
# Step 1: Build Docker Image
# ============================================================================

print_header "Step 1/4: Building Docker Image"

log_info "Building multi-stage Docker image..."
log_info "This includes:"
echo "  - Python 3.11 slim base image"
echo "  - uv dependency installation (no-dev)"
echo "  - Multi-stage build for minimal image size"
echo ""

# Build the image
if docker build \
    -f "${DOCKERFILE}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    ${BUILD_ARGS} \
    . ; then
    log_success "Docker image built successfully!"
else
    log_error "Docker build failed!"
    exit 1
fi

# ============================================================================
# Step 2: Validate Image
# ============================================================================

print_header "Step 2/4: Validating Image"

log_info "Checking image size..."
IMAGE_SIZE=$(docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Size}}")
log_success "Image size: ${IMAGE_SIZE}"

log_info "Verifying image metadata..."
docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# ============================================================================
# Step 3: Security Scan (Optional)
# ============================================================================

print_header "Step 3/4: Security Scan"

if [[ "${SKIP_TRIVY}" == "true" ]]; then
    log_warning "Security scan skipped (SKIP_TRIVY=true)"
elif command -v trivy &> /dev/null; then
    log_info "Running Trivy security scan..."
    if trivy image --severity HIGH,CRITICAL "${IMAGE_NAME}:${IMAGE_TAG}"; then
        log_success "Security scan completed"
    else
        log_warning "Security scan found vulnerabilities"
    fi
else
    log_warning "Trivy not installed. Skipping security scan."
    echo "  Install Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
fi

# ============================================================================
# Step 4: Build Summary
# ============================================================================

print_header "Step 4/4: Build Summary"

END_TIME=$(date +%s)
BUILD_DURATION=$((END_TIME - START_TIME))

log_success "Build completed successfully!"
echo ""
echo "Build Details:"
echo "  Image:         ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Size:          ${IMAGE_SIZE}"
echo "  Build Time:    ${BUILD_DURATION} seconds"
echo ""

# ============================================================================
# Usage Instructions
# ============================================================================

print_header "🚀 Ready to Deploy!"

echo "Run the container:"
echo "  docker run -p 30003:30003 --env-file .env.local ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose --env-file .env.local up"
echo ""
echo "Note: Default image name is 'mariadb-mcp'"
echo ""
echo "Access the application:"
echo "  - MCP HTTP:    http://localhost:30003/mcp"
echo "  - MCP SSE:     http://localhost:30003/sse"
echo ""

log_info "For more details, see README.md"
