# GitOps Metal Foundry - Implementation Plan

## Vision

A fully automated, self-bootstrapping bare metal cloud that:
- Runs the control plane **100% FREE** on Oracle Cloud Free Tier (strict enforcement)
- Provisions **real bare metal** machines at colocation/home lab
- Is **100% GitOps** - all changes through Git, no manual intervention
- Has **zero secrets in the repo** - uses OIDC federation for authentication
- **Cross-platform bootstrap** - works from any browser via OCI Cloud Shell
- Uses **Cilium** for eBPF-based networking

## Cost Guarantee

**STRICT FREE TIER ONLY** - This project will NEVER incur charges:
- Hard-coded Always Free shapes only (VM.Standard.E2.1.Micro, VM.Standard.A1.Flex)
- Terraform validation rejects non-free resources
- No "upgrade" paths that could cost money
- If free tier capacity unavailable, fails gracefully (never falls back to paid)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                             │
│                   (Single Source of Truth)                           │
│                                                                      │
│   📁 terraform/        - OCI infrastructure as code                  │
│   📁 tinkerbell/       - Hardware definitions, templates, workflows  │
│   📁 kubernetes/       - K3s manifests, Helm charts                  │
│   📁 .github/workflows - CI/CD pipelines                             │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ OIDC Federation
                                   │ (No static secrets)
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Oracle Cloud Free Tier                            │
│                    (Always Free - $0/month)                          │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                  Virtual Cloud Network                       │   │
│   │                                                              │   │
│   │   ┌─────────────────────────────────────────────────────┐   │   │
│   │   │           Control Plane VM (AMD, 1GB RAM)           │   │   │
│   │   │                                                      │   │   │
│   │   │   🔧 K3s (lightweight Kubernetes)                   │   │   │
│   │   │   🔧 Tinkerbell Stack (smee, hegel, tink, hook)     │   │   │
│   │   │   🔧 Flux CD (GitOps controller)                    │   │   │
│   │   │   🔧 Tailscale (VPN mesh to colo)                   │   │   │
│   │   │                                                      │   │   │
│   │   └─────────────────────────────────────────────────────┘   │   │
│   │                            │                                 │   │
│   │   ┌────────────────────────┴────────────────────────────┐   │   │
│   │   │        Optional: A1 Flex VMs (ARM, 24GB total)      │   │   │
│   │   │        (Additional K8s workers in cloud)             │   │   │
│   │   └─────────────────────────────────────────────────────┘   │   │
│   │                                                              │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Tailscale VPN Mesh
                                   │ (Secure tunnel)
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Colocation / Home Lab                             │
│                    (Your Physical Servers)                           │
│                                                                      │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│   │  Bare Metal #1   │  │  Bare Metal #2   │  │  Bare Metal #3   │  │
│   │                  │  │                  │  │                  │  │
│   │  PXE Boot ──────────────────────────────────► Tinkerbell     │  │
│   │  Provisioned by  │  │  Provisioned by  │  │  Provisioned by  │  │
│   │  Tinkerbell      │  │  Tinkerbell      │  │  Tinkerbell      │  │
│   │                  │  │                  │  │                  │  │
│   │  Joins K3s as    │  │  Joins K3s as    │  │  Joins K3s as    │  │
│   │  worker node     │  │  worker node     │  │  worker node     │  │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                      │
│   🔌 Local network with DHCP relay to Tinkerbell over Tailscale     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Technology Choices

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Control Plane** | Oracle Free Tier AMD VM | Always free, 1 OCPU, 1GB RAM |
| **Kubernetes** | K3s | Lightest footprint, runs on 512MB RAM, single binary |
| **CNI/Networking** | Cilium | eBPF-based, built-in LB, better for bare metal |
| **Bare Metal Provisioning** | Tinkerbell | Cloud-native, declarative, Kubernetes-native |
| **GitOps** | Flux CD | Lighter than ArgoCD, native Git, CNCF graduated |
| **VPN Mesh** | Tailscale | Zero-config, NAT traversal, free tier (100 devices) |
| **Infrastructure as Code** | Terraform + OCI Provider | Standard, GitOps-friendly |
| **CI/CD** | GitHub Actions | Native, free for public repos, OIDC support |
| **Secrets** | None in repo! | OIDC federation for OCI, Tailscale auth keys via bootstrap |
| **Bootstrap** | OCI Cloud Shell | Cross-platform (browser), already authenticated, free |

