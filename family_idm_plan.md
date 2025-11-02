# Family Identity & Device Management Plan — Samba + Keycloak + MDM + Entra (Single-Hostname Split‑DNS)

**Audience:** 5‑person family; Apple‑first with some Windows PCs.  
**Goal:** Self‑hosted identity (Samba AD + Keycloak) with MDM, **one IdP hostname** — `id.tickell.us` — using **split‑horizon DNS**: internal clients go direct to LAN; external clients go via Cloudflare WAF. Optional Entra integration.

> ✅ This version removes all `id.home.tickell.us` references and standardizes on **`id.tickell.us`** everywhere. Kerberos SPN, SSO profiles, and diagrams are all updated accordingly.

---

## Phase 0 — Overview & Architecture

**Core stack**
- **Samba AD** — realm `HOME.TICKELL.US`, DNS `home.tickell.us`, NetBIOS `HOME`; DCs: `rio.home.tickell.us`, `donga.home.tickell.us`.
- **Keycloak** — IdP/broker, **served at `https://id.tickell.us`** (single hostname).
- **Caddy** — reverse proxy/TLS on LAN host.
- **Cloudflare WAF** — protects **external** access to `id.tickell.us`.
- **ManageEngine MDM** — Wi‑Fi/VPN/cert + Kerberos SSO payloads.
- **Microsoft Entra ID** — optional: user import and Windows device registration.

**Flow summary**
1) Devices join **Samba AD (HOME)**.  
2) **Keycloak** federates users via Samba LDAP.  
3) **Split‑DNS**: `id.tickell.us` → **LAN IP** (inside) / **Cloudflare** (outside).  
4) **Kerberos/SPNEGO** works internally to `id.tickell.us`; external users use standard web login.  
5) Optional **Entra**: user sync + `dsregcmd /join` on Windows.

**Confidence:** High

---

## Phase 1 — Samba AD foundation (already provisioned)

- Realm: `HOME.TICKELL.US`; Domain: `home.tickell.us`; NetBIOS: `HOME`; DCs: `rio`, `donga`.
- Verify Kerberos:
```bash
kinit administrator@HOME.TICKELL.US
kvno host/$(hostname -f)
klist
```
- Ensure clients use DC DNS; NTP in sync.

**Confidence:** High

---

## Phase 2 — Keycloak on `id.tickell.us` (Split‑DNS + Cloudflare)

**Hostname (only):** `id.tickell.us`

### DNS layout
- **External (public DNS):** `id.tickell.us` → Cloudflare proxy → your public IP (Caddy).  
- **Internal (LAN DNS):** `id.tickell.us` → **LAN IP** of Caddy/Keycloak (bypasses Cloudflare).

### Cloudflare settings (for `id.tickell.us/*`)
- Proxy: **ON** (WAF, DDoS).  
- Security level: High.  
- Cache level: **Bypass**.  
- Disable **Rocket Loader** and auto‑minify.

### Keycloak basics
- Realm: `tickell` (email as username ON; self‑registration OFF).
- MFA: OTP + WebAuthn/Passkeys.
- LDAP (Samba): `ldaps://rio.home.tickell.us:636` (failover add donga).  
  Bind DN: `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`.  
  Sync mode: **READ_ONLY**.  Attribute maps: `sAMAccountName→username`, `mail`, `givenName`, `sn`.

**Confidence:** High

---

## Phase 3 — Internal Kerberos/SPNEGO for Keycloak

> With split‑DNS, internal browsers hit **`id.tickell.us` → LAN IP**, allowing Kerberos.

### SPN and keytab (only this SPN)
```bash
samba-tool spn add keycloak$ HTTP/id.tickell.us
samba-tool domain exportkeytab --principal=HTTP/id.tickell.us /tmp/idp-http.keytab
```
Upload keytab to Keycloak Kerberos authenticator (realm = `HOME.TICKELL.US`).

### `krb5.conf` realm mapping (clients)
```ini
[domain_realm]
  .tickell.us = HOME.TICKELL.US
  .home.tickell.us = HOME.TICKELL.US
```

### Browser policy (internal)
- Edge/Chrome (Windows): add `id.tickell.us` to Local Intranet zone or `AuthServerAllowlist`.
- Chrome (macOS): `AuthServerAllowlist=id.tickell.us` policy.
- Firefox: `network.negotiate-auth.trusted-uris = id.tickell.us`.

**Confidence:** High

---

## Phase 4 — ManageEngine MDM

1) Enroll Macs/iPhones (User‑Approved MDM).  
2) **Kerberos SSO Extension** payload:  
   - Realm: `HOME.TICKELL.US`  
   - Domains: `.home.tickell.us`  
   - KDCs: `rio.home.tickell.us`, `donga.home.tickell.us`  
   - (Optional) Map to Safari/Chrome as needed
