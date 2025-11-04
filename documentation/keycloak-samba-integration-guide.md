# Keycloak Samba Active Directory Integration Guide

## Overview

This document describes a complete family identity management system using Keycloak federated to Samba Active Directory with SPNEGO authentication for silent SSO. This setup provides enterprise-grade identity management with modern authentication flows while maintaining compatibility with legacy systems.

## Architecture

### Components
- **Keycloak 26.4.2** - Identity and Access Management
- **PostgreSQL 15** - Keycloak database backend
- **Caddy 2** - Reverse proxy with TLS termination
- **Samba AD 4.19.5** - Active Directory Domain Services
- **Internal CA** - Certificate trust infrastructure

### Network Configuration
- **External Access**: `id.tickell.us` (via Cloudflare)
- **Internal LDAPS**: `rio.home.tickell.us:636`, `donga.home.tickell.us:636`
- **Kerberos Realm**: `HOME.TICKELL.US`
- **AD Domain**: `home.tickell.us`

## Critical Prerequisites

### Domain Functional Level Requirements
⚠️ **CRITICAL**: Domain functional level **MUST** be 2016 or higher for AES encryption compatibility.

**Problem**: Default Samba AD installations use 2008 R2 functional level, which defaults to RC4 encryption. Modern Keycloak/Java requires AES encryption for security.

**Solution**: Upgrade domain functional level to 2016:
```bash
# Check current level
sudo samba-tool domain level show

# Upgrade to 2016 (enables AES by default)
sudo samba-tool domain level raise --domain-level=2016 --forest-level=2016
```

**Verification**:
```bash
# Verify AES encryption is default
sudo samba-tool domain passwordsettings show
# Should show: msDS-SupportedEncryptionTypes: 24 (AES256 + AES128)
```

### Certificate Trust Infrastructure
- Internal CA certificates must be trusted by all components
- Domain controllers require internal CA certificate installation
- Keycloak truststore must include internal CA certificate

## Keycloak Federation Configuration

### LDAP Federation with Integrated Kerberos

**Key Decision**: Use single LDAP federation with built-in Kerberos integration rather than separate LDAP + Kerberos federations. This eliminates federation conflicts and provides cleaner architecture.

#### LDAP Provider Settings
```
Provider: ldap
Name: Samba LDAP
Connection URL: ldaps://rio.home.tickell.us:636 ldaps://donga.home.tickell.us:636
Users DN: CN=Users,DC=home,DC=tickell,DC=us
Bind Type: simple
Bind DN: CN=keycloak-svc,CN=Users,DC=home,DC=tickell,DC=us
Username LDAP Attribute: userPrincipalName
RDN LDAP Attribute: cn
UUID LDAP Attribute: objectGUID
User Object Classes: person, organizationalPerson, user
Edit Mode: WRITABLE
```

#### Kerberos Integration Settings
```
Allow Kerberos Authentication: ON
Kerberos Realm: HOME.TICKELL.US
Server Principal: HTTP/id.tickell.us@HOME.TICKELL.US
Key Tab: /opt/keycloak/conf/keycloak.keytab
Kerberos Principal Attribute: userPrincipalName
Use Kerberos for Password Authentication: ON
Debug: ON (for troubleshooting)
```

### Service Account Permissions

The `keycloak-svc` account requires write permissions for self-service operations:

#### Active Directory Permissions
```bash
# Add to Account Operators group (provides user management permissions)
sudo samba-tool group addmembers "Account Operators" keycloak-svc

# Verify membership
sudo samba-tool group listmembers "Account Operators"
```

#### Keycloak Federation Mode
- **Edit Mode**: Must be set to `WRITABLE` for password changes and profile updates
- **Sync Registrations**: Enabled for user creation
- **Remove Invalid Users**: Enabled for cleanup

## Kerberos/SPNEGO Configuration

### Keytab Generation
The HTTP service principal keytab must support AES encryption:

```bash
# Generate keytab with AES encryption (requires domain FL 2016+)
sudo samba-tool spn add HTTP/id.tickell.us keycloak-svc
sudo samba-tool domain exportkeytab --principal=HTTP/id.tickell.us@HOME.TICKELL.US keycloak.keytab

# Verify AES keys are present
klist -e -k keycloak.keytab
# Should show: AES256-CTS-HMAC-SHA1-96, AES128-CTS-HMAC-SHA1-96
```

### File Permissions
The keycloak container user must be able to read the keytab:
```bash
# Container runs as UID 1000 (keycloak user)
sudo chown 1000:1000 keycloak.keytab
sudo chmod 600 keycloak.keytab
```

