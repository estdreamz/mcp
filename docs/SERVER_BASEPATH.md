# SERVER_BASEPATH Configuration Guide

The `SERVER_BASEPATH` environment variable allows you to configure the base path for HTTP and SSE transport modes in the MariaDB MCP Server.

## Overview

- **Environment Variable**: `SERVER_BASEPATH`
- **Default Value**: `""` (empty string)
- **Valid Values**: Any string (e.g., `""`, `/mcp`, `/api`, `/v1`)
- **Applies To**: HTTP and SSE transport modes only (not stdio)

## Configuration Methods

### Method 1: Using `.env` File (Recommended)

Add `SERVER_BASEPATH` to your `.env` file in the project root:

```bash
# .env
DB_HOST=your-db-host
DB_USER=your_user
DB_PASSWORD=your_password
DB_PORT=3306
DB_NAME=your_database
MCP_READ_ONLY=true
MCP_MAX_POOL_SIZE=10
SERVER_BASEPATH=
```

Then run the server:
```bash
uv run src/server.py --transport http --host 127.0.0.1 --port 30003
```

Server will be available at: `http://127.0.0.1:30003/`

### Method 2: Using Environment Variable

Set the environment variable when running the server:

```bash
SERVER_BASEPATH=/api uv run src/server.py --transport http --host 127.0.0.1 --port 30003
```

Server will be available at: `http://127.0.0.1:30003/api`

### Method 3: Using Command Line Argument

Override the environment variable with a command-line argument:

```bash
uv run src/server.py --transport http --host 127.0.0.1 --port 30003 --path /v1
```

Server will be available at: `http://127.0.0.1:30003/v1`

### Method 4: Docker Environment Variable

When running in Docker, set via `-e` flag:

```bash
docker run -p 30003:30003 \
  -e SERVER_BASEPATH=/api \
  -e DB_HOST=your-db-host \
  -e DB_USER=your_user \
  -e DB_PASSWORD=your_password \
  mariadb-mcp-server
```

Server will be available at: `http://localhost:30003/api`

### Method 5: Docker Compose

Set in your `docker-compose.yml`:

```yaml
services:
  mariadb-mcp:
    build: .
    ports:
      - "30003:30003"
    environment:
      SERVER_BASEPATH: /api
      DB_HOST: mariadb-server
      DB_USER: root
      DB_PASSWORD: password
      DB_NAME: your_database
```

Or use `env_file` to load from `.env`:

```yaml
services:
  mariadb-mcp:
    build: .
    ports:
      - "30003:30003"
    env_file: .env
```

## Common Use Cases

### Root Path (Default - Empty String)

**Configuration:**
```bash
SERVER_BASEPATH=
```

**Server URL:**
```
http://127.0.0.1:30003/
```

**VS Code MCP Config:**
```json
{
  "servers": {
    "mariadb-mcp-server": {
      "url": "http://127.0.0.1:30003/",
      "type": "streamable-http"
    }
  }
}
```

### Custom Path (`/mcp`)

**Configuration:**
```bash
SERVER_BASEPATH=/mcp
```

**Server URL:**
```
http://127.0.0.1:30003/mcp
```

**VS Code MCP Config:**
```json
{
  "servers": {
    "mariadb-mcp-server": {
      "url": "http://127.0.0.1:30003/mcp",
      "type": "streamable-http"
    }
  }
}
```

### Custom API Path

**Configuration:**
```bash
SERVER_BASEPATH=/api/v1
```

**Server URL:**
```
http://127.0.0.1:30003/api/v1
```

**VS Code MCP Config:**
```json
{
  "servers": {
    "mariadb-mcp-server": {
      "url": "http://127.0.0.1:30003/api/v1",
      "type": "streamable-http"
    }
  }
}
```

## Priority Order

Configuration values are applied in the following order (later values override earlier ones):

1. Default value in `config.py` (`""` - empty string)
2. `.env` file in project root
3. Environment variable at runtime
4. Command-line argument `--path`

## Examples

### Example 1: Development with default path (root)

```bash
# .env
SERVER_BASEPATH=

# Run server
uv run src/server.py --transport http --host 127.0.0.1 --port 30003

# Access at: http://127.0.0.1:30003/
```

### Example 2: Production with custom path

```bash
# .env
SERVER_BASEPATH=/api/mariadb/v1

# Run server
uv run src/server.py --transport http --host 0.0.0.0 --port 30003

# Access at: http://your-server:30003/api/mariadb/v1
```

### Example 3: Testing with different paths

```bash
# Test with /mcp
SERVER_BASEPATH=/mcp uv run src/server.py --transport http --port 30003

# Test with /api
SERVER_BASEPATH=/api uv run src/server.py --transport http --port 30003

# Test with root path
SERVER_BASEPATH="" uv run src/server.py --transport http --port 30003
```

### Example 4: Docker deployment with nginx reverse proxy

**Nginx config:**
```nginx
location /mariadb-mcp/ {
    proxy_pass http://mariadb-mcp-server:30003/mcp/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

**Docker run:**
```bash
docker run -d \
  --name mariadb-mcp-server \
  -e SERVER_BASEPATH=/mcp \
  -e DB_HOST=your-db \
  mariadb-mcp-server
```

## Verification

To verify the server is running with the correct path, check the logs:

```
Starting MCP server via http on 127.0.0.1:30003/mcp...
Server URL: http://127.0.0.1:30003/mcp
```

Or test with curl:

```bash
# For /mcp path
curl http://127.0.0.1:30003/mcp

# For custom path
curl http://127.0.0.1:30003/api/v1
```

## Troubleshooting

### Issue: Server returns 404

**Solution:** Check that your client is using the same path as configured in `SERVER_BASEPATH`.

**Example:**
```bash
# Server configured with:
SERVER_BASEPATH=/api

# Client must connect to:
http://127.0.0.1:30003/api  ✓
http://127.0.0.1:30003/mcp  ✗ (404 error)
```

### Issue: Path not updating

**Solution:** Ensure you've restarted the server after changing `SERVER_BASEPATH`.

### Issue: Empty path not working

**Solution:** Some MCP clients may require a path. Try using `/` instead of an empty string.

## See Also

- [Main README](../README.md)
- [Configuration Guide](../README.md#configuration--environment-variables)
- [ECR Deployment](../scripts/README_ECR.md)
