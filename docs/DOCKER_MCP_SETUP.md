# Docker MCP WSL Integration Setup Guide

## Overview

### What is Docker MCP?

Docker MCP (Model Context Protocol) is a standardized protocol that enables communication between AI development tools (like Claude Desktop) and Docker environments. It allows AI assistants to interact with Docker containers, images, and the Docker daemon directly through a well-defined API.

**Why it's useful:**
- Seamless container management from your AI assistant
- Real-time Docker operations without manual CLI commands
- Consistent interface across different development environments
- Enhanced automation capabilities for containerized workflows

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Windows Host                             │
│                                                              │
│  ┌────────────────────────────────────┐                     │
│  │    Docker Desktop v4.54.0+         │                     │
│  │    (WSL2 Backend Enabled)          │                     │
│  └──────────────┬─────────────────────┘                     │
│                 │                                            │
│                 │ WSL Integration                            │
│                 ▼                                            │
│  ┌─────────────────────────────────────────────────┐        │
│  │              WSL2 Ubuntu-22.04                  │        │
│  │                                                 │        │
│  │  ┌──────────────────────────────────────────┐  │        │
│  │  │   /var/run/docker.sock (Unix Socket)    │  │        │
│  │  └──────────────┬───────────────────────────┘  │        │
│  │                 │                               │        │
│  │                 ▼                               │        │
│  │  ┌──────────────────────────────────────────┐  │        │
│  │  │   MCP Gateway (docker mcp gateway run)  │  │        │
│  │  └──────────────┬───────────────────────────┘  │        │
│  │                 │                               │        │
│  │                 ▼                               │        │
│  │  ┌──────────────────────────────────────────┐  │        │
│  │  │   Your Project (/home/docker/MOM)       │  │        │
│  │  │   .mcp.json configuration                │  │        │
│  │  └──────────────────────────────────────────┘  │        │
│  └─────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Docker Desktop Requirements

| Requirement | Minimum Version | Recommended |
|-------------|----------------|-------------|
| Docker Desktop | 4.50.0+ | 4.54.0+ |
| WSL2 Backend | Enabled | Enabled |
| Docker MCP Gateway | Built-in | Latest |

### WSL2 Configuration Requirements

1. **WSL2 must be installed and configured:**
   ```bash
   wsl --version
   # Should show WSL version 2.x.x or higher
   ```

2. **Ubuntu or compatible distribution:**
   ```bash
   wsl -l -v
   # Should show Ubuntu-22.04 or similar with VERSION 2
   ```

3. **Docker Desktop WSL Integration enabled:**
   - Open Docker Desktop Settings
   - Navigate to Resources → WSL Integration
   - Enable integration for your Ubuntu distribution

### Required Permissions

Your WSL user must be a member of the `docker` group:

```bash
# Check current group membership
groups

# Add user to docker group if not present
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker

# Verify docker access without sudo
docker ps
```

## Configuration Explanation

### The `.mcp.json` Docker Entry

Here's the typical Docker MCP configuration for WSL environments:

```json
{
  "docker": {
    "command": "docker",
    "args": [
      "mcp",
      "gateway",
      "run",
      "/var/run/docker.sock"
    ]
  }
}
```

### Breaking Down the Configuration

| Field | Value | Explanation |
|-------|-------|-------------|
| `command` | `"docker"` | The Docker CLI executable available in WSL |
| `args[0-2]` | `["mcp", "gateway", "run"]` | Docker's built-in MCP gateway subcommand |
| `args[3]` | `"/var/run/docker.sock"` | Unix socket path for Docker daemon in WSL |

**Key Points:**

- **No Windows paths needed**: The socket path is WSL-native (`/var/run/docker.sock`)
- **No `npx` or Node.js required**: Uses Docker's built-in MCP gateway
- **Environment variables**: Not needed for basic WSL setup
- **Socket access**: Direct Unix socket communication (fastest method)

### Why Windows Paths Are NOT Needed

❌ **Don't use:**
```json
{
  "docker": {
    "command": "npx",
    "args": ["-y", "@docker/mcp-server"],
    "env": {
      "DOCKER_HOST": "npipe:////./pipe/docker_engine"  // Windows-specific
    }
  }
}
```

✅ **Use instead:**
```json
{
  "docker": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "/var/run/docker.sock"]
  }
}
```

**Reason:** When running in WSL, you're in a Linux environment. Docker Desktop's WSL integration makes the Docker daemon accessible via the standard Unix socket, so Windows named pipes are unnecessary and won't work.

## Verification Commands

### Pre-Flight Checks

Before configuring MCP, verify your environment:

#### 1. Check Docker Socket Access

```bash
ls -la /var/run/docker.sock
```

**Expected output:**
```
srw-rw---- 1 root docker 0 Dec  7 12:00 /var/run/docker.sock
```

#### 2. Verify Docker CLI Availability

```bash
which docker
docker --version
```

**Expected output:**
```
/usr/bin/docker
Docker version 24.0.7, build afdd53b
```

