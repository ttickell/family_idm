# Family Identity & Device Management Plan — Samba + Keycloak + MDM + Entra Integration (Cloudflare Enabled)

**Audience:** 5-person family; Apple-first with some Windows PCs.

**Goal:** Build a self-hosted identity foundation (Samba AD + Keycloak) with MDM for device management, protected behind Cloudflare’s WAF for public access, and extended into Entra ID for cloud-linked SSO — while retaining local Kerberos SSO inside the LAN.

**Confidence levels:** Each section includes confidence estimates (High / Medium / Low).

---

## Phase 0 — Overview & Architecture

**Core stack:**
- **Samba AD** — local directory, Kerberos realm `HOME.TICKELL.US`, DNS `home.tickell.us`, NetBIOS `HOME`.
- **Keycloak** — identity broker and IdP overlaying Samba.
- **ManageEngine MDM** — pushes Wi‑Fi, VPN, and Kerberos SSO payloads.
- **Cloudflare WAF** — secures public access to `id.tickell.us`.
- **Microsoft Entra ID** — optional cloud ID extension for device registration and federation.

**Flow summary:**
1. Devices (macOS/Windows) join **Samba AD (HOME.TICKELL.US)**.
2. **Keycloak** federates users via LDAP from Samba.
3. **MDM** manages configuration and SSO payloads.
4. **Cloudflare WAF** protects external traffic to Keycloak (`id.tickell.us`).
5. **Internal Kerberos** continues to use `id.home.tickell.us` for SPNEGO.
6. **Entra ID** syncs users and registers Windows devices.

**Confidence:** High

---

## Phase 1 — Samba AD foundation (Already provisioned)

> **Status:** Samba AD is already set up with:
> - **Realm:** `HOME.TICKELL.US`
> - **DNS domain:** `home.tickell.us`
> - **NetBIOS:** `HOME`
> - **DCs:** `rio.home.tickell.us`, `donga.home.tickell.us`

**Verification steps:**
```bash
kinit administrator@HOME.TICKELL.US
kvno host/$(hostname -f)
klist
```
Confirm valid TGT and ticket.

Ensure DNS resolves internally and NTP is synced.

**Confidence:** High

---

## Phase 2 — Deploy Keycloak (Behind Cloudflare)

**Public URL:** `https://id.tickell.us` (via Cloudflare)  
**Internal URL:** `https://id.home.tickell.us` (local only)

### Deployment steps
1. Deploy Keycloak + Postgres + Caddy via Podman.
2. Caddy serves both internal and public hostnames.
3. Public DNS (`id.tickell.us`) proxied by Cloudflare → Caddy (public IP).
4. Internal DNS (`id.tickell.us` & `id.home.tickell.us`) resolves directly to LAN IP.

### Cloudflare configuration
- Proxy ON for `id.tickell.us` (WAF, DDoS protection).
- Page Rules for `id.tickell.us/*`:
  - **Security:** High
  - **Cache Level:** Bypass
  - **Rocket Loader:** Disabled
- Split-horizon DNS so internal clients reach LAN directly.

**Confidence:** High

### Keycloak configuration
- Realm: `tickell`
- LDAP connection: `ldaps://rio.home.tickell.us:636`
- Bind DN: `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`
- Sync mode: **READ_ONLY**
- MFA: OTP + Passkeys

**Confidence:** High

---

## Phase 3 — Kerberos Integration (Internal Only)

> Cloudflare WAF terminates TLS, so SPNEGO only works internally.

### Internal hostname for Kerberos
`id.home.tickell.us` — accessible only via internal DNS.

### SPN and keytab setup
```bash
samba-tool spn add keycloak$ HTTP/id.home.tickell.us
samba-tool domain exportkeytab --principal=HTTP/id.home.tickell.us /tmp/idp-http.keytab
```

### Kerberos config mapping
```ini
[domain_realm]
  .tickell.us = HOME.TICKELL.US
  .home.tickell.us = HOME.TICKELL.US
```

### Browser policy (internal clients)
- **Windows/Edge/Chrome:** add `id.home.tickell.us` to Local Intranet zone or `AuthServerAllowlist`.
- **macOS Chrome/Firefox:** add to trusted URIs for negotiate-auth.

**Confidence:** High

---

## Phase 4 — ManageEngine MDM Setup

1. Enroll Macs/iPhones in ManageEngine MDM.
2. Push **Kerberos SSO** profile:
   - Realm: `HOME.TICKELL.US`
   - Domains: `.home.tickell.us`
   - KDCs: `rio.home.tickell.us`, `donga.home.tickell.us`
3. Push Wi-Fi (EAP-TLS), VPN, and SCEP/cert payloads.

**Confidence:** High

---

## Phase 5 — Add Apps to Keycloak

OIDC Clients:
- Nextcloud (`https://cloud.tickell.us`)
- Vaultwarden (`https://vault.tickell.us`)
- Grafana, Home Assistant, etc.

Each app trusts Keycloak (`https://id.tickell.us`) as the issuer.

**Confidence:** High

---

## Phase 6 — Lightweight Entra Integration (Hybrid-like)

### 6.1 User Sync Script
Export users from Samba and import to Entra via Graph API.

### 6.2 Device Registration (Windows)
Windows PCs (Samba-joined) → `dsregcmd /join` → Entra *Registered*.

### 6.3 Optional AADS
Enable **Microsoft Entra Domain Services** if full AD-like join needed.

**Confidence:** High

---

## Phase 7 — Security Baselines

- MFA (WebAuthn + OTP)
- TLS (Let’s Encrypt via Caddy)
- Backups (Postgres + Keycloak export)
- Cloudflare WAF (public-facing IdP)
- Local admin + Entra break-glass account

**Confidence:** High

---

## Phase 8 — Rollout Order

| Day | Action |
|-----|---------|
| 1 | Verify Samba AD joins |
| 2 | Deploy Keycloak (Cloudflare-protected) |
| 3 | Configure MDM + enroll Apple devices |
| 4 | Register Windows PCs to Entra |
| Later | Optional AADS + cloud federation |

**Confidence:** High

---

## Architecture Diagrams

### A) Current: Internal + Cloudflare Split

```
            Internet
               │
               ▼
       +---------------------+
       |   Cloudflare WAF    |
       | (Proxy id.tickell.us)|
       +---------┬-----------+
                 │ HTTPS
                 ▼
       +---------------------+
       |     Caddy Proxy     |
       | id.tickell.us +     |
       | id.home.tickell.us  |
       +---------┬-----------+
                 │
         +-------▼--------+
         |    Keycloak    |
         |  Realm: tickell|
         +-------┬--------+
                 │ LDAP/Bind
                 ▼
         +-----------------+
         |  Samba AD (HOME)|
         | Realm: HOME.TICKELL.US |
         +-----------------+

   Internal users → id.home.tickell.us (Kerberos SPNEGO)
   External users → id.tickell.us (Cloudflare HTTPS)
```

### B) Future: Entra Integration

```
       +---------------------+
       |   Microsoft Entra   |
       |     (Cloud ID)      |
       +---------▲-----------+
                 │ Graph API / dsregcmd
     +-----------┴-----------+
     |  Sync Script (Python) |
     +-----------▲-----------+
                 │ LDAP (read)
          +------+------ +
          | Samba AD   |
          +-------------+

Windows (AD-joined) → dsregcmd /join → Entra: Registered
```

### C) Login Flow

```
External user → id.tickell.us → Cloudflare (TLS terminate) → Keycloak
Internal user → id.home.tickell.us → SPNEGO Kerberos → SSO token → App
```

---

**Final State:**  
- **Samba AD** = internal identity & Kerberos realm (`HOME.TICKELL.US`)  
- **Keycloak** = public IdP (`id.tickell.us`) behind Cloudflare; internal SPNEGO at `id.home.tickell.us`  
- **MDM** = manages device SSO & profiles  
- **Entra ID** = optional cloud sync & registration  
- **Cloudflare** = WAF + DDoS protection for public identity endpoint
