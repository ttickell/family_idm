# A2. Keycloak @ `https://id.tickell.us` - Deployment with Podman-Compose

## Overview
Deploy Keycloak stack using `podman-compose` with declarative YAML configuration. This approach better prepares for Phase 2 GitOps migration and provides reproducible infrastructure-as-code.

**Target URL:** `https://id.tickell.us`  
**Host:** `idealx.home.tickell.us`  
**Stack:** PostgreSQL + Keycloak + Caddy via podman-compose

---

## 🏗️ **Step 1: Podman-Compose Setup**

### 1.1 Install podman-compose
- [ ] Install podman-compose: `pip3 install podman-compose` or package manager
- [ ] Verify installation: `podman-compose --version`
- [ ] Create project directory: `mkdir -p ~/keycloak-stack && cd ~/keycloak-stack`

### 1.2 Create Docker Compose Configuration
- [ ] Create `docker-compose.yml` with PostgreSQL, Keycloak, and Caddy services
- [ ] Create `.env` file for sensitive environment variables
- [ ] Create `config/` directory for service configurations

**🔧 docker-compose.yml:**
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: keycloak-postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${KC_DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - keycloak-net
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak-main
    depends_on:
      - postgres
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KC_DB_PASSWORD}
      KC_HOSTNAME: id.tickell.us
      KC_HOSTNAME_STRICT: false
      KC_PROXY: edge
      KEYCLOAK_ADMIN: ${KC_ADMIN_USER}
      KEYCLOAK_ADMIN_PASSWORD: ${KC_ADMIN_PASSWORD}
    command: ["start"]
    volumes:
      - keycloak-data:/opt/keycloak/data
      - ./config/keycloak:/opt/keycloak/conf
    networks:
      - keycloak-net
    restart: unless-stopped

  caddy:
    image: caddy:2-alpine
    container_name: caddy-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs/id.tickell.us.crt:/etc/ssl/certs/id.tickell.us.crt:ro
      - ./certs/id.tickell.us.key:/etc/ssl/private/id.tickell.us.key:ro
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - keycloak-net
    restart: unless-stopped

volumes:
  postgres-data:
  keycloak-data:
  caddy-data:
  caddy-config:

networks:
  keycloak-net:
    driver: bridge
```

**🔧 .env file:**
```bash
# Database credentials
KC_DB_PASSWORD=your-secure-db-password

# Keycloak admin credentials
KC_ADMIN_USER=admin
KC_ADMIN_PASSWORD=your-secure-admin-password
```

---

## 🌐 **Step 2: Internal CA Certificate & Caddy Configuration**

### 2.1 Generate Internal CA Certificate
- [ ] Request certificate for `id.tickell.us` from your internal CA
- [ ] Ensure certificate includes SAN (Subject Alternative Name) for `id.tickell.us`
- [ ] Copy certificate files to project: `cp id.tickell.us.crt ~/keycloak-stack/certs/`
- [ ] Copy private key: `cp id.tickell.us.key ~/keycloak-stack/certs/`
- [ ] Set proper permissions: `chmod 600 ~/keycloak-stack/certs/id.tickell.us.key`

### 2.2 Create Caddyfile with Internal TLS
- [ ] Create `config/Caddyfile` with internal CA certificate configuration
- [ ] Configure reverse proxy settings for Keycloak
- [ ] Set up proper headers and security configuration

**🔧 config/Caddyfile:**
```
id.tickell.us {
    # Use internal CA certificate
    tls /etc/ssl/certs/id.tickell.us.crt /etc/ssl/private/id.tickell.us.key
    
    reverse_proxy keycloak-main:8080 {
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Real-IP {remote}
    }
    
    # Security headers
    header {
        X-Frame-Options SAMEORIGIN
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
        X-XSS-Protection "1; mode=block"
    }
    
    # Logging for troubleshooting
    log {
        output file /data/logs/access.log
        format json {
            time_format "2006-01-02T15:04:05Z07:00"
            message_key "msg"
        }
        level INFO
    }
    
    # Health check endpoint
    respond /health 200
}
```

### 2.3 Create Certificate Directory Structure
- [ ] Create certificate directory: `mkdir -p ~/keycloak-stack/certs`
- [ ] Verify certificate files are present and readable
- [ ] Test certificate validity: `openssl x509 -in certs/id.tickell.us.crt -text -noout`

---

## ☁️ **Step 3: Cloudflare DNS Setup**

### 3.1 DNS Configuration
- [ ] Add DNS A record: `id.tickell.us` → `idealx` public IP in Cloudflare
- [ ] Verify external DNS resolution: `dig id.tickell.us @8.8.8.8`

### 4.2 Cloudflare Settings
- [ ] Enable Proxy (orange cloud) for `id.tickell.us`
- [ ] SSL/TLS: **Full (strict)** mode (required for internal CA)
- [ ] Cache Level: BYPASS for all requests
- [ ] Disable Auto Minify and Rocket Loader
- [ ] Security Level: Medium
- [ ] **Important:** Cloudflare must trust your internal CA for Full (strict) mode

---

## 🚀 **Step 4: Deploy Stack**

### 4.1 Initial Deployment
- [ ] Ensure certificate files are in place: `ls -la certs/id.tickell.us.*`
- [ ] Deploy stack: `podman-compose up -d`
- [ ] Check all containers running: `podman-compose ps`
- [ ] View logs: `podman-compose logs -f`

### 4.2 Verify Services
- [ ] Test database: `podman-compose exec postgres psql -U keycloak -d keycloak -c '\l'`
- [ ] Test Keycloak startup: `podman-compose logs keycloak | grep "Keycloak.*started"`
- [ ] Test Caddy TLS: `curl -I https://id.tickell.us/health` (should return 200)
- [ ] Verify certificate: `openssl s_client -connect id.tickell.us:443 -servername id.tickell.us`

