# CHECKLIST.md — Priority-Ordered Delivery Plan
> **Principle:** Deliver *function first*, then upgrade the *mechanism of delivery*.
> **Single IdP hostname:** `id.tickell.us` (split‑DNS). **Kerberos SPN:** `HTTP/id.tickell.us`.

---

## Phase A — Identity MVP on Podman (No Entra) ✅ *Start here*
**Goal:** Working SSO for family apps using Samba + Keycloak on Podman; MDM profiles active.

### A1. Samba AD (already provisioned) — Sanity
- [ ] DNS clients point to `rio`/`donga`
- [ ] `kinit administrator@HOME.TICKELL.US` / `klist` succeeds
- [ ] Time (NTP) in sync on DCs and clients

### A2. Keycloak @ `id.tickell.us` (split‑DNS; Cloudflare WAF external)
- [ ] Caddy serves Keycloak via `id.tickell.us` (internal resolves to LAN IP)
- [ ] Cloudflare proxy ON externally; Cache BYPASS; Rocket Loader OFF
- [ ] Keycloak realm `tickell` created (email-as-username ON, self-registration OFF)
- [ ] LDAP federation to Samba (READ_ONLY) via `ldaps://rio.home.tickell.us:636` (failover: `donga`)
- [ ] Kerberos SPN added & keytab exported for **`HTTP/id.tickell.us`** and uploaded to Keycloak
- [ ] Browser policies allow SPNEGO to `id.tickell.us` on internal devices

### A3. MDM (ManageEngine)
- [ ] APNs uploaded; devices enrolled (User-Approved MDM for Macs)
- [ ] **Kerberos SSO Extension**: Realm `HOME.TICKELL.US`, Domains `.home.tickell.us`, KDCs `rio` + `donga`
- [ ] Wi‑Fi (EAP‑TLS), VPN (on‑demand), SCEP/cert profiles deployed

### A4. First Apps behind SSO (OIDC to Keycloak)
- [ ] Nextcloud integrated (issuer `https://id.tickell.us/realms/tickell`)
- [ ] Vaultwarden integrated
- [ ] Grafana integrated
- [ ] Home Assistant integrated
- [ ] **Internal** login is silent via Kerberos; **External** login works with passkeys/MFA
- [ ] Backups enabled for Keycloak DB + realm export; app data backed up

**Exit Criteria Phase A**
- [ ] Family can log into at least **two** apps with SSO
- [ ] Kerberos works internally; Cloudflare WAF protects external IdP
- [ ] No `id.home.tickell.us` anywhere

---

## Phase B — Optional Entra Integration (Add Cloud Presence)
**Goal:** Add cloud registration and optional user presence without breaking local control.

- [ ] Export Samba users (`samba-tool user export …`) and import into Entra (Graph/PowerShell)
- [ ] One Windows PC registered: `dsregcmd /join` → shows as **Registered** in Entra
- [ ] (Optional) Evaluate Entra Domain Services (AADS) cost/benefit (not required)

**Exit Criteria Phase B**
- [ ] At least one user + one device appear in Entra
- [ ] Local Samba/Keycloak remain the source of truth

---

## Phase C — Platformization: OKD + GitOps + CI/CD (When ready)
**Goal:** Migrate from Podman to Kubernetes while preserving behavior from Phase A.

### C1. OKD Install (SNO preferred to learn)
- [ ] OKD up on Proxmox (SNO or compact)
- [ ] DNS: `api.okd.tickell.us`, `console.okd.tickell.us`, `*.apps.okd.tickell.us`
- [ ] Default storage class; ingress reachable
- [ ] cert‑manager installed (DNS‑01 via Cloudflare)

### C2. OAuth via Keycloak
- [ ] OKD OAuth provider = OIDC to `https://id.tickell.us/realms/tickell`
- [ ] `oc whoami` returns Keycloak identity; console login works

### C3. Argo CD (OpenShift GitOps) & Repos
- [ ] `family-gitops` repo created with **clusters/okd-home** and **apps/** structure
- [ ] Root “App of Apps” deployed and healthy
- [ ] Platform components (cert‑manager, External Secrets) synced

### C4. CI → GHCR
- [ ] Each app repo has GitHub Actions building to GHCR with tag `stable-<shortsha>`
- [ ] (Optional) Image automation updates manifests in `family-gitops`

### C5. Migrate Apps (one at a time)
- [ ] Nextcloud manifests (Deployment/Service/Route + PVCs); synced in Argo
- [ ] Vaultwarden manifests; synced
- [ ] Grafana manifests; synced
- [ ] DNS cutover to OKD Routes when healthy; Podman instance retired post‑backup

**Exit Criteria Phase C**
- [ ] At least **two** apps fully running on OKD via GitOps
- [ ] CI builds images; Argo synchronizes manifests
- [ ] Podman versions decommissioned (with backups)

---

## Phase D — Observability, Backup & DR (Harden)
- [ ] Loki/Promtail + Grafana dashboards for cluster & apps
- [ ] Velero backups for etcd + PVs; scheduled jobs in place
- [ ] **Quarterly restore drill**: one namespace + Keycloak realm

**Exit Criteria Phase D**
- [ ] Restore drill successful
- [ ] Monitoring alerts cover basic failures

---

## Phase E — Docs & Decisions (Keep Copilot Smart)
- [ ] `family_idm_okd_copilot_learning_plan.md` committed
- [ ] **ADR-001** Adopt Keycloak IdP (single-hostname `id.tickell.us`)
- [ ] **ADR-002** Split‑DNS strategy; Kerberos SPN `HTTP/id.tickell.us`
- [ ] **ADR-003** OKD SNO vs Compact (record final choice & rationale)
- [ ] CHECKLIST kept current in Git

**Exit Criteria Phase E**
- [ ] Copilot has enough context from READMEs, ADRs, and this CHECKLIST to guide future work

---

### Notes & Invariants
- Single IdP hostname everywhere: **`id.tickell.us`**
- Kerberos only via internal path (split‑DNS to LAN IP)
- Cloudflare WAF on public path; no Rocket Loader; cache bypass
- Never commit cleartext secrets; use SOPS + External Secrets
