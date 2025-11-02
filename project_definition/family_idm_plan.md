# Family Identity, GitOps & OKD Learning Plan — *Hands‑On with Copilot* (Single‑Hostname Split‑DNS)

**Audience:** You (solo operator), 5‑person family; Apple‑first with some Windows PCs.  
**Mode:** Learn‑by‑doing. You will **type commands and author files by hand**; GitHub Copilot assists with *inline* guidance and completions.  
**IdP hostname:** **`id.tickell.us`** (single hostname, split‑horizon DNS).  
**Theme notes:** Proxmox (stars), Samba (samba pioneers), Podman/OKD (container ships: `idealx`).

> This doc is written so that **VS Code + Copilot** has *sufficient context* to guide you end‑to‑end: it includes folder structures, minimal examples, “Definition of Done” checklists, and **prompts** you can paste to Copilot inline.  
> Confidence: **High**.

---

## 0) Ground Truth & Assumptions (Pin these for Copilot)
- **Directory/Realm:** `HOME.TICKELL.US`; **DNS:** `home.tickell.us`; **NetBIOS:** `HOME`; DCs: `rio.home.tickell.us`, `donga.home.tickell.us`.
- **IdP URL:** `https://id.tickell.us` (**single hostname**; split‑DNS).
- **Reverse proxy:** Caddy on `idealx.home.tickell.us` (legacy Podman host), serving Keycloak.
- **Cloudflare:** Proxy ON for external; Cache BYPASS; Rocket Loader OFF.
- **Kerberos SPN:** `HTTP/id.tickell.us` (only).
- **MDM:** ManageEngine; Kerberos SSO Extension targets `HOME.TICKELL.US`.
- **Git:** GitHub org/user `tickell` (adjust if needed).
- **K8s platform:** **OKD** (SNO or compact) with **Argo CD** (OpenShift GitOps).
- **CI:** GitHub Actions building to **GHCR**.
- **Secrets:** SOPS (age) + External Secrets Operator.

> Copilot prompt to keep handy:  
> **“Treat `id.tickell.us` as the only IdP hostname (split‑DNS). Assume Kerberos SPN `HTTP/id.tickell.us`, Samba realm `HOME.TICKELL.US`, and DCs `rio`/`donga`. Do not introduce `id.home.tickell.us`.”**

---

## 1) Samba + Keycloak (Recap)
- LDAP in Keycloak: `ldaps://rio.home.tickell.us:636` (failover: `donga`); Bind DN `CN=Keycloak Bind,CN=Users,DC=home,DC=tickell,DC=us`; READ_ONLY.
- Kerberos: export keytab for `HTTP/id.tickell.us`; upload to Keycloak’s Kerberos authenticator.
- MDM: Kerberos SSO Extension → Realm `HOME.TICKELL.US`; Domains `.home.tickell.us`; KDCs `rio` + `donga`.
- **Definition of Done (DoD):**
  - [ ] Internal login to a Keycloak‑protected app is silent (SPNEGO).  
  - [ ] External login works via Cloudflare with passkeys/MFA.  
  - [ ] No references to `id.home.tickell.us` anywhere.

Confidence: **High**.

---

## 2) VS Code Workspace & Git Repos

Create a parent folder and open in VS Code:
```
~/src/tickell/
├─ family-gitops/         # GitOps manifests (Argo CD watches)
├─ apps/                  # App source repos (one folder per app)
│  ├─ nextcloud/
│  ├─ vaultwarden/
│  └─ grafana/
└─ platform-notes/        # Scratch notes, diagrams, ADRs
```

Initialize repos:
```bash
cd ~/src/tickell/family-gitops && git init
cd ~/src/tickell/apps/nextcloud && git init
# repeat for other apps
```