### 4.3 Access Admin Console
- [ ] Access `https://id.tickell.us/admin` externally
- [ ] Login with admin credentials from `.env` file
- [ ] Verify admin console loads properly

---

## 🏰 **Step 5: Realm Configuration**

### 5.1 Create Tickell Realm
- [ ] Create new realm: `tickell` via admin console
- [ ] Configure realm settings:
  - [ ] Display name: "Tickell Family"
  - [ ] Email as username: ON
  - [ ] User registration: OFF
  - [ ] Edit username: OFF
  - [ ] Remember me: ON

### 5.2 Security Settings
- [ ] **Brute Force Detection:** Enable with max 5 failures
- [ ] **Password Policy:** Minimum 8 chars, 1 digit, 1 special char
- [ ] **Sessions:**
  - [ ] SSO Session Idle: 30 minutes
  - [ ] SSO Session Max: 10 hours
  - [ ] Client Session Idle: 30 minutes

---

## 🔗 **Step 6: Samba LDAP Integration**

### 6.1 Create LDAP User Federation
- [ ] Navigate to User Federation → Add provider → LDAP
- [ ] Configure connection settings:
  - [ ] Edit Mode: READ_ONLY
  - [ ] Vendor: Active Directory
  - [ ] Connection URL: `ldaps://rio.home.tickell.us:636`
  - [ ] Users DN: `CN=Users,DC=home,DC=tickell,DC=us`
  - [ ] Bind Type: simple
  - [ ] Bind DN: `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`
  - [ ] Bind Credential: [password for bind account]

### 6.2 LDAP Mappers Configuration
- [ ] **Username:** sAMAccountName
- [ ] **Email:** mail
- [ ] **First Name:** givenName
- [ ] **Last Name:** sn
- [ ] **Full Name:** cn

### 6.3 User Synchronization
- [ ] Test LDAP connection and authentication
- [ ] Perform initial user import/sync: Synchronize all users
- [ ] Verify user attributes are properly mapped
- [ ] Test user login with LDAP credentials

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
- [ ] Copy keytab to compose stack: `cp keycloak.keytab ~/keycloak-stack/config/keycloak/`
- [ ] Test keytab: `kinit -kt keycloak.keytab HTTP/id.tickell.us@HOME.TICKELL.US`

### 7.3 Keycloak Kerberos Configuration
- [ ] Navigate to Authentication → Browser flow → Add execution
- [ ] Add Kerberos authenticator to browser flow
- [ ] Configure Kerberos authenticator:
  - [ ] Kerberos realm: `HOME.TICKELL.US`
  - [ ] Server principal: `HTTP/id.tickell.us@HOME.TICKELL.US`
  - [ ] Keytab: `/opt/keycloak/conf/keycloak.keytab`
  - [ ] Debug: ON (initially)
- [ ] Set execution as ALTERNATIVE (fallback to username/password)

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
- [ ] Test with different browsers and devices

---

## ✅ **Definition of Done (A2)**

- [ ] **Internal Login is Silent:** Users on domain-joined devices access `https://id.tickell.us` without credential prompt
- [ ] **External Login Works:** External users can authenticate with username/password at `https://id.tickell.us`
- [ ] **LDAP Integration:** All Samba AD users can authenticate through Keycloak
- [ ] **Split-DNS Functional:** `id.tickell.us` resolves correctly both internally and externally
- [ ] **No hostname confusion:** No references to `id.home.tickell.us` anywhere
- [ ] **Admin Access:** Keycloak admin console accessible and secured
- [ ] **Stack Reproducible:** `podman-compose down && podman-compose up -d` works reliably
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

# Test HTTPS access with internal CA
curl -I https://id.tickell.us

# Verify certificate chain
openssl s_client -connect id.tickell.us:443 -servername id.tickell.us -showcerts

# Test certificate validity
openssl x509 -in certs/id.tickell.us.crt -text -noout | grep -A2 "Subject Alternative Name"
```

### Podman-Compose Management
```bash
# View all services
podman-compose ps

# Check service logs
podman-compose logs keycloak
podman-compose logs caddy
podman-compose logs postgres

# Restart specific service
podman-compose restart keycloak

# Full stack restart
podman-compose restart

# Update and redeploy
podman-compose pull
podman-compose up -d

# Clean shutdown
podman-compose down

# Clean shutdown with volume removal (DESTRUCTIVE)
podman-compose down -v
```