# Fedora Firewall Configuration for Container Services

## Problem

After successfully deploying containers with exposed ports (80/443), external connections fail with "Couldn't connect to server" errors, even though the services work locally on the host.

## Root Cause

Fedora Server enables `firewalld` by default with a restrictive configuration that only allows specific services (SSH, Cockpit, DHCPv6-client) through the firewall.

## Solution

Configure firewalld to allow HTTP and HTTPS traffic to reach your containerized services.

### Check Current Firewall Status

```bash
# Verify firewall is active
sudo firewall-cmd --state

# Check current configuration  
sudo firewall-cmd --list-all

# Check specifically what ports are open
sudo firewall-cmd --list-ports
sudo firewall-cmd --list-services
```

### Open Required Ports

```bash
# Method 1: Open specific ports (explicit)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp

# Method 2: Use predefined services (recommended)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Apply changes
sudo firewall-cmd --reload
```

### Verify Configuration

After reload, you should see:

```bash
sudo firewall-cmd --list-services
# Output: cockpit dhcpv6-client http https ssh

sudo firewall-cmd --list-ports  
# Output: 80/tcp 443/tcp
```

## Why Both Methods?

**Using both `--add-port` and `--add-service` provides redundancy:**

- **Services** (`http`/`https`) are semantic and automatically include standard ports
- **Explicit ports** (`80/tcp`/`443/tcp`) ensure the exact ports are open regardless of service definitions
- **Best practice:** Use services for standard protocols, explicit ports for custom applications

## Before and After

**Before (default FedoraServer):**
```
services: cockpit dhcpv6-client ssh
ports: (empty)
```

**After (web services enabled):**
```
services: cockpit dhcpv6-client http https ssh  
ports: 80/tcp 443/tcp
```

## Testing

From external machine:
```bash
# Should now work (replace with your server IP)
curl --resolve id.tickell.us:443:192.168.105.10 -k https://id.tickell.us/health
```

## Security Considerations

- **Only open required ports** - we opened 80/443 for web services
- **Keep SSH (22) open** for remote administration  
- **Cockpit remains available** for web-based server management
- **Consider IP restrictions** for production deployments using `--source` parameter

## Automation

For Infrastructure as Code deployments, include firewall rules in your provisioning:

```bash
#!/bin/bash
# Configure firewall for web services
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Common Mistakes

1. **Forgetting `--permanent`** - Changes lost on reboot
2. **Forgetting `--reload`** - Changes not active until reload
3. **Opening wrong interface** - Default zone usually correct for most setups
4. **SELinux confusion** - This is firewall (network), not SELinux (file access)

## Related Issues

- If services still don't work after firewall changes, check:
  - Container port bindings (`0.0.0.0:443:443` vs `127.0.0.1:443:443`)
  - SELinux contexts (separate issue)
  - Service binding addresses
  - DNS resolution