### Java Kerberos Configuration
Container requires krb5.conf configuration:
```
[libdefaults]
    default_realm = HOME.TICKELL.US
    default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96

[realms]
    HOME.TICKELL.US = {
        kdc = rio.home.tickell.us
        kdc = donga.home.tickell.us
        admin_server = rio.home.tickell.us
        default_domain = home.tickell.us
    }

[domain_realm]
    .home.tickell.us = HOME.TICKELL.US
    home.tickell.us = HOME.TICKELL.US
    .tickell.us = HOME.TICKELL.US
    tickell.us = HOME.TICKELL.US
```

## Authentication Flow Configuration

### Family Browser Flow
The authentication flow must include Kerberos as an ALTERNATIVE authenticator:

```
Steps:
1. Cookie (Alternative) - For existing sessions
2. Kerberos (Alternative) - For SPNEGO authentication  
3. Identity Provider Redirector (Alternative) - For external IdPs
4. Username Password Form (Required) - Fallback authentication
```

**Critical**: Kerberos authenticator will auto-disable if Kerberos federation is deleted. Re-enable it when using LDAP federation with Kerberos integration.

## Troubleshooting

### Common Issues

#### 1. "Cannot find key of appropriate type to decrypt AP-REQ"
**Cause**: Encryption type mismatch (RC4 vs AES)
**Solution**: 
- Upgrade domain functional level to 2016
- Regenerate keytab with AES keys
- Verify Java krb5.conf excludes RC4

#### 2. "Permission denied" reading keytab
**Cause**: Container user cannot read keytab file
**Solution**: Set proper ownership (uid 1000) and permissions (600)

#### 3. SPNEGO negotiation hangs
**Cause**: Normal SPNEGO process, browser waiting for server response
**Solution**: Force browser refresh to complete negotiation

#### 4. KDC lookup errors for wrong realm
**Cause**: Email addresses interpreted as Kerberos principals in wrong realm
**Solution**: Use LDAP federation only, avoid separate Kerberos federation

### Verification Commands

#### Check Kerberos tickets
```bash
# On client machine
klist
# Should show TGT and HTTP service ticket
```

#### Test LDAP connectivity
```bash
# Test LDAPS connection
openssl s_client -connect rio.home.tickell.us:636 -verify_return_error

# Test authentication
ldapsearch -H ldaps://rio.home.tickell.us:636 -D "CN=keycloak-svc,CN=Users,DC=home,DC=tickell,DC=us" -W -b "CN=Users,DC=home,DC=tickell,DC=us"
```

#### Check keytab validity
```bash
# List keytab contents with encryption types
klist -e -k keycloak.keytab

# Test authentication with keytab
kinit -k -t keycloak.keytab HTTP/id.tickell.us@HOME.TICKELL.US
```

## Security Considerations

### Encryption Standards
- **Kerberos**: AES256/AES128 only, RC4 disabled
- **LDAPS**: TLS 1.2+ with certificate validation
- **HTTP**: HTTPS only, no plaintext

### Service Account Security
- **Principle of Least Privilege**: keycloak-svc has minimal required permissions
- **Account Operators**: Limited to user management, not domain administration
- **Password Policy**: Strong password, regular rotation recommended

### Network Security
- **Internal CA**: All certificates signed by internal CA
- **Certificate Validation**: Strict certificate checking enabled
- **Split DNS**: External access via Cloudflare, internal resolution preserved

## Benefits of This Architecture

### Single Federation Design
- **Simplified Management**: One federation provider instead of multiple
- **Reduced Conflicts**: No federation priority conflicts
- **Clean Integration**: LDAP provider handles both user lookup and Kerberos auth

### Modern Security
- **AES Encryption**: Industry standard encryption throughout
- **Certificate Validation**: Full certificate chain validation
- **SPNEGO SSO**: Silent authentication for domain users

### Family-Friendly Features
- **Self-Service**: Users can manage their own profiles and passwords
- **Attribute Mapping**: Custom fields for family-relevant information
- **Fallback Authentication**: Username/password when SPNEGO unavailable

## Conclusion

This configuration provides enterprise-grade identity management suitable for family environments. The key success factors are:

1. **Domain Functional Level 2016+** for AES encryption compatibility
2. **Single LDAP Federation** with integrated Kerberos support
3. **Proper Service Account Permissions** for write operations
4. **Correct Authentication Flow** with Kerberos as ALTERNATIVE

The result is a robust, secure identity system with silent SSO for domain-joined devices and fallback authentication for guest access.