> Copilot prompt:  
> **“Create a README that explains this monorepo layout: ‘family-gitops’ is Argo’s source of truth; ‘apps/*’ are separate app repos in practice. Include split‑DNS and IdP assumptions.”**

DoD:
- [ ] Each repo has a README with the above context (so Copilot sees it).  
- [ ] Commit + push to GitHub (so Actions & Argo can reference it).

Confidence: **High**.

---

## 3) OKD Cluster Planning

Pick **one**:
- **SNO** (Single‑Node OKD) on Proxmox (simplest to learn).  
- **Compact 3‑node** across `proxima`, `toliman`, `rigil` (HA; heavier).

DNS (split‑DNS encouraged):
- `api.okd.tickell.us` → OKD API VIP
- `console.okd.tickell.us` → OKD console
- `*.apps.okd.tickell.us` → Ingress VIP (Cloudflare proxy OFF unless needed per app)

cert‑manager: DNS‑01 via Cloudflare for `*.apps.okd.tickell.us`.

DoD:
- [ ] `oc login https://api.okd.tickell.us:6443` works.  
- [ ] Console loads; Node(s) healthy; storage class present.

Confidence: **Medium‑High**.

> Copilot prompt:  
> **“Outline SNO OKD install on Proxmox (UPI) with static IPs, API/Ingress VIPs, and split‑DNS. Prefer Assisted Installer notes only if they simplify homelab.”**

---

## 4) OKD OAuth → Keycloak

- OKD OAuth provider = **OIDC** to `https://id.tickell.us/realms/tickell`
- Claims: `preferred_username`, `email`, `groups`
- Keycloak client `openshift` with redirect:  
  `https://oauth-openshift.apps.okd.tickell.us/oauth2callback/oidc`

DoD:
- [ ] `oc whoami` returns your Keycloak username.  
- [ ] Console login works via Keycloak.

Confidence: **High**.

> Copilot prompt:  
> **“Generate YAML to set OpenShift OAuth to a Keycloak OIDC provider at https://id.tickell.us/realms/tickell with standard claims.”**

---

## 5) Argo CD (OpenShift GitOps)

Install **OpenShift GitOps** Operator. Create a **root App of Apps**:

Repo structure (**family-gitops**):
```
family-gitops/
├─ clusters/
│  └─ okd-home/
│     ├─ kustomization.yaml
│     └─ apps.yaml            # Argo ‘app-of-apps’
├─ platform/
│  ├─ cert-manager/
│  ├─ external-secrets/
│  └─ monitoring/
└─ apps/
   ├─ nextcloud/
   │  ├─ base/
   │  │  ├─ deployment.yaml
   │  │  ├─ service.yaml
   │  │  └─ route.yaml        # or ingress.yaml
   │  └─ overlays/prod/
   │     └─ kustomization.yaml
   └─ vaultwarden/...
```

DoD:
- [ ] Argo shows the root app healthy.  
- [ ] Platform components sync (cert‑manager, ESO).

Confidence: **High**.

> Copilot prompt:  
> **“Author an Argo CD app-of-apps manifest that deploys cert-manager and external-secrets from ./platform/* and Nextcloud from ./apps/nextcloud/overlays/prod.”**

---

## 6) GitHub Actions (CI → GHCR)

Each app repo (`apps/nextcloud`) has a minimal workflow that **builds** and **pushes** images to GHCR on `main`. Use tags like `stable-<shortsha>`.

DoD:
- [ ] Image published at `ghcr.io/<owner>/<repo>:stable-<sha>`.
- [ ] (Optional) Image automation PR bumps tag inside `family-gitops` overlays.

Confidence: **High**.

> Copilot prompt:  
> **“Create a GitHub Actions workflow that builds a Docker/Podman image and pushes to GHCR with tag stable-<git short sha>. Assume there is a Dockerfile at repo root.”**

---

## 7) Secrets & Certificates (GitOps)

- **SOPS (age)** for encrypting Kubernetes manifests in Git.  
- **External Secrets Operator** pulls cleartext from your chosen backend (Bitwarden/1Password/file) into clusters.
- **Never commit cleartext secrets**.

DoD:
- [ ] `age` keypair generated and stored safely.  
- [ ] SOPS‑encrypted Secret or ExternalSecret manifest merges cleanly.  
- [ ] cert‑manager issues `*.apps.okd.tickell.us` cert via DNS‑01.

Confidence: **High**.

> Copilot prompts:  
> - **“Show me a SOPS-encrypted Kubernetes Secret example with age recipients.”**  
> - **“Write an ExternalSecret that reads from 1Password/Bitwarden for Nextcloud DB credentials.”**

---

## 8) Migrate Services: Podman → OKD (by hand)

1) **Inventory** containers on `idealx` (Keycloak, Caddy, Postgres, Nextcloud, Vaultwarden, Grafana).  
2) For each app, create **base manifests** (or a lightweight **Helm chart**), then an **overlay** for prod.  
3) Deploy via Argo; wait for green; switch DNS (Route) to new service.  
4) Verify; decommission Podman service.

DoD:
- [ ] App runs in OKD with Route under `*.apps.okd.tickell.us`.  
- [ ] OIDC to `id.tickell.us` works where applicable.  
- [ ] Old container stopped; data migrations completed/backed up.

Confidence: **High**.

> Copilot prompt:  
> **“Create base Deployment/Service/Route manifests for Nextcloud in namespace nextcloud with persistent storage and resource requests appropriate for a homelab.”**

---

## 9) Observability & Backups

- **Loki/Promtail + Grafana** for logs/metrics.  
- **Backups:** etcd snapshots, PV backups (Restic/Velero), Keycloak realm export, Postgres dumps.  
- **Drills:** quarterly restore a single namespace.

DoD:
- [ ] Grafana shows cluster & app dashboards.  
- [ ] Verified restore for one app and for Keycloak realm.

Confidence: **High**.

> Copilot prompt:  
> **“Draft a Velero backup plan for an OKD SNO cluster with Restic for PVs and a restore walkthrough.”**

---

## 10) Checklists (Quick Reference)

**Cluster DoD**
- [ ] OKD reachable; nodes Ready; storage class default.  
- [ ] OAuth → Keycloak works.  
- [ ] cert‑manager + ESO synced.

**GitOps DoD**
- [ ] `family-gitops` repo has `clusters/okd-home` and `apps/*` overlays.  
- [ ] Argo root app healthy; apps syncing automatically.

**Security DoD**
- [ ] SOPS operational; no cleartext secrets in Git.  
- [ ] Cloudflare WAF on public IdP; split‑DNS in place.

**Apps DoD**
- [ ] Each app has CI to GHCR.  
- [ ] Route live under `*.apps.okd.tickell.us`.  
- [ ] OIDC to `https://id.tickell.us/realms/tickell` when applicable.

Confidence: **High**.

---

## 11) Copilot Prompt Library (Paste as comments where you’re working)

- **Repo bootstrap:**  
  *“Create a README explaining that this repo provides GitOps manifests for an OKD homelab using Argo CD. Assume IdP at https://id.tickell.us (single hostname, split-DNS). Include folder structure and rollout steps.”*

- **OIDC OAuth for OKD:**  
  *“Generate OpenShift OAuth CR YAML to use Keycloak OIDC at https://id.tickell.us/realms/tickell. Include clientID/secret placeholders and scopes openid, email, profile.”*

- **Argo App of Apps:**  
  *“Write an Argo CD Application manifest that points to ./clusters/okd-home/apps.yaml and syncs automatically.”*

- **Nextcloud K8s base:**  
  *“Generate Kubernetes Deployment, Service, and Route for Nextcloud with PVCs (ReadWriteOnce), fitting OKD conventions.”*

- **GitHub Actions CI:**  
  *“Create a GH Actions workflow to build and push Docker images to GHCR with tag stable-<shortsha> and OIDC-based auth if possible.”*

- **SOPS + ESO:**  
  *“Show a SOPS-encrypted Kubernetes Secret using age, and an ExternalSecret that pulls the cleartext at runtime.”*

- **Velero plan:**  
  *“Draft a Velero install/backup/restore plan for OKD SNO. Include restic for PVs and a sample restore.”*

---

## 12) Appendix F — Hostname Conventions

**Proxmox (stars):** `proxima`, `toliman`, `rigil`  
**Samba (samba pioneers):** `rio`, `donga`, `cartola`  
**Podman/OKD (container ships):** **`idealx`** (primary), optional `emma`, `rocinante`

- **Legacy Podman host:** `idealx.home.tickell.us`  
- **IdP URL (single hostname):** `https://id.tickell.us` (split‑DNS)

**Principles**
- One IdP hostname (`id.tickell.us`), split‑DNS, SPN `HTTP/id.tickell.us`.  
- OKD DNS: `api.okd.tickell.us`, `console.okd.tickell.us`, `*.apps.okd.tickell.us`.

---

**Final State (Learning‑first)**  
You will have: Samba + Keycloak stable; OKD installed; Argo CD syncing from `family-gitops`; per‑app repos with CI to GHCR; SOPS/ESO handling secrets; and a clear, testable migration path from Podman on **`idealx`** to OKD — with Copilot guiding you through the authoring in VS Code.
