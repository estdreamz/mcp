#!/bin/bash
# ECR Publish Script for MariaDB MCP Server
# Publishes Docker image to AWS ECR

set -e

# Resolve script directory and repo root so paths work whether script is
# executed from repo root or from the scripts directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() {
    local message=$1
    echo -e "\033[0;36m$(date '+%Y-%m-%d %H:%M:%S.%3N') - INFO - $message\033[0m"
}

log_error() {
    local message=$1
    echo -e "\033[0;31m$(date '+%Y-%m-%d %H:%M:%S.%3N') - ERROR - $message\033[0m" >&2
}

validate_env_variables() {
    log_info "Validating required environment variables..."

    # Check AWS credentials
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        log_error "AWS_ACCESS_KEY_ID environment variable is not set"
        exit 1
    fi

    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_error "AWS_SECRET_ACCESS_KEY environment variable is not set"
        exit 1
    fi

    if [ -z "$AWS_REGION" ]; then
        log_error "AWS_REGION environment variable is not set"
        exit 1
    fi

    if [ -z "$AWS_ACCOUNT_ID" ]; then
        log_error "AWS_ACCOUNT_ID environment variable is not set"
        exit 1
    fi

    log_info "AWS credentials validation successful"
}

# Load environment variables from .env.dev file (located in repo root)
if [ -f "${REPO_ROOT}/.env.dev" ]; then
    log_info "Loading environment variables from ${REPO_ROOT}/.env.dev file"
    set -a  # automatically export all variables
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/.env.dev"
    set +a  # disable automatic export
else
    log_error ".env.dev file not found at ${REPO_ROOT}/.env.dev. Please create a .env.dev file with the required variables."
    exit 1
fi

# Validate all required environment variables
validate_env_variables

# Validate repository variables
if [ -z "$LOCAL_IMAGE_NAME" ]; then
    log_error "LOCAL_IMAGE_NAME environment variable is not set"
    exit 1
fi

if [ -z "$REPO_NAME" ]; then
    log_error "REPO_NAME environment variable is not set"
    exit 1
fi

if [ -z "$BUILD_TAG" ]; then
    log_error "BUILD_TAG environment variable is not set"
    exit 1
fi

log_info "Repository variables validation successful"

local_image_name="$LOCAL_IMAGE_NAME"
repo_name="$REPO_NAME"
repo_version="$BUILD_TAG"

# Ensure we operate from the repository root so relative paths (Dockerfile, src/, etc.) resolve correctly
log_info "Changing working directory to repo root: ${REPO_ROOT}"
cd "${REPO_ROOT}"

# Verify required files exist
log_info "Verifying project structure..."
if [ ! -f "${REPO_ROOT}/Dockerfile" ]; then
    log_error "Dockerfile not found at ${REPO_ROOT}/Dockerfile"
    exit 1
fi

if [ ! -f "${REPO_ROOT}/pyproject.toml" ]; then
    log_error "pyproject.toml not found at ${REPO_ROOT}/pyproject.toml"
    exit 1
fi

if [ ! -d "${REPO_ROOT}/src" ]; then
    log_error "src/ directory not found at ${REPO_ROOT}/src"
    exit 1
fi

log_info "Project structure verified successfully"

# Setup Docker buildx for multi-platform builds
log_info "Setting up Docker buildx for multi-platform builds"
# Create or use existing buildx builder
if ! docker buildx inspect multiplatform-builder >/dev/null 2>&1; then
    log_info "Creating new buildx builder: multiplatform-builder"
    docker buildx create --name multiplatform-builder --use
else
    log_info "Using existing buildx builder: multiplatform-builder"
    docker buildx use multiplatform-builder
fi

# Bootstrap the builder to ensure it's ready
log_info "Bootstrapping buildx builder..."
docker buildx inspect --bootstrap

create_ecr_repo() {
    if aws ecr describe-repositories --repository-names ${repo_name} >/dev/null 2>&1; then
        log_info "ECR repository ${repo_name} exists."
    else
        log_info "Creating ECR repository: ${repo_name}"
        aws ecr create-repository --repository-name ${repo_name}
    fi
}

region="$AWS_REGION"
aws_accountid="$AWS_ACCOUNT_ID"

ecr_repo_name="$aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"
container_name="ecr_$repo_name"

log_info "Logging into ECR registry"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin "$aws_accountid.dkr.ecr.$region.amazonaws.com"

create_ecr_repo ${repo_name}

log_info "Building and pushing multi-platform image to ECR"
log_info "Target: $aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"
log_info "Platforms: linux/amd64, linux/arm64"

# Build and push multi-platform image directly to ECR
# Using --push flag to push both platform variants
docker buildx build \
    --platform=linux/amd64,linux/arm64 \
    -t "$aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version" \
    -f "${REPO_ROOT}/Dockerfile" \
    "${REPO_ROOT}" \
    --push

if [ $? -ne 0 ]; then
    log_error "Failed to build and push multi-platform image to ECR"
    exit 1
fi

log_info "Current docker images:"
docker images | grep -E "(REPOSITORY|$repo_name)" || docker images

log_info "ECR publish completed successfully"
log_info "Image available at: $aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"
