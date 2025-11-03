# TLS Certificate Hostname Mismatch Issue

## Problem Encountered

After successfully resolving SELinux volume mount issues, HTTPS connections to localhost fail with TLS handshake errors:

```
TLS connect error: error:0A000438:SSL routines::tlsv1 alert internal error
```

## Root Cause Analysis

**Issue:** Hostname mismatch between request and certificate configuration.

**Evidence:**
1. OpenSSL connection test shows "no peer certificate available"
2. Caddy logs show certificates loaded for specific domains:
   - `id.tickell.us`
   - `mdm.id.tickell.us` 
   - `scep.id.tickell.us`
3. Accessing via `localhost` but certificates are for `*.tickell.us` domains

**Caddy TLS Behavior:**
- Caddy only serves certificates for configured server names
- Accessing `localhost` doesn't match any configured domain
- No certificate is presented, causing TLS handshake failure

## The Problem

Our Caddyfile is configured for specific domains:

```
id.tickell.us {
    tls /etc/ssl/certs/id.tickell.us.crt /etc/ssl/private/id.tickell.us.key
    # ...
}

mdm.id.tickell.us {
    tls /etc/ssl/certs/id.tickell.us.crt /etc/ssl/private/id.tickell.us.key
    # ...
}
```

**But we're testing with:**
- `https://localhost/health` ❌
- `https://127.0.0.1/health` ❌

**Should be testing with:**
- `https://id.tickell.us/health` ✅
- `https://mdm.id.tickell.us/mdm/health` ✅

## Solutions

### Option 1: Add localhost to Caddyfile (Testing)
For local testing without DNS, add a localhost block:

```
localhost {
    tls internal
    reverse_proxy keycloak-main:8080
    respond /health 200
}
```

### Option 2: Use HTTP for testing
Test the reverse proxy functionality without TLS:

```bash
curl http://localhost/health
```

### Option 3: Set up local DNS resolution
Add entries to `/etc/hosts`:

```
127.0.0.1 id.tickell.us
127.0.0.1 mdm.id.tickell.us
127.0.0.1 scep.id.tickell.us
```

### Option 4: Test with proper domain names
Configure DNS properly and test with actual domain names.

## Next Steps

1. **Immediate testing:** Use HTTP or add localhost block
2. **Production setup:** Configure DNS resolution
3. **Long-term:** Remove localhost testing configuration before production deployment