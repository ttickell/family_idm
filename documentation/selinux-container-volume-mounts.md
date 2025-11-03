# SELinux Container Volume Mount Configuration

## Problem Encountered

During deployment, containers were unable to read mounted configuration files and certificates, failing with "Permission denied" errors even though file permissions appeared correct (644, readable by all).

## Root Cause Analysis

**Issue:** SELinux (Security-Enhanced Linux) was blocking container access to host files due to security context mismatches.

**Evidence:**
```bash
# SELinux AVC (Access Vector Cache) denials in system logs
sudo journalctl | grep -i avc | grep -i denied
# Showed: container_t context trying to read user_home_t files
```

**Diagnosis Process:**
1. Verified file permissions were correct (644)
2. Confirmed user namespace mapping was working (`podman unshare ls -la`)
3. Tested that even root podman had same issue (ruled out rootless-specific problem)
4. Discovered bind mounts were failing systemically and being replaced with empty tmpfs mounts
5. Found SELinux AVC denials in system logs

## The Solution: SELinux Volume Mount Labels

### What We Implemented

Added `:z` flags to all volume mounts in docker-compose.yml:

```yaml
volumes:
  - ./config/Caddyfile:/etc/caddy/Caddyfile:ro,z
  - ./certs/id.tickell.us.crt:/etc/ssl/certs/id.tickell.us.crt:ro,z
  - ./certs/id.tickell.us.key:/etc/ssl/private/id.tickell.us.key:ro,z
```

### How SELinux Volume Labels Work

**`:z` (lowercase) - Shared Label:**
- Relabels the file/directory with a shared SELinux context
- Allows multiple containers to access the same file
- Changes context from `user_home_t` to `container_file_t` 
- Enables horizontal scaling (multiple container replicas can share files)

**`:Z` (uppercase) - Private Label:**
- Relabels with an exclusive SELinux context
- Only one specific container instance can access the file
- More restrictive security but prevents scaling

### Why This Solution

**Benefits of `:z` flag:**
1. **Cross-platform compatibility:** Ignored on non-SELinux systems, no side effects
2. **Future-proof:** Works whether SELinux is enabled or not
3. **Scaling-friendly:** Multiple container replicas can share the same config files
4. **Security compliant:** Maintains SELinux protections while enabling necessary access
5. **Industry standard:** Common practice in container deployments

**When SELinux is enabled:**
- Files get relabeled with appropriate container context
- Containers can read the files while maintaining security boundaries

**When SELinux is disabled:**
- Flag is ignored completely
- No performance impact or side effects

## Verification

**Before fix:**
```bash
# Failed with permission denied
podman run --rm -v /tmp/test.txt:/tmp/test.txt:ro docker.io/library/caddy:2-alpine cat /tmp/test.txt
```

**After fix:**
```bash
# Successful read
podman run --rm -v /tmp/test.txt:/tmp/test.txt:ro,z docker.io/library/caddy:2-alpine cat /tmp/test.txt
```

## Best Practices

1. **Always use `:z` for shared config files** - enables scaling and cross-platform compatibility
2. **Use `:Z` only for exclusive access scenarios** - when you need container-specific isolation
3. **Include SELinux labels in all production deployments** - prevents issues when moving between environments
4. **Test volume mounts on SELinux-enabled systems** - catch issues early in development

## References

- [Podman Volume Mount Documentation](https://docs.podman.io/en/latest/markdown/podman-run.1.html#volume-v-source-volume-host-dir-container-dir-options)
- [SELinux and Container Security](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/using_selinux/using-selinux-with-container-runtimes_using-selinux)