#### 3. Test Docker Connection

```bash
docker ps
```

**Expected output:**
```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Or your current running containers (should NOT error).

#### 4. Check MCP Gateway Availability

```bash
docker mcp gateway --help
```

**Expected output:**
```
Run the MCP gateway

Usage: docker mcp gateway run [OPTIONS] <SOCKET>
...
```

### Post-Configuration Verification

After adding the Docker MCP entry to `.mcp.json`:

#### 1. Restart Your IDE/Client

Close and reopen your application (Claude Desktop, VS Code, etc.) to load the new MCP configuration.

#### 2. Check MCP Connection (if available in your client)

Some clients provide MCP status indicators or logs. Check your client's documentation for MCP connection verification.

#### 3. Test Basic Docker Operations

Through your AI assistant, try commands like:
- "List all Docker containers"
- "Show Docker images"
- "Check Docker system info"

### Testing MCP Communication Manually

```bash
# Run the MCP gateway directly to test
docker mcp gateway run /var/run/docker.sock

# In another terminal, send a test MCP request (if you have an MCP client)
# This is advanced - typically your IDE/AI client handles this
```

## Troubleshooting Guide

### Issue 1: "docker: command not found" in WSL

**Symptoms:**
```bash
$ docker ps
bash: docker: command not found
```

**Solution:**

1. **Enable WSL integration in Docker Desktop:**
   - Open Docker Desktop on Windows
   - Go to Settings → Resources → WSL Integration
   - Toggle on your Ubuntu distribution
   - Click "Apply & Restart"

2. **Verify Docker is running:**
   - Ensure Docker Desktop is running on Windows
   - Check system tray for Docker icon

3. **Reinstall Docker CLI (if needed):**
   ```bash
   # Update package lists
   sudo apt-get update
   
   # Install Docker CLI
   sudo apt-get install docker.io
   ```

### Issue 2: Permission Denied on Docker Socket

**Symptoms:**
```bash
$ docker ps
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**

1. **Add your user to the docker group:**
   ```bash
   sudo usermod -aG docker $USER
   ```

2. **Apply the group change:**
   ```bash
   # Option A: Log out and log back in to WSL
   exit
   # Then reconnect to WSL
   
   # Option B: Use newgrp (temporary for current session)
   newgrp docker
   ```

3. **Verify permissions:**
   ```bash
   groups
   # Should include 'docker'
   
   docker ps
   # Should work without sudo
   ```

### Issue 3: MCP Gateway Command Not Found

**Symptoms:**
```bash
$ docker mcp gateway --help
docker: 'mcp' is not a docker command.
```

**Solution:**

1. **Update Docker Desktop:**
   - Ensure you have Docker Desktop 4.50.0 or later
   - The MCP gateway is a built-in feature in recent versions
   - Download latest from: https://www.docker.com/products/docker-desktop/

2. **Alternative: Use npm-based MCP server:**
   If you can't update Docker Desktop, use the npm package:
   ```json
   {
     "docker": {
       "command": "npx",
       "args": ["-y", "@docker/mcp-server"],
       "env": {
         "DOCKER_HOST": "unix:///var/run/docker.sock"
       }
     }
   }
   ```

### Issue 4: Connection Timeout/Refused Errors

**Symptoms:**
- MCP operations timeout
- "Connection refused" errors
- No response from Docker daemon

**Solution:**

1. **Verify Docker daemon is running:**
   ```bash
   docker info
   ```
   If this fails, Docker daemon is not accessible.

2. **Check Docker Desktop status:**
   - Open Docker Desktop on Windows
   - Ensure it shows "Running" status
   - Check for error messages in Docker Desktop

3. **Restart Docker Desktop:**
   - Right-click Docker Desktop system tray icon
   - Select "Restart"
   - Wait for complete restart

4. **Check WSL integration:**
   ```bash
   # In WSL, verify socket exists
   ls -la /var/run/docker.sock
   
   # Test basic Docker command
   docker version
   ```

### Issue 5: Docker Desktop Not Running

**Symptoms:**
- Docker commands fail entirely
- `/var/run/docker.sock` not found
- "Cannot connect to Docker daemon" errors

**Solution:**

1. **Start Docker Desktop:**
   - Launch Docker Desktop from Windows Start menu
   - Wait for initialization (check system tray icon)

2. **Set Docker Desktop to start on login (optional):**
   - Docker Desktop Settings → General
   - Enable "Start Docker Desktop when you log in"

3. **Verify Docker is running:**
   ```bash
   docker version
   docker ps
   ```

### Issue 6: WSL Integration Not Enabled in Docker Desktop

**Symptoms:**
- Docker CLI not available in WSL
- Commands work in PowerShell but not in WSL

**Solution:**

1. **Enable WSL integration:**
   - Open Docker Desktop
   - Navigate to Settings → Resources → WSL Integration
   - Enable "Enable integration with my default WSL distro"
   - Toggle on your specific distribution (e.g., Ubuntu-22.04)
   - Click "Apply & Restart"

