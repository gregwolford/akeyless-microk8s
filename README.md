# Akeyless Unified Gateway Deployment on GCP with Microk8s

This repository automates the deployment of the Akeyless Unified Gateway on a GCP Virtual Machine using MicroK8s and Helm. You'll be able to provision the VM, install dependencies, deploy the gateway, and verify it with minimal effort.

## Repository Structure

```
.
├── README.md
├── config
│   └── config.properties           # Your deployment configuration (excluded from repo)
├── k8s
│   ├── gateway-values.yaml         # Helm values file for Akeyless Gateway
│   └── *.yaml                      # Other Kubernetes resources (issuer, ingress, PVC, etc)
└── scripts
    ├── create_vm.sh                # Provisions VM with static IP
    ├── 01_pre_docker_setup.sh      # Installs Docker and prepares group permissions
    ├── 02_post_docker_setup.sh     # Installs MicroK8s, Helm, and deploys Gateway
    ├── test_gateway.sh             # Tests the running gateway instance
    ├── validate_installation.sh    # Validates pod and ingress readiness
    └── rollback_setup.sh           # Fully removes all installed components
```

## Prerequisites

- GCP account with permission to create VMs and static IPs
- Google Cloud CLI (`gcloud`) installed and authenticated
- Configured `config/config.properties` with the following:
  ```properties
  STATIC_IP=34.56.141.95
  GATEWAY_CREDENTIALS_SECRET=access-key
  GATEWAY_ACCESS_ID=...
  GATEWAY_ACCESS_KEY=...
  ```

## Deployment Instructions

### 1. Create the VM

```bash
./scripts/create_vm.sh
```

This allocates the static IP and provisions a VM in your chosen region.

### 2. SSH into the VM

```bash
gcloud compute ssh my-microk8s-vm --zone us-central1-c
```

### 3. Run the Docker Setup

```bash
./scripts/01_pre_docker_setup.sh
```

> Follow the instructions to re-run the sudo group setup and then log out and log back in.

### 4. Run the Post-Docker Setup

```bash
./scripts/02_post_docker_setup.sh
```

This step installs MicroK8s, Helm, and deploys the Akeyless Gateway.

### 5. Test the Gateway

```bash
./scripts/test_gateway.sh
```

If successful, you should be able to access your gateway at `https://<STATIC_IP>.sslip.io`.

### 6. Validate the Installation

```bash
./scripts/validate_installation.sh
```

This confirms pod readiness and TLS certificate status.

## Rolling Back

To remove the full setup (gateway, Helm release, volumes, secrets):

```bash
./scripts/rollback_setup.sh
```

## Troubleshooting

- **Ingress unreachable:** Make sure the ingress address reflects your static IP, and `hostNetwork: true` is set in your ingress controller deployment.
- **TLS not issued:** Confirm your cert-manager and ACME challenge solvers are installed and working properly.
- **CreateContainerConfigError:** Verify the access-key secret exists and contains `gateway-access-key`.

## License

MIT