# ECR Deployment Scripts

Scripts for building and deploying the MariaDB MCP Server Docker image to AWS Elastic Container Registry (ECR).

## Configuration

The ECR scripts use `.env.dev` for deployment configuration, keeping it separate from your local runtime `.env` file.

### Setup

1. **Copy the example environment file:**
   ```bash
   cp .env.dev.example .env.dev
   ```

2. **Edit `.env.dev` with your AWS credentials:**
   ```bash
   # Required AWS credentials
   AWS_ACCESS_KEY_ID=your_access_key_id
   AWS_SECRET_ACCESS_KEY=your_secret_access_key
   AWS_REGION=us-east-1
   AWS_ACCOUNT_ID=123456789012

   # Docker image configuration
   LOCAL_IMAGE_NAME=mariadb-mcp-server
   REPO_NAME=mariadb-mcp-server
   BUILD_TAG=0.2.3
   ```

3. **Get your AWS Account ID:**
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

## Scripts

### ecr-publish.sh

Builds the Docker image and publishes it to AWS ECR.

**Usage:**
```bash
./scripts/ecr-publish.sh
```

**What it does:**
1. Loads environment variables from `.env.dev`
2. Validates AWS credentials and repository variables
3. Verifies project structure (Dockerfile, pyproject.toml, src/)
4. Builds multi-stage Docker image for linux/amd64
5. Authenticates with AWS ECR
6. Creates ECR repository if it doesn't exist
7. Tags and pushes the image to ECR

### ecr-pull.sh

Pulls the Docker image from AWS ECR to your local machine.

**Usage:**
```bash
./scripts/ecr-pull.sh
```

**What it does:**
1. Loads environment variables from `.env.dev`
2. Validates AWS credentials
3. Authenticates with AWS ECR
4. Checks if the ECR repository exists
5. Pulls the specified image version

## File Structure

```
.
├── .env                  # Local runtime configuration (database, etc.)
├── .env.dev              # Deployment configuration (AWS, Docker, etc.)
├── .env.dev.example      # Example deployment configuration
├── scripts/
│   ├── ecr-publish.sh    # Build and publish to ECR
│   ├── ecr-pull.sh       # Pull from ECR
│   └── README_ECR.md     # This file
```

## Why .env.dev?

- **Separation of concerns**: Local runtime config (`.env`) vs deployment config (`.env.dev`)
- **Security**: Keep AWS credentials separate from database credentials
- **Git safety**: `.env` is for local database config, `.env.dev` is for AWS deployment
- **Flexibility**: Different team members can have different AWS accounts without conflicts

## Security Best Practices

1. **Never commit `.env.dev`** with real credentials
2. Add `.env.dev` to `.gitignore`
3. Use AWS IAM roles when possible instead of access keys
4. Rotate credentials regularly
5. Use AWS Secrets Manager for production deployments

## Example Workflow

```bash
# 1. Setup your deployment config
cp .env.dev.example .env.dev
vim .env.dev  # Add your AWS credentials

# 2. Build and publish to ECR
./scripts/ecr-publish.sh

# 3. On another machine, pull the image
./scripts/ecr-pull.sh

# 4. Run the container
docker run -p 30003:30003 \
  -e DB_HOST=your-db-host \
  -e DB_USER=your_user \
  -e DB_PASSWORD=your_password \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/mariadb-mcp-server:0.2.3
```

## See Also

- [Main README](../README.md)
- [SERVER_BASEPATH Documentation](../docs/SERVER_BASEPATH.md)
