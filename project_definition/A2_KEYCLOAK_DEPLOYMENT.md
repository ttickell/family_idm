# A2. Keycloak @ `https://id.tickell.us` - Deployment Checklist

## Overview
Deploy Keycloak on Podman with Caddy reverse proxy, integrate with Samba AD via LDAP, and enable Kerberos SPNEGO for silent internal authentication.

**Target URL:** `https://id.tickell.us`  
**Host:** `idealx.home.tickell.us`  
**Backend:** PostgreSQL + Keycloak containers via Podman

---

## 🏗️ **Step 1: Infrastructure Setup**

### 1.1 Podman Network & Storage
- [ ] Create dedicated podman network: `podman network create keycloak-net`
- [ ] Create persistent volumes:
  - [ ] `podman volume create keycloak-postgres-data`
  - [ ] `podman volume create keycloak-data`
  - [ ] `podman volume create caddy-data`
  - [ ] `podman volume create caddy-config`

### 1.2 PostgreSQL Database
- [ ] Deploy PostgreSQL container with proper environment
- [ ] Verify database connectivity and create Keycloak database
- [ ] Test database persistence across container restarts

---

## 🌐 **Step 2: Caddy Reverse Proxy**

### 2.1 Caddy Container Setup
- [ ] Create Caddyfile configuration for `id.tickell.us`
- [ ] Deploy Caddy container with volume mounts
- [ ] Configure automatic HTTPS with Let's Encrypt

### 2.2 Internal DNS & Routing
- [ ] Verify split-DNS resolution: `dig id.tickell.us @rio.home.tickell.us`
- [ ] Test internal HTTP access to Caddy
- [ ] Confirm proxy_protocol and real IP forwarding

---

## 🔐 **Step 3: Keycloak Container**

### 3.1 Initial Deployment
- [ ] Deploy Keycloak container with PostgreSQL backend
- [ ] Set initial admin credentials securely
- [ ] Verify Keycloak starts and connects to database

### 3.2 Basic Configuration
- [ ] Access admin console at `https://id.tickell.us/admin`
- [ ] Configure hostname settings and proxy headers
- [ ] Set up proper logging and monitoring

---

## ☁️ **Step 4: Cloudflare Integration**

### 4.1 DNS Configuration
- [ ] Add DNS A record: `id.tickell.us` → `idealx` public IP
- [ ] Verify external DNS resolution
- [ ] Test external HTTPS access

### 4.2 Cloudflare Settings
- [ ] Enable Proxy (orange cloud) for `id.tickell.us`
- [ ] Set Cache Level: BYPASS for all requests
- [ ] Disable Rocket Loader and Auto Minify
- [ ] Configure SSL/TLS: Full (strict) mode

---

## 🏰 **Step 5: Realm Configuration**

### 5.1 Create Tickell Realm
- [ ] Create new realm: `tickell`
- [ ] Set realm display name and email configuration
- [ ] Configure default locale and timezone

### 5.2 Realm Settings
- [ ] **Login Settings:**
  - [ ] Email as username: ON
  - [ ] User registration: OFF
  - [ ] Edit username: OFF
  - [ ] Forgot password: ON
- [ ] **Security Defenses:**
  - [ ] Brute force detection: ON
  - [ ] X-Frame-Options: SAMEORIGIN
- [ ] **Sessions:**
  - [ ] SSO Session Idle: 30 minutes
  - [ ] SSO Session Max: 10 hours

---

## 🔗 **Step 6: Samba LDAP Integration**

### 6.1 LDAP Provider Setup
- [ ] Create LDAP user federation provider
- [ ] Configure connection: `ldaps://rio.home.tickell.us:636`
- [ ] Set up bind DN: `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`
- [ ] Configure user search base: `CN=Users,DC=home,DC=tickell,DC=us`

### 6.2 LDAP Mappings
- [ ] Map username to `sAMAccountName`
- [ ] Map email to `mail` attribute
- [ ] Map first/last name to `givenName`/`sn`
- [ ] Set import mode: READ_ONLY

