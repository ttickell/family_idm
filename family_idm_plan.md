# Family Identity & Device Management Plan — Samba + Keycloak + MDM + Entra Integration

**Audience:** 5-person family; Apple-first with some Windows PCs.

**Goal:** Build a self-hosted identity foundation (Samba AD + Keycloak) with MDM for device management, then extend it into Entra ID for cloud-linked SSO — without losing local control.

**Confidence levels:** Every section includes confidence estimates (High / Medium / Low).

---

## Phase 0 — Overview & Architecture

**Core stack:**
- **Samba AD** — local domain controller providing Kerberos, LDAP, and DNS.
- **Keycloak** — identity broker and IdP overlaying Samba.
- **ManageEngine MDM** — to push profiles, Wi-Fi, VPN, and Kerberos SSO.
- **Microsoft Entra ID** — optional cloud layer for SSO with Microsoft services.

**Flow summary:**
1. Devices (macOS/Windows) join **Samba AD** → Kerberos realm `HOME.TICKELL.US`.
2. **Keycloak** federates users from Samba via LDAP → provides OIDC/SAML SSO for apps.
3. **MDM** delivers Wi-Fi/VPN/cert and Kerberos SSO payloads for Apple devices.
4. **Entra ID** syncs user metadata (lightweight) and optionally registers devices.

**Confidence:** High

---

## Phase 1 — Samba AD foundation (Already provisioned)

> **Status:** Samba AD is already set up with:
> - **Realm:** `HOME.TICKELL.US`
> - **DNS domain:** `home.tickell.us`
> - **NetBIOS domain:** `HOME`

**Verification steps:**
```bash
kinit administrator@HOME.TICKELL.US
kvno host/$(hostname -f)
klist
```
Confirm valid TGT and ticket.

Ensure all clients use your Samba DC for DNS and NTP is in sync.

**Domain Controllers:**
- `rio.home.tickell.us`
- `donga.home.tickell.us`

**Confidence:** High

---

## Phase 2 — Deploy Keycloak

- Deploy with Podman and Caddy (TLS via Let’s Encrypt).
- Realm: `tickell`
- LDAP connection: `ldaps://rio.home.tickell.us:636`
- Bind DN: `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`
- Attributes mapped: `sAMAccountName`, `mail`, `givenName`, `sn`
- Sync mode: **READ_ONLY**
- Test login with Samba user credentials.

**Confidence:** High

---

## Phase 3 — Kerberos Integration (Optional)

Add SPNs and export keytab for Keycloak service:
```bash
samba-tool spn add keycloak$ HTTP/id.tickell.us
samba-tool spn add keycloak$ HTTP/id.home.tickell.us
samba-tool domain exportkeytab --principal=HTTP/id.tickell.us --principal=HTTP/id.home.tickell.us /tmp/idp-http.keytab
```

Update `/etc/krb5.conf`:
```ini
[domain_realm]
  .tickell.us = HOME.TICKELL.US
  .home.tickell.us = HOME.TICKELL.US
```

**Confidence:** Medium

---

## Phase 4 — ManageEngine MDM Setup

1. Enroll Macs/iPhones in ManageEngine MDM (User-Approved MDM).
2. Push **Kerberos SSO** profile:
   - Realm: `HOME.TICKELL.US`
   - Domain: `.home.tickell.us`
   - KDCs: `rio.home.tickell.us`, `donga.home.tickell.us`
3. Push Wi-Fi (EAP-TLS), VPN (on-demand), and SCEP/cert payloads.

**Confidence:** High

---

## Phase 5 — Add Apps to Keycloak

Create OIDC clients in Keycloak for:
- Nextcloud
- Vaultwarden
- Grafana
- Home Assistant

Redirect URI examples:
```
https://cloud.tickell.us/login/oauth2/callback
https://vault.tickell.us/oauth/callback
```

**Confidence:** High

---

## Phase 6 — Lightweight Entra Integration (Hybrid-like)

