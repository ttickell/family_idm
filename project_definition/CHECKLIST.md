# CHECKLIST.md — Function-First Delivery (Read Me, Copilot)
> **Intent:** Prioritize **identity experience** first, then platform mechanics.  
> **Invariant:** Single IdP hostname **`id.tickell.us`** with **split-DNS**. **Kerberos SPN:** `HTTP/id.tickell.us`. **Realm:** `HOME.TICKELL.US`.  
> **Absolute Rule:** 🚫 **Never expose any host under `home.tickell.us` to the public internet.**  
> **Anti-pattern:** ⚠️ Do **not** introduce Kubernetes/Helm/OKD in Phase 1. Do **not** invent `id.home.tickell.us`.

---

## 📋 Phase 1 — Identity Foundation (Podman-based)  **← Start here**
**Goal:** Rock-solid SSO on Podman for a 5-person Apple-first family.

### A1. Samba AD sanity (already provisioned)
- [ ] DNS clients → `rio.home.tickell.us` / `donga.home.tickell.us`
- [ ] Kerberos: `kinit administrator@HOME.TICKELL.US` / `klist` ok
- [ ] Time/NTP in sync

### A2. Keycloak @ `https://id.tickell.us`  (split-DNS + Cloudflare WAF external)
- [x] Caddy reverse proxy on `idealx` serves Keycloak at **`id.tickell.us`**
- [x] Cloudflare: **Proxy ON** externally; Cache **Bypass**, Rocket Loader **OFF**
- [x] Keycloak realm `tickell` created (email-as-username ON, self-registration OFF)
- [x] LDAP federation (READ_ONLY) → `ldaps://rio.home.tickell.us:636` (**UPGRADED to LDAPS with certificate validation**)
- [ ] Kerberos: add SPN **`HTTP/id.tickell.us`**, export/upload keytab
- [ ] Browsers (internal) allow SPNEGO to `id.tickell.us`

### A3. **MDM (ManageEngine) — Critical to Phase 1**
- [ ] APNs uploaded; enroll Macs/iPhones (User-Approved MDM for Macs)
- [ ] **Kerberos SSO Extension** payload: Realm `HOME.TICKELL.US`; Domains `.home.tickell.us`; KDCs `rio`,`donga`
- [ ] Wi-Fi (EAP-TLS), VPN (on-demand), SCEP/cert profiles deployed
- [ ] **MDM/SCEP endpoints bypass Cloudflare proxy:**
  - Public hostnames: `mdm.id.tickell.us`, `scep.id.tickell.us` → **DNS Only (grey cloud)** in Cloudflare.
  - Split-DNS: LAN resolves to internal IPs; remote resolves to public IPs.
  - 🚫 **Never expose `*.home.tickell.us` externally.**
  - Verify enrollment & certificate issuance complete without TLS errors.
- [ ] Confirm Macs/iOS obtain Kerberos tickets automatically

### A4. First apps behind SSO (Podman)
- [ ] Nextcloud OIDC (issuer `https://id.tickell.us/realms/tickell`)
- [ ] Vaultwarden OIDC
- [ ] Grafana OIDC
- [ ] Home Assistant OIDC
- [ ] Backups: Keycloak DB + realm export; app data dumps

### A5. Certificate Hardening
- [x] Replace Samba LDAPS auto-generated certificate with internal CA certificate
- [x] Upgrade LDAP federation from `ldap://rio.home.tickell.us:389` to `ldaps://rio.home.tickell.us:636`
- [x] Verify LDAPS certificate validation works properly in Keycloak federation
- [ ] Update any other services using auto-generated certificates to use internal CA

**Phase 1 Definition of Done**
- [ ] **Internal** app login is silent (SPNEGO); **External** login works with passkeys/MFA
- [ ] **Core apps** working with SSO on Podman
- [ ] **Split-DNS** for `id.tickell.us` proven
- [ ] **No** `id.home.tickell.us` anywhere
- [ ] **MDM/SCEP** endpoints validated (bypass Cloudflare)
- [ ] **No host under `home.tickell.us` publicly reachable**

---

## 🚢 Phase 2 — Platform Migration (OKD + GitOps)  **← Only after Phase 1 is perfect**
**Goal:** Replace Podman runtime with OKD while keeping the same SSO behavior.

### B1. OKD install
- [ ] OKD SNO (or compact) on Proxmox; default storage class present
- [ ] DNS: `api.okd.tickell.us`, `console.okd.tickell.us`, `*.apps.okd.tickell.us`
- [ ] cert-manager via DNS-01 (Cloudflare)

### B2. OAuth via Keycloak
- [ ] Configure OpenShift OAuth: OIDC to `https://id.tickell.us/realms/tickell`
- [ ] `oc whoami` returns Keycloak identity; console login works

### B3. GitOps (Argo CD)
- [ ] `family-gitops` repo: `clusters/okd-home`, `platform/*`, `apps/*`
- [ ] Root **app-of-apps** healthy; platform (cert-manager, External Secrets) synced

### B4. CI/CD (GitHub Actions → GHCR)
- [ ] Each app builds/pushes `stable-<shortsha>` to GHCR

### B5. Migrate apps one-by-one
- [ ] Nextcloud manifests synced; DNS cutover to Route
- [ ] Vaultwarden manifests synced
- [ ] Grafana manifests synced
- [ ] Podman instances retired after backup

**Phase 2 Definition of Done**
- [ ] OKD OAuth→Keycloak ok; Argo syncing from `family-gitops`
- [ ] Apps live under `*.apps.okd.tickell.us`
- [ ] Full GitOps loop operational (CI→image, Argo→deploy)
- [ ] `home.tickell.us` remains private-only

---

## ☁️ Optional — Entra (after Phase 1, anytime before/after Phase 2)
- [ ] Import users (LDIF→Graph/PowerShell) to Entra
- [ ] Register a Windows PC: `dsregcmd /join` → shows as **Registered**
- [ ] AADS evaluated (cost/benefit)

**Entra DoD**
- [ ] At least one user + one device visible in Entra; local Samba/Keycloak remain SoT

---

## 📊 Ops Hardening (continuous)
- [ ] Loki/Promtail + Grafana dashboards
- [ ] Velero backups for etcd + PVs (when OKD), plus app data and Keycloak realm export
- [ ] Quarterly restore drill: one namespace + Keycloak realm

---

## 🧠 Copilot Anchors (Put these in READMEs)
- **Single hostname:** Use only `id.tickell.us` for IdP (split-DNS).  
- **Kerberos:** SPN `HTTP/id.tickell.us`. Internal path only; external is web login via Cloudflare.  
- **MDM/SCEP:** Use `mdm.id.tickell.us` and `scep.id.tickell.us` (DNS Only). Never expose `home.tickell.us`.  
- **Phase boundaries:** Phase 1 = Podman; Phase 2 = OKD.  
- **MDM is Phase 1 critical:** Kerberos SSO Extension must be deployed for silent login on Apple devices.