---

## Bootstrap Flow

### What the User Does (Cross-Platform via Browser)

```
1. Log into Oracle Cloud Console (cloud.oracle.com)
2. Click the Cloud Shell icon (>_) in the top right
3. Wait for Cloud Shell to start
4. Run ONE command:

   curl -sSL https://raw.githubusercontent.com/vietcgi/gitops-metal-foundry/main/bootstrap.sh | bash

5. Answer a few prompts (region, GitHub repo, Tailscale auth key)
6. Done!
```

**Why Cloud Shell?**
- Works on Linux, Mac, Windows (just needs a browser)
- Already authenticated to OCI (no API keys needed)
- All tools pre-installed (Terraform, OCI CLI, kubectl, git, etc.)
- Free to use, no local setup required

### What bootstrap.sh Does

```
Phase 1: Validate Free Tier
├── Detect available Always Free resources
├── Check region has free tier capacity
├── Fail fast if paid resources would be needed
└── Display cost: $0.00/month guaranteed

Phase 2: Clone & Configure
├── Clone gitops-metal-foundry repo
├── Prompt for GitHub repo URL (for GitOps)
├── Generate SSH keys if needed
└── Configure Terraform variables

Phase 3: Create Infrastructure (Terraform)
├── Create VCN + public/private subnets
├── Create security lists (strict, minimal ports)
├── Create control plane VM (VM.Standard.E2.1.Micro - FREE)
├── Attach block volume (50GB - FREE)
└── Reserve public IP (FREE)

Phase 4: Bootstrap Control Plane (cloud-init)
├── Install K3s (disable flannel, traefik)
├── Install Cilium (eBPF networking + LB)
├── Install Tinkerbell stack
├── Install Flux CD
├── Install Tailscale
└── Configure firewall (iptables)

Phase 5: Setup GitHub OIDC
├── Create OCI Identity Provider for GitHub Actions
├── Create IAM policies (minimal permissions)
├── Test OIDC authentication
└── Verify GitHub Actions can access OCI

Phase 6: GitOps Handoff
├── Flux connects to GitHub repo
├── Initial sync of manifests
├── Verify all components healthy
└── Print success message + next steps

🎉 Your FREE bare metal cloud is ready!
   Cost: $0.00/month (Always Free tier)
   Control plane: https://<public-ip>
   Add bare metal: tinkerbell/hardware/
```

---

## Directory Structure

