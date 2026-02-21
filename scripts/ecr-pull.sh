#!/bin/bash
# ECR Pull Script for MariaDB MCP Server
# Pulls Docker image from AWS ECR

set -e

# Resolve script directory and repo root for consistent .env loading
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
if [ -z "$REPO_NAME" ]; then
    log_error "REPO_NAME environment variable is not set"
    exit 1
fi

if [ -z "$BUILD_TAG" ]; then
    log_error "BUILD_TAG environment variable is not set"
    exit 1
fi

log_info "Repository variables validation successful"

repo_name="$REPO_NAME"
repo_version="$BUILD_TAG"

check_ecr_repo() {
    if aws ecr describe-repositories --repository-names ${repo_name} >/dev/null 2>&1; then
        log_info "ECR repository ${repo_name} exists."
        return 0
    else
        log_error "ECR repository ${repo_name} does not exist."
        return 1
    fi
}

region="$AWS_REGION"
aws_accountid="$AWS_ACCOUNT_ID"

ecr_repo_name="$aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"

log_info "Logging into ECR registry"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin "$aws_accountid.dkr.ecr.$region.amazonaws.com"

log_info "Current docker images before pull:"
docker images

# Check if repository exists before pulling
if ! check_ecr_repo ${repo_name}; then
    log_error "Cannot pull from non-existent repository. Exiting."
    exit 1
fi

log_info "Pulling image from ECR: $aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"
docker pull "$aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"

log_info "Current docker images after pull:"
docker images

log_info "ECR pull completed successfully"
log_info "Image available locally: $aws_accountid.dkr.ecr.$region.amazonaws.com/$repo_name:$repo_version"
