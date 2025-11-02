# COPILOT_CONTEXT.md — Priorities, Invariants, and Non‑Goals

<!-- COPILOT: Read this first before suggesting anything. -->

## 🎯 Priorities
1) **Identity Experience First** — Make SSO seamless on Podman (Samba + Keycloak + MDM).  
2) **Platform Second** — Migrate to OKD + GitOps only after Phase 1 is bulletproof.  
3) **Clarity Over Complexity** — Prefer explicit, minimal examples I can type by hand.

## 🔒 Invariants (Do Not Change)
- **IdP Hostname:** Only **`id.tickell.us`** (single hostname).  
- **DNS:** **Split‑horizon** — internal resolves to LAN IP, external to Cloudflare proxy.  
- **Kerberos:** SPN **`HTTP/id.tickell.us`**; no alternate SPNs or hostnames.  
- **Realm:** `HOME.TICKELL.US`; DCs are `rio.home.tickell.us` and `donga.home.tickell.us`.  
- **MDM is essential in Phase 1:** Deploy Kerberos SSO Extension via ManageEngine for Apple devices.

## 🧭 Phase Boundaries
- **Phase 1 (Podman):** Keycloak, Caddy, and first apps on Podman. **No Kubernetes/Helm/Operators.**  
- **Phase 2 (OKD/GitOps):** Introduce OKD, Argo CD, CI/CD, SOPS/ESO, and migrate apps.  
- **Entra:** Optional; can be done after Phase 1 and before/after Phase 2.

## ⛔ Non‑Goals
- Don’t invent `id.home.tickell.us`.  
- Don’t suggest ADFS or random IdPs.  
- Don’t push OKD/GitOps while Phase 1 isn’t done.  
- Don’t store cleartext secrets in Git (use SOPS/ESO later).

## ✅ Useful Prompts (for inline assistance)
- *“Create Keycloak OIDC client config for Nextcloud with issuer https://id.tickell.us/realms/tickell and scopes openid,email,profile.”*  
- *“Write a ManageEngine Kerberos SSO Extension profile for realm HOME.TICKELL.US with KDCs rio,donga.”*  
- *“Generate a Caddy v2 config to serve Keycloak at id.tickell.us with Let’s Encrypt and proxy headers preserved.”*  
- *“After Phase 1, draft OpenShift OAuth CR to use Keycloak OIDC at https://id.tickell.us/realms/tickell.”*

## 🧪 Definition of Done (per phase)
- **Phase 1:** Internal Kerberos SSO works; external passkeys/MFA works; apps behind OIDC on Podman.  
- **Phase 2:** OKD OAuth via Keycloak; Argo syncs; apps live at *.apps.okd.tickell.us with CI→CD flow.

---

Thanks! Please keep suggestions minimal, explicit, and consistent with these constraints.