```
gitops-metal-foundry/
├── bootstrap.sh                    # One-time setup script
├── README.md                       # Project documentation
├── PLAN.md                         # This file
│
├── bootstrap/                      # Bootstrap helper scripts
│   ├── 00-preflight.sh            # Check prerequisites
│   ├── 01-oci-auth.sh             # OCI authentication
│   ├── 02-terraform.sh            # Run Terraform
│   ├── 03-control-plane.sh        # Configure control plane
│   ├── 04-github-oidc.sh          # Setup OIDC federation
│   └── 05-flux-init.sh            # Initialize Flux
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Main configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── versions.tf                # Provider versions
│   │
│   ├── modules/
│   │   ├── vcn/                   # Virtual Cloud Network
│   │   ├── compute/               # VM instances
│   │   ├── iam/                   # IAM policies, OIDC
│   │   └── load-balancer/         # Load balancer
│   │
│   └── environments/
│       └── prod/                  # Production environment
│           ├── terraform.tfvars
│           └── backend.tf
│
├── kubernetes/                     # K8s manifests (Flux manages these)
│   ├── flux-system/               # Flux bootstrap manifests
│   ├── infrastructure/            # Cluster infrastructure
│   │   ├── tinkerbell/           # Tinkerbell Helm release
│   │   ├── tailscale/            # Tailscale operator
│   │   ├── cert-manager/         # TLS certificates
│   │   └── ingress/              # Ingress controller
│   │
│   └── apps/                      # User applications
│       └── .gitkeep
│
├── tinkerbell/                     # Tinkerbell configurations
│   ├── hardware/                  # Hardware definitions
│   │   └── example-server.yaml   # Example bare metal registration
│   │
│   ├── templates/                 # OS installation templates
│   │   ├── ubuntu-24.04.yaml
│   │   ├── flatcar.yaml
│   │   └── talos.yaml
│   │
│   └── workflows/                 # Provisioning workflows
│       └── standard-provision.yaml
│
├── .github/
│   └── workflows/
│       ├── terraform.yaml         # Infra changes
│       ├── flux-sync.yaml         # Manual Flux sync trigger
│       └── hardware-register.yaml # Register new bare metal
│
└── docs/
    ├── architecture.md
    ├── adding-bare-metal.md
    ├── troubleshooting.md
    └── oracle-free-tier-limits.md
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create repository structure
- [ ] Write bootstrap.sh skeleton
- [ ] Create Terraform modules for OCI
  - [ ] VCN module
  - [ ] Compute module (control plane VM)
  - [ ] IAM module (OIDC federation)
- [ ] Test basic infrastructure creation

### Phase 2: Control Plane (Week 2)
- [ ] K3s installation script
- [ ] Tinkerbell Helm chart configuration
- [ ] Flux CD bootstrap
- [ ] Tailscale integration
- [ ] GitHub Actions OIDC workflow

### Phase 3: Bare Metal Integration (Week 3)
- [ ] Tinkerbell hardware registration workflow
- [ ] OS templates (Ubuntu, Flatcar)
- [ ] PXE/iPXE over Tailscale setup
- [ ] K3s worker node auto-join

### Phase 4: GitOps & Polish (Week 4)
- [ ] Full GitOps workflow testing
- [ ] Documentation
- [ ] Example applications
- [ ] Troubleshooting guides

---

## Oracle Free Tier Resources (ALWAYS FREE - $0/month)

**IMPORTANT**: We ONLY use Always Free resources. These never expire and never cost money.

| Resource | Always Free Limit | Our Usage | Cost |
|----------|-------------------|-----------|------|
| AMD VM (E2.1.Micro) | 2 VMs (1/8 OCPU, 1GB each) | 1 VM (control plane) | **$0** |
| ARM A1 VM | 4 OCPUs, 24GB RAM total | Optional cloud workers | **$0** |
| Boot Volume | 200 GB total | 50GB | **$0** |
| Block Volume | Included in 200GB | 50GB data | **$0** |
| Object Storage | 10 GB | TF state + images | **$0** |
| Load Balancer | 1 flexible (10 Mbps) | Ingress (optional) | **$0** |
| Outbound Data | 10 TB/month | Minimal | **$0** |
| VCN/Networking | Unlimited | 1 VCN | **$0** |
| Public IP | 1 reserved | Control plane | **$0** |

**Total Monthly Cost: $0.00**

### Free Tier Shapes (Hard-coded)
```hcl
# These are the ONLY shapes we use - always free
locals {
  free_tier_shapes = {
    amd_micro = "VM.Standard.E2.1.Micro"  # 1/8 OCPU, 1GB RAM
    arm_flex  = "VM.Standard.A1.Flex"      # Up to 4 OCPU, 24GB RAM
  }
}
```

### Capacity Issues
Oracle Free Tier ARM instances are sometimes unavailable (high demand). Our approach:
1. Try AMD micro first (more reliable availability)
2. If ARM needed and unavailable: wait and retry, never fall back to paid
3. Script will clearly indicate "Free tier capacity unavailable, try again later"

---

## Security Model

### No Secrets in Repository
- **OCI Access**: GitHub OIDC federation (workload identity)
- **Tailscale**: Auth key provided during bootstrap, rotated automatically
- **K3s Join Token**: Generated at bootstrap, stored in K8s secret
- **TLS Certs**: cert-manager with Let's Encrypt

### Network Security
- Control plane in private subnet with NAT gateway
- Only ports 80/443/6443 exposed via load balancer
- All colo traffic over encrypted Tailscale tunnel
- OCI Security Lists restrict ingress

---

## Decisions Made

| Decision | Choice | Notes |
|----------|--------|-------|
| **Bootstrap Method** | OCI Cloud Shell | Cross-platform, zero local setup, already authenticated |
| **CNI** | Cilium | eBPF-based, built-in LB, replaces Flannel + MetalLB |
| **Cost Model** | Strict Free Tier | Hard-coded free shapes, fail if unavailable |
| **VPN Mesh** | Tailscale | Free tier (100 devices), zero-config |
| **Terraform State** | OCI Object Storage | Free tier, stays in Oracle ecosystem |
| **Worker OS** | Ubuntu Server | Familiar, flexible, well-supported |
| **Colo Access** | Mixed | Physical (USB iPXE) + Remote (ISO via IPMI) |
| **PXE Boot Method** | Public Tinkerbell + iPXE | Expose boot endpoints via LB, chainload from USB/ISO |
| **DNS** | User's domain | Cloudflare or similar, cert-manager for TLS |
| **Secrets** | Sealed Secrets | Encrypt secrets in Git, decrypt in cluster |
| **Storage** | Local Path Provisioner | Simple, no external dependencies |
| **Ingress** | Cilium Ingress | Built into CNI, no extra component |
| **Monitoring** | Victoria Metrics | Lighter than Prometheus |
| **Backup** | etcd snapshots → OCI Object Storage | Free tier storage |

---

## Complete Component Stack

### Control Plane (Oracle Free Tier)
```
┌─────────────────────────────────────────────────────────────────┐
│  K3s Control Plane (VM.Standard.E2.1.Micro - 1GB RAM)          │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │   Cilium     │ │    Flux      │ │  Tailscale   │            │
│  │   (CNI+LB+   │ │    (GitOps)  │ │  (VPN mesh)  │            │
│  │   Ingress)   │ │              │ │              │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │  Tinkerbell  │ │ cert-manager │ │   Sealed     │            │
│  │  (bare metal │ │ (TLS certs)  │ │   Secrets    │            │
│  │  provision)  │ │              │ │              │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ Local Path   │ │  Victoria    │ │   Backup     │            │
│  │ Provisioner  │ │  Metrics     │ │  Controller  │            │
│  │ (storage)    │ │ (monitoring) │ │  (etcd snap) │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### Bare Metal Provisioning Flow

