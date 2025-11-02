# Family Infrastructure — CHECKLIST.md

This file acts as your **operational truth table** while building and learning.  
Use it to track what’s done and what’s pending.

---

## ✅ Identity (Samba + Keycloak)
- [ ] Samba AD verified: `rio` + `donga` reachable
- [ ] Kerberos SPN `HTTP/id.tickell.us` exported
- [ ] Keycloak realm `tickell` configured (LDAP + Kerberos)
- [ ] MDM payloads deployed (Kerberos SSO, Wi-Fi, VPN)
- [ ] Split‑DNS verified for `id.tickell.us`
- [ ] Cloudflare WAF active externally

---

## ☁️ Entra Integration
- [ ] Test import of Samba users to Entra via LDIF
- [ ] Run `dsregcmd /join` on one Windows device
- [ ] Validate Entra-registered device appears in portal

---

## 🛠️ OKD Setup
- [ ] Install OKD (SNO or compact) on Proxmox
- [ ] Configure `api.okd.tickell.us`, `console.okd.tickell.us`, `*.apps.okd.tickell.us`
- [ ] Deploy cert‑manager (DNS‑01 via Cloudflare)
- [ ] Verify ingress and default storage class

---

## 🔐 OAuth & Keycloak
- [ ] Create Keycloak client `openshift`
- [ ] Configure OKD OAuth provider = OIDC → Keycloak
- [ ] Confirm `oc whoami` shows Keycloak user

---

## 📦 GitOps & Argo CD
- [ ] Deploy Argo CD (OpenShift GitOps Operator)
- [ ] Create `family-gitops` repo
- [ ] Define `clusters/okd-home` & `apps/*` overlays
- [ ] Root “App of Apps” syncing successfully

---

## 🚀 CI/CD (GitHub Actions → GHCR)
- [ ] GH Actions workflow in each app repo
- [ ] Image builds + pushes to GHCR
- [ ] Tags follow `stable-<shortsha>`
- [ ] Optional: automated Argo sync after merge

---

## 🧩 Secrets & Certificates
- [ ] SOPS (age) keypair generated
- [ ] External Secrets Operator deployed
- [ ] cert‑manager issues valid certs via DNS‑01

---

## 📊 Observability & Backup
- [ ] Loki/Promtail + Grafana running
- [ ] Velero backups for etcd + PVs
- [ ] Quarterly restore test successful

---

## 🧭 Documentation & Learning
- [ ] First ADR written (e.g., ADR-001 Adopt Keycloak)
- [ ] `family_idm_okd_copilot_learning_plan.md` committed to repo
- [ ] GitHub Copilot suggestions improving workflow

---

## 🏁 Final Targets
- [ ] All services migrated off Podman
- [ ] OKD GitOps pipeline stable
- [ ] Keycloak → OKD OAuth operational
- [ ] Single-sign-on across family devices and apps
