Yes, you still benefit from IaC, but now it only needs to manage cloud-side pieces (Cloudflare, DNS, tunnel, zero trust) – not on-prem ER605 ports or VLANs.

Below are patch-style changes you can apply to your existing IAC_CODE.md to reflect the ER605-only design.

Terraform section changes
Update the Terraform intro to make its scope explicit:

text
-## Terraform
+## Terraform

terraform/
├── main.tf # Root composition of modules
├── variables.tf # Input variables
├── outputs.tf # Exported values
├── providers.tf # Provider config (Cloudflare, etc.)
├── modules/
│ ├── cloudflare/
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ └── outputs.tf
│ └── monitoring/
│ ├── main.tf
│ ├── variables.tf
│ └── outputs.tf
└── environments/
├── production/
│ ├── backend.tf
│ └── terraform.tfvars
└── staging/
├── backend.tf
└── terraform.tfvars

text

-**Conventions**:  
-- Terraform ≥ 1.5, always run `terraform fmt -recursive`.  
-- Cloudflare DNS/tunnel managed via `modules/cloudflare`.  
-- Secrets (API tokens, passwords) only via `*.tfvars` or env vars, never hardcoded.  
+**Conventions**:  
+- Terraform ≥ 1.5, always run `terraform fmt -recursive`.  
+- **Only cloud/remote resources are managed here**: Cloudflare DNS, Cloudflare Tunnel, Zero Trust/WAF, external monitoring hooks.[web:154][web:155][web:160]  
+- Home hardware (ER605, Synology, VMs, VLANs, Wi‑Fi, UPS) is configured via the ER605 UI + Synology UI + Ansible, not Terraform.  
+- Secrets (API tokens, passwords) only via `*.tfvars` or env vars, never hardcoded.  
Add a short subsection clarifying the ER605-only topology:

text
### What Terraform does not manage

- No TP-Link ER605 configuration (ports, VLANs, ACLs are manual or via future Ansible).  
- No Synology DSM settings or VM definitions.  
- No local Docker/k3s networking; Terraform only knows service IPs/ports as data to build Cloudflare Tunnel and DNS records.[web:154][web:155][web:160]
Apply order section change
Adjust the “Apply Order” to reflect that physical network is now purely manual/Ansible and Terraform is for Cloudflare only:

text
 ## Apply Order
 
-1. Bootstrap VMs with Ansible.  
-2. Provision external infra with Terraform (Cloudflare, DNS).  
-3. Apply Kubernetes base + overlays to k3s.  
-4. Bring up Docker stacks on VM2 (monitoring, services, security).  
+1. Configure ER605 (WAN, VLANs, DHCP, firewall) and Synology/VMs manually using the router/NAS UI, following the ER605-only network design.  
+2. Bootstrap VMs with Ansible (base OS hardening, packages, Docker, k3s).  
+3. Provision external infra with Terraform (Cloudflare DNS, Cloudflare Tunnel, WAF/Zero Trust, health checks). [web:154][web:155][web:160]  
+4. Apply Kubernetes base + overlays to k3s.  
+5. Bring up Docker stacks on VM2 (monitoring, services, security).  
Optional: new “Network IaC” note
If you want a placeholder for future ER605 automation (likely via Ansible, not Terraform), add:

text
### Network automation (future)

- ER605 configuration is currently **documented + manual**, not fully automated.  
- If TP-Link exposes stable APIs/CLI in future, add an `ansible/roles/er605/` role to template VLANs, ACLs, and backups; keep Terraform focused on Cloudflare and other cloud providers.[web:161]
These edits keep your IaC story clean: Terraform = Cloudflare & cloud, Ansible = VMs/OS, ER605 = manual but documented, matching your ER605-only decision while still following homelab IaC best practices.​