**For Physical Access Machines (USB Boot):**
```
1. Create iPXE USB stick (one-time, from repo)
   └── Contains: iPXE binary + script pointing to Tinkerbell URL

2. Boot server from USB
   └── BIOS/UEFI → USB → iPXE

3. iPXE fetches boot config from Tinkerbell (public HTTPS)
   └── https://tinkerbell.yourdomain.com/auto.ipxe

4. Tinkerbell serves Hook (in-memory OS)
   └── Downloads kernel + initramfs

5. Hook runs Tinkerbell workflow
   └── Partitions disk
   └── Installs Ubuntu
   └── Configures cloud-init

6. Server reboots into Ubuntu
   └── cloud-init runs
   └── Installs K3s agent
   └── Installs Tailscale
   └── Joins cluster
```

**For Remote-Only Machines (IPMI/BMC):**
```
1. Generate iPXE ISO (one-time, from repo)
   └── Same as USB but in ISO format

2. Mount ISO via IPMI virtual media
   └── iLO / iDRAC / IPMI → Virtual Media → Mount ISO

3. Boot from virtual CD
   └── Same flow as USB from step 3 onwards
```

### GitOps Repository Structure (Updated)

```
gitops-metal-foundry/
├── bootstrap.sh                      # Cloud Shell bootstrap
├── PLAN.md
├── README.md
│
├── terraform/                        # OCI Infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── free-tier.tf                 # Free tier validation
│   └── modules/
│       ├── vcn/
│       ├── compute/
│       ├── iam/
│       └── object-storage/          # For TF state + backups
│
├── kubernetes/                       # Flux-managed manifests
│   ├── flux-system/                 # Flux bootstrap
│   ├── infrastructure/
│   │   ├── sources/                 # Helm repos, Git repos
│   │   ├── cilium/                  # CNI + LB + Ingress
│   │   ├── tinkerbell/              # Bare metal provisioner
│   │   ├── tailscale/               # VPN operator
│   │   ├── cert-manager/            # TLS certificates
│   │   ├── sealed-secrets/          # Secret encryption
│   │   ├── local-path/              # Storage provisioner
│   │   ├── victoria-metrics/        # Monitoring
│   │   └── backup/                  # etcd backup jobs
│   │
│   └── apps/                        # User applications
│       └── .gitkeep
│
├── tinkerbell/                       # Bare metal configs
│   ├── hardware/                    # Machine definitions
│   │   └── example.yaml
│   ├── templates/                   # OS templates
│   │   └── ubuntu-24.04/
│   │       ├── template.yaml
│   │       └── cloud-init.yaml
│   └── workflows/                   # Provisioning workflows
│       └── ubuntu-k3s-worker.yaml
│
├── boot-media/                       # iPXE boot artifacts
│   ├── Makefile                     # Build USB/ISO
│   ├── ipxe-script.ipxe            # Boot script
│   └── README.md                    # Instructions
│
├── .github/workflows/
│   ├── terraform.yaml               # Infra CI/CD
│   ├── validate.yaml                # PR validation
│   └── build-boot-media.yaml        # Build iPXE artifacts
│
└── docs/
    ├── architecture.md
    ├── bootstrap-guide.md
    ├── adding-bare-metal.md
    ├── troubleshooting.md
    └── oracle-free-tier.md
```