### User Sync Script (Samba → Entra)
Export and sync users manually or via script:
```bash
samba-tool user export /tmp/users.ldif
```
Convert and import via PowerShell or Graph API.

### Device Registration (Windows)
Register Windows PCs while remaining AD-joined:
```bash
dsregcmd /join
```
Devices appear as *Registered* in Entra.

### Entra Domain Services (optional)
For full hybrid AD join (adds cost ~$100/mo).

**Confidence:** High

---

## Phase 7 — Security Baselines

- Enforce MFA (WebAuthn + OTP)
- TLS via Caddy
- Nightly Postgres + Keycloak backups
- Maintain local Samba + cloud admin accounts

**Confidence:** High

---

## Phase 8 — Rollout Order

| Day | Action |
|-----|---------|
| 1 | Verify Samba AD + test joins |
| 2 | Deploy Keycloak + integrate LDAP |
| 3 | Configure MDM + enroll Apple devices |
| 4 | Register Windows PCs to Entra |
| Later | Add Entra Domain Services or cloud federation |

**Confidence:** High

---

## Phase 9 — Optional Automation

### Samba → Entra Sync (Python)
```python
from ldap3 import Server, Connection, ALL
from msgraph.core import GraphClient
import os

server = Server('ldaps://rio.home.tickell.us', get_info=ALL)
conn = Connection(server, user='CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us', password=os.getenv('LDAP_PASS'))
conn.bind()
conn.search('DC=home,DC=tickell,DC=us', '(objectClass=user)', attributes=['sAMAccountName','mail','displayName'])

client = GraphClient(credential=os.getenv('GRAPH_TOKEN'))
for entry in conn.entries:
    upn = f"{entry.sAMAccountName}@id.tickell.us"
    payload = {
      'accountEnabled': True,
      'displayName': str(entry.displayName),
      'userPrincipalName': upn,
      'mailNickname': str(entry.sAMAccountName),
      'passwordProfile': {'forceChangePasswordNextSignIn': False, 'password': 'TempPassw0rd!'}
    }
    client.post('/users', json=payload)
```

**Confidence:** High

---

## Architecture Diagrams

### A) Core Stack (Current)

```
            Internet
               │
               ▼
        +----------------+
        |    Caddy TLS   |
        +----------------+
               │ https://id.tickell.us
               ▼
        +----------------+
        |   Keycloak     |
        +----------------+
           ▲          ▲
           │ OIDC/SAML│
           │          │ LDAP/Bind (read-only)
           │          ▼
  +----------------+  +----------------------+
  |   Your Apps    |  |  Samba AD (HOME)     |
  |  (Nextcloud,   |  |  Realm: HOME.TICKELL.US
  |  Grafana, etc) |  |  Domain: home.tickell.us
  +----------------+  +----------------------+
           ▲                     ▲
           │                     │
           │ MDM profiles        │ Kerberos tickets
           ▼                     │
   +-----------------+           │
   | ManageEngine    |           │
   |   MDM (Free)    |           │
   +-----------------+           │
           ▲                     │
   +--------------------+  +--------------------+
   | macOS / iOS/iPadOS |  | Windows 10/11     |
   | (SSO Extension)    |  | (AD-joined: HOME) |
   +--------------------+  +--------------------+
```

### B) Entra Extension (Future)

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
           +-----+-----+
           |  Samba AD |
           +-----------+

Windows (AD-joined) → dsregcmd /join → Entra: Registered
```

### C) Login Flow

```
User → App (Nextcloud) → Redirect to Keycloak →
  (TGT) SPNEGO or Password+MFA → Tokens → App session
```

---

**Final State:**  
- **Samba AD** = local identity and Kerberos source  
- **Keycloak** = federated IdP for all apps  
- **MDM** = device configuration & Kerberos SSO payloads  
- **Entra ID** = optional cloud layer for registration and sync

Ready for Git versioning.
