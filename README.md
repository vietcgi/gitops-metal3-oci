# GitOps Metal3 OCI

A fully automated, self-bootstrapping bare metal cloud using **Metal3/Ironic** running on **Oracle Free Tier**.

**Cost: $0.00/month** - Uses only Always Free resources.

## Features

- **100% Free** - Runs entirely on Oracle Cloud Always Free tier
- **100% GitOps** - All configuration stored in Git, changes via pull requests
- **Zero Secrets** - Uses OIDC federation for passwordless authentication
- **Cross-Platform** - Bootstrap from any browser via OCI Cloud Shell
- **Bare Metal Ready** - Provision physical servers at your colo/home lab using Metal3
- **Production Grade** - K3s, Cilium, Flux, Cluster API, and more

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                             │
│                   (Single Source of Truth)                           │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ OIDC (passwordless)
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Oracle Cloud Free Tier ($0/month)                 │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │         Control Plane VM (ARM A1.Flex - 4 CPU, 24GB)        │   │
│   │                                                              │   │
│   │   K3s │ Cilium │ Flux │ Metal3/Ironic │ CAPI │ Tailscale   │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Tailscale VPN
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Your Bare Metal Servers                           │
│                                                                      │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│   │ Colo Server  │  │ Home Server  │  │ Edge Device  │              │
│   │ (BareMetalHost) │ (BareMetalHost) │ (BareMetalHost) │              │
│   └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Oracle Cloud account ([sign up free](https://www.oracle.com/cloud/free/))
- GitHub account
- Tailscale account ([sign up free](https://tailscale.com/))

### Bootstrap (5 minutes)

1. **Fork this repository** to your GitHub account

2. **Open OCI Cloud Shell:**
   - Log into [Oracle Cloud Console](https://cloud.oracle.com)
   - Click the Cloud Shell icon (>_) in the top right

3. **Run the bootstrap:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/YOUR_USER/gitops-metal3-oci/main/bootstrap.sh | bash
   ```

4. **Follow the prompts** for:
   - Region selection
   - GitHub repository URL
   - Tailscale auth key
   - Domain name (optional)

5. **Done!** Your control plane is running.

## What Gets Deployed

### Control Plane (Oracle Free Tier)

| Component | Purpose |
|-----------|---------|
| **K3s** | Lightweight Kubernetes |
| **Cilium** | eBPF networking, load balancing, ingress |
| **Flux CD** | GitOps continuous deployment |
| **Metal3/Ironic** | Bare metal provisioning (OpenStack Ironic) |
| **Baremetal Operator** | Kubernetes-native BareMetalHost management |
| **Cluster API** | Declarative cluster lifecycle management |
| **Tailscale** | VPN mesh to colo/home lab |
| **cert-manager** | TLS certificate automation |
| **Sealed Secrets** | GitOps-safe secret management |

### Free Tier Resources Used

| Resource | Limit | Usage |
|----------|-------|-------|
| ARM VM (A1.Flex) | 4 OCPU, 24GB | 4 OCPU, 24GB (control plane) |
| Storage | 200 GB | 200 GB |
| Bandwidth | 10 TB/mo | Minimal |

**Monthly cost: $0.00**

## Adding Bare Metal Servers

1. **Create BMC credentials secret:**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: my-server-bmc
     namespace: baremetal-operator-system
   type: Opaque
   stringData:
     username: admin
     password: your-bmc-password
   ```

2. **Register BareMetalHost** in `metal3/hosts/`:
   ```yaml
   apiVersion: metal3.io/v1alpha1
   kind: BareMetalHost
   metadata:
     name: my-server
     namespace: baremetal-operator-system
   spec:
     bmc:
       address: ipmi://192.168.1.100
       credentialsName: my-server-bmc
     bootMACAddress: "00:11:22:33:44:55"
     bootMode: UEFI
     online: true
     image:
       url: https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
       checksum: https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS
       checksumType: sha256
       format: qcow2
   ```

3. **Apply and watch** the server get provisioned automatically

## Metal3 vs Tinkerbell

This project uses Metal3 (Ironic-based) for bare metal provisioning:

| Aspect | Metal3/Ironic | Tinkerbell |
|--------|---------------|------------|
| CRD | BareMetalHost | Hardware, Template, Workflow |
| Boot | Ironic PXE/iPXE | Smee + HookOS |
| BMC | Native IPMI/Redfish/iDRAC | Rufio |
| Lifecycle | Cluster API integration | Custom workflows |
| Community | OpenStack/CNCF | Equinix Metal |

## GitHub Actions CI/CD (OIDC - No Static Secrets)

This project uses **OIDC (OpenID Connect)** for passwordless authentication from GitHub Actions to Oracle Cloud.

**Setup (after bootstrap):**

Add these as **GitHub Repository Secrets**:

| Secret | Value |
|--------|-------|
| `TF_VAR_TENANCY_OCID` | Your tenancy OCID |
| `TF_VAR_COMPARTMENT_OCID` | Your compartment OCID |
| `TF_VAR_REGION` | e.g., `us-ashburn-1` |
| `TF_VAR_USER_OCID` | Your user OCID |
| `TF_VAR_FINGERPRINT` | API key fingerprint |
| `TF_VAR_PRIVATE_KEY` | API private key content |
| `TF_VAR_SSH_PUBLIC_KEY` | SSH public key for VM access |

## Directory Structure

```
gitops-metal3-oci/
├── bootstrap.sh           # One-command setup
├── terraform/             # OCI infrastructure
├── kubernetes/            # Flux-managed K8s manifests
│   ├── infrastructure/   # Core components
│   │   └── metal3/       # Ironic, BMO, CAPI
│   └── apps/             # Your applications
├── metal3/               # Bare metal configs
│   ├── hosts/            # BareMetalHost definitions
│   └── secrets/          # BMC credentials (sealed)
└── boot-media/           # iPXE boot image builder
```

## Documentation

- [Architecture](docs/architecture.md)
- [Adding Bare Metal](docs/adding-bare-metal.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Metal3 Documentation](https://metal3.io/documentation.html)
- [Cluster API Book](https://cluster-api.sigs.k8s.io/)

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- [Metal3](https://metal3.io/) - Bare metal provisioning for Kubernetes
- [OpenStack Ironic](https://wiki.openstack.org/wiki/Ironic) - Bare metal service
- [K3s](https://k3s.io/) - Lightweight Kubernetes
- [Cilium](https://cilium.io/) - eBPF networking
- [Flux CD](https://fluxcd.io/) - GitOps toolkit
- [Tailscale](https://tailscale.com/) - Zero-config VPN
- [Cluster API](https://cluster-api.sigs.k8s.io/) - Declarative cluster management