---

## Implementation Phases (Detailed)

### Phase 1: Foundation
- [ ] Repository structure + README
- [ ] bootstrap.sh for Cloud Shell
- [ ] Terraform: VCN, Compute, Object Storage, IAM
- [ ] Free tier validation/guardrails
- [ ] GitHub OIDC setup

### Phase 2: Control Plane
- [ ] K3s installation (disable default CNI)
- [ ] Cilium installation + configuration
- [ ] Tailscale installation
- [ ] Flux bootstrap
- [ ] Sealed Secrets controller

### Phase 3: Core Infrastructure
- [ ] cert-manager + Let's Encrypt ClusterIssuer
- [ ] Local Path Provisioner
- [ ] Victoria Metrics (basic)
- [ ] etcd backup CronJob

### Phase 4: Tinkerbell
- [ ] Tinkerbell Helm deployment
- [ ] Public HTTPS exposure via Cilium Ingress
- [ ] Ubuntu 24.04 template + cloud-init
- [ ] K3s worker auto-join workflow
- [ ] iPXE boot media (USB + ISO)

### Phase 5: GitOps & Polish
- [ ] Complete Flux kustomizations
- [ ] GitHub Actions workflows
- [ ] Documentation
- [ ] Testing with real hardware

---

## Next Steps

After plan approval:
1. Create the repository structure
2. Implement bootstrap.sh Phase 0 (prerequisites check)
3. Create Terraform VCN module
4. Iterate through each phase

---

## References

- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [Tinkerbell Documentation](https://tinkerbell.org/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [GitHub OIDC with OCI](https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/workloadidentityconfederationwithoidc.htm)
- [Tailscale](https://tailscale.com/)