2. **Wait for WSL to update:**
   - Close all WSL terminals
   - Wait 10-15 seconds
   - Open new WSL terminal

3. **Verify integration:**
   ```bash
   which docker
   # Should show: /usr/bin/docker or /mnt/c/Program Files/Docker/Docker/resources/bin/docker
   
   docker --version
   # Should show version matching Docker Desktop
   ```

## Common Pitfalls

### 1. Path Translation Mistakes

❌ **Wrong:** Mixing Windows and WSL paths
```json
{
  "docker": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "//./pipe/docker_engine"]
  }
}
```

✅ **Correct:** Use WSL-native paths
```json
{
  "docker": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "/var/run/docker.sock"]
  }
}
```

### 2. Using Windows Environment Variables in WSL

❌ **Wrong:** Windows-style DOCKER_HOST
```json
{
  "docker": {
    "env": {
      "DOCKER_HOST": "npipe:////./pipe/docker_engine"
    }
  }
}
```

✅ **Correct:** WSL-style or omit entirely
```json
{
  "docker": {
    "env": {
      "DOCKER_HOST": "unix:///var/run/docker.sock"
    }
  }
}
```

Or better yet, omit the `env` entirely when using the socket directly.

### 3. Docker Context Issues

**Problem:** Multiple Docker contexts causing confusion

```bash
# Check current context
docker context ls

# Should show 'default' as active with unix:// socket
```

**Solution:** Switch to default context
```bash
docker context use default
```

### 4. Socket vs Named Pipe Confusion

| Environment | Socket Type | Path |
|-------------|-------------|------|
| **Native Windows** | Named Pipe | `npipe:////./pipe/docker_engine` |
| **WSL2** | Unix Socket | `/var/run/docker.sock` |
| **Native Linux** | Unix Socket | `/var/run/docker.sock` |

**Key Rule:** If you're running commands in WSL, use the Unix socket path. The WSL integration handles the bridge to Docker Desktop automatically.

## Advanced Configuration

### Using Custom Docker Contexts

If you need to connect to a remote Docker daemon or use a custom context:

```json
{
  "docker": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "/var/run/docker.sock"],
    "env": {
      "DOCKER_CONTEXT": "remote-server"
    }
  }
}
```

First, create the context:
```bash
docker context create remote-server --docker "host=ssh://user@remote-server"
docker context use remote-server
```

### Alternative: npm-based Docker MCP Server

If you prefer or need to use the npm package instead of the built-in gateway:

#### Installation

```bash
# Global installation
npm install -g @docker/mcp-server

# Or use npx (no installation needed)
```

#### Configuration

```json
{
  "docker": {
    "command": "npx",
    "args": ["-y", "@docker/mcp-server"],
    "env": {
      "DOCKER_HOST": "unix:///var/run/docker.sock"
    }
  }
}
```

#### When to Use npm Package

- You need features not yet in the built-in gateway
- You're using an older Docker Desktop version
- You want to customize the MCP server behavior
- You're developing MCP extensions

### Debugging MCP Communication

Enable detailed MCP logging for troubleshooting:

```json
{
  "docker": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "/var/run/docker.sock"],
    "env": {
      "DEBUG_MCP": "1",
      "MCP_LOG_LEVEL": "debug"
    }
  }
}
```

**Check logs:**
- Location varies by client (Claude Desktop, VS Code, etc.)
- Look for MCP-related log files in your application's log directory
- Check system logs: `journalctl -f` (Linux/WSL)

**Common log locations:**
```bash
# Claude Desktop logs (WSL)
~/.config/Claude/logs/

# VS Code logs
~/.vscode/logs/

# System logs
journalctl -fu docker
```

### Performance Tuning

For optimal performance in WSL:

1. **Use the Unix socket directly** (fastest)
   ```json
   {
     "docker": {
       "command": "docker",
       "args": ["mcp", "gateway", "run", "/var/run/docker.sock"]
     }
   }
   ```

2. **Place project files in WSL filesystem** (not `/mnt/c/`)
   - Faster file I/O
   - Better Docker volume performance
   - Recommended: `/home/docker/projects/`

3. **Allocate sufficient resources to WSL:**
   - Create/edit `C:\Users\YourName\.wslconfig`
   ```ini
   [wsl2]
   memory=8GB
   processors=4
   ```

4. **Keep Docker Desktop updated:**
   - Performance improvements in each release
   - Better WSL integration over time

---

## Summary

This guide covered the complete setup and troubleshooting for Docker MCP integration in WSL environments. Key takeaways:

- ✅ Use Unix socket paths, not Windows named pipes
- ✅ Ensure WSL integration is enabled in Docker Desktop
- ✅ Add your user to the docker group
- ✅ Use the built-in MCP gateway when possible
- ✅ Keep Docker Desktop updated for best compatibility

For additional help, consult:
- [Docker Desktop WSL Documentation](https://docs.docker.com/desktop/wsl/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- Docker Desktop Settings → About → (click version number for diagnostics)