3) Wi‑Fi (EAP‑TLS), VPN (on‑demand), SCEP/cert payloads.
4) Windows agent enrollment/baselines (BitLocker, updates).

**Confidence:** High

---

## Phase 5 — Put apps behind Keycloak (OIDC/SAML)

Good first apps: **Nextcloud**, **Vaultwarden**, **Grafana**, **Home Assistant**.  
- Issuer: `https://id.tickell.us/realms/tickell`  
- Scopes: `openid email profile`  
- Redirect URIs per app

**Confidence:** High

---

## Phase 6 — Lightweight Entra Integration (hybrid‑like)

### 6.1 User import
Export from Samba:
```bash
samba-tool user export /tmp/users.ldif
```
Transform → import to Entra via Graph/PowerShell (`New-MgUser …`).

### 6.2 Windows device registration
Keep devices **AD‑joined to HOME**, then:
```powershell
dsregcmd /join
```
Devices appear in Entra as **Registered** (not “Hybrid Joined”).

### 6.3 Optional AADS
If you need full AD‑like joins from cloud, enable **Microsoft Entra Domain Services** (added cost).

**Confidence:** High

---

## Phase 7 — Security baselines

- MFA required; passkeys allowed; OTP fallback.  
- TLS: Let’s Encrypt via Caddy; HSTS.  
- Backups: nightly Postgres dump + Keycloak realm export; quarterly restore test.  
- Cloudflare WAF for public traffic.  
- Break‑glass: one Samba on‑prem admin + one Entra cloud‑only admin.

**Confidence:** High

---

## Phase 8 — Rollout order

| Day | Action |
|-----|--------|
| 1 | Verify Samba AD + client time/DNS |
| 2 | Deploy Keycloak at `id.tickell.us` (split‑DNS + Cloudflare) |
| 3 | MDM enroll Apple; push Kerberos SSO, Wi‑Fi/VPN/SCEP |
| 4 | Add 1–2 apps to Keycloak; register Windows to Entra |
| Later | Optional AADS or per‑app Entra trust |

**Confidence:** High

---

## Architecture Diagrams

### A) Current: Single‑Hostname Split‑DNS

```
             Internet
                │
                ▼
        +---------------------+
        |   Cloudflare WAF    |
        |  (id.tickell.us)    |
        +----------┬----------+
                   │ HTTPS (external only)
                   ▼
        +---------------------+
        |    Caddy (LAN IP)   |  ← Also reached directly by internal DNS
        +----------┬----------+
                   │
          +--------▼--------+
          |     Keycloak    |  Issuer: https://id.tickell.us/realms/tickell
          +--------┬--------+
                   │ LDAP (read‑only)
                   ▼
          +------------------+
          |  Samba AD (HOME) |
          |  rio / donga     |
          +------------------+

Internal: DNS `id.tickell.us` → LAN IP → Kerberos/SPNEGO OK  
External: DNS `id.tickell.us` → Cloudflare → HTTPS login (no SPNEGO)
```

### B) Entra extension

```
     +----------------------+
     |   Microsoft Entra    |
     +----------▲-----------+
                │  Graph API (user import) / dsregcmd (device reg)
   +------------┴------------+
   |   Sync/Import Script    |
   +------------▲------------+
                │  LDAP (read)
        +-------+-------+
        |   Samba AD    |
        +---------------+

Windows (AD‑joined) → dsregcmd /join → Entra: Registered
```

### C) Login flow

```
User → App → Redirect to https://id.tickell.us →
  Internal: Kerberos SPNEGO → SSO token → App
  External: Password/Passkey + MFA → SSO token → App
```

---

## Appendix F — Hostname Conventions

**Proxmox (stars)**: `proxima`, `toliman`, `rigil`  
**Samba (samba pioneers)**: `rio`, `donga`, `cartola`  
**Podman (container ships)**: **`idealx`** (primary), optional `emma`, `rocinante`

- **Keycloak/Caddy/Postgres host:** `idealx.home.tickell.us`  
- **IdP URL (single hostname):** `https://id.tickell.us` (split‑DNS)

**Principles**
- One IdP hostname everywhere (`id.tickell.us`).  
- Split‑horizon DNS for internal Kerberos and external WAF.  
- SPN **only** `HTTP/id.tickell.us`.

---

**Final state**
- **Samba AD (HOME)** for on‑prem identity/Kerberos.  
- **Keycloak at `id.tickell.us`** for SSO (internal Kerberos + external HTTPS).  
- **MDM** enforces Wi‑Fi/VPN/cert + Kerberos SSO on Apple.  
- **Entra** optional for cloud presence/registration.
