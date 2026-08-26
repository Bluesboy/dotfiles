Audit Kubernetes manifests in this repository.

Focus:
- dangerous RBAC
- missing resource requests/limits
- unsafe Gateway/Ingress exposure
- missing PDBs for critical workloads
- missing topology spread or anti-affinity
- secret leakage in manifests
- unsafe ExternalSecret / SecretStore patterns

Rules:
- Do not edit files.
- Return findings grouped by severity.
- Include file paths.
- For every finding, provide a minimal fix.