### 6.3 User Synchronization
- [ ] Test LDAP connection and authentication
- [ ] Perform initial user import/sync
- [ ] Verify user attributes are properly mapped

---

## 🎫 **Step 7: Kerberos SPNEGO Setup**

### 7.1 Service Principal Name (SPN)
- [ ] Connect to Samba AD controller (`rio` or `donga`)
- [ ] Create SPN: `setspn -A HTTP/id.tickell.us IDEALX$`
- [ ] Verify SPN creation: `setspn -L IDEALX$`

### 7.2 Keytab Generation
- [ ] Generate keytab on AD controller:
  ```bash
  ktpass -out keycloak.keytab -princ HTTP/id.tickell.us@HOME.TICKELL.US \
         -mapUser IDEALX$ -pass * -pType KRB5_NT_PRINCIPAL
  ```
- [ ] Securely transfer keytab to `idealx` host
- [ ] Test keytab: `kinit -kt keycloak.keytab HTTP/id.tickell.us@HOME.TICKELL.US`

### 7.3 Keycloak Kerberos Configuration
- [ ] Upload keytab to Keycloak admin console
- [ ] Configure Kerberos authenticator:
  - [ ] Kerberos realm: `HOME.TICKELL.US`
  - [ ] Server principal: `HTTP/id.tickell.us@HOME.TICKELL.US`
  - [ ] Keytab path: `/opt/keycloak/conf/keycloak.keytab`
- [ ] Add Kerberos to browser authentication flow

---

## 🖥️ **Step 8: Browser SPNEGO Configuration**

### 8.1 Internal Browser Configuration
- [ ] **Safari:** Add `id.tickell.us` to Kerberos trusted sites
- [ ] **Chrome:** Configure `--auth-server-whitelist=id.tickell.us`
- [ ] **Firefox:** Set `network.negotiate-auth.trusted-uris` to `id.tickell.us`

### 8.2 Authentication Flow Testing
- [ ] Test internal access (should be silent with Kerberos)
- [ ] Test external access (should prompt for username/password)
- [ ] Verify fallback to form-based auth when Kerberos fails

---

## ✅ **Definition of Done (A2)**

- [ ] **Internal Login is Silent:** Users on domain-joined devices access `https://id.tickell.us` without credential prompt
- [ ] **External Login Works:** External users can authenticate with username/password at `https://id.tickell.us`
- [ ] **LDAP Integration:** All Samba AD users can authenticate through Keycloak
- [ ] **Split-DNS Functional:** `id.tickell.us` resolves correctly both internally and externally
- [ ] **No hostname confusion:** No references to `id.home.tickell.us` anywhere
- [ ] **Admin Access:** Keycloak admin console accessible and secured
- [ ] **Logging & Monitoring:** Basic logging configured for troubleshooting

---

## 📝 **Notes & References**

### Key Configuration Values
- **Realm:** `tickell`
- **SPN:** `HTTP/id.tickell.us@HOME.TICKELL.US`
- **LDAP Base:** `CN=Users,DC=home,DC=tickell,DC=us`
- **Kerberos Realm:** `HOME.TICKELL.US`
- **Domain Controllers:** `rio.home.tickell.us`, `donga.home.tickell.us`

### Troubleshooting Commands
```bash
# Test DNS resolution
dig id.tickell.us @rio.home.tickell.us

# Test Kerberos ticket
klist -v

# Check LDAP connectivity
ldapsearch -H ldaps://rio.home.tickell.us:636 -D "CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us" -W

# Test HTTP access
curl -I https://id.tickell.us
```

### Container Management
```bash
# View all Keycloak containers
podman ps -a --filter label=app=keycloak

# Check container logs
podman logs keycloak-main
podman logs caddy-proxy

# Restart services
podman restart keycloak-main caddy-proxy postgres-db
```