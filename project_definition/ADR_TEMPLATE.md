# Architecture Decision Record (ADR) Template

**Title:** [Short descriptive title, e.g. "Adopt Keycloak as Primary Identity Provider"]  
**Status:** Proposed / Accepted / Superseded / Deprecated  
**Date:** YYYY-MM-DD  
**Context:**  
Describe the background and reasoning behind this decision. What problem are we solving? What constraints exist (technical, operational, financial)? Include relevant alternatives considered.

**Decision:**  
Summarize the key choice and the rationale for it. Include links to any supporting documentation or issues.

**Consequences:**  
Explain the impact of this decision, both positive and negative. What becomes easier, and what potential downsides or trade-offs exist?

**Related Decisions:**  
Link to other ADRs that are related, superseded, or dependent.

---

## Example

**Title:** Migrate from Podman to OKD for Container Orchestration  
**Status:** Accepted  
**Date:** 2025-11-02  
**Context:** We currently run self-hosted containers on `idealx.home.tickell.us` (Podman). Future goals include GitOps automation, declarative configuration, and family learning of CI/CD concepts.  
**Decision:** Deploy OKD (Single Node OpenShift) on Proxmox with Argo CD and GitHub Actions for GitOps and CI.  
**Consequences:** Increases complexity but enables scalability, visibility, and DevOps learning.  
**Related Decisions:** ADR-001 (Adopt Keycloak as IDP), ADR-002 (Use Split-DNS on id.tickell.us).
