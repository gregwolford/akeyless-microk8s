# Akeyless Unified Gateway Deployment on GCP with Microk8s

This repository helps automate the deployment of the Akeyless Unified Gateway on a GCP Virtual Machine using Microk8s and Helm. The installation is script-driven and fully configurable. You'll be able to provision the VM, deploy the gateway, and validate the setup with minimal effort.

## Repository Structure

```
.
├── README.md
├── .gitignore
├── config
│   └── config.properties            # Configuration variables (do not commit)
├── scripts
│   ├── create_vm.sh                 # Creates GCP VM and static IP
│   ├── post_setup.sh                # Installs Microk8s, Helm, Akeyless Gateway
│   ├── validate_installation.sh     # Validates deployment and performs auto-fixes
│   ├── test_gateway.sh              # Tests gateway functionality
│   └── rollback_setup.sh            # Removes all installed components
└── k8s
    ├── gateway-values.yaml
    ├── lets-encrypt-prod-issuer.yml
    ├── nginx-ingress-service.yaml
    ├── pv.yml
    └── storageclass.yml
```

## Prerequisites

- **GCP CLI (gcloud)**: [Install here](https://cloud.google.com/sdk)
- **A GCP Project** with proper IAM roles (see below)
- **SSH access** and permission to use `gcloud compute ssh`
- **Bash shell**

## 🔐 How to Create and Use a Google Cloud Service Account Key

1. Visit: [IAM Console](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. Create a new service account
3. Assign these roles:
   - Compute Admin
   - Service Account User
   - Viewer
4. Generate and download a JSON key
5. Update `config/config.properties`:

```properties
GCLOUD_CREDENTIALS_JSON=<path to credentials key>
```

## 🔐 Required IAM Permissions for the Service Account

| Role Name            | Role ID                      | Purpose                                       |
|----------------------|------------------------------|-----------------------------------------------|
| Compute Admin        | roles/compute.admin          | To create/manage VM instances and IPs         |
| Service Account User | roles/iam.serviceAccountUser | To allow using the service account itself     |
| Viewer               | roles/viewer                 | Read-only access to most GCP resources        |

## Setup Instructions

### 1. Configure the Environment

1. Clone this repository or extract the archive.
2. Edit `config/config.properties` with your environment:

```properties
PROJECT_ID=<your-gcp-project-id>
ZONE=us-central1-c
REGION=us-central1
STATIC_IP_NAME=my-gateway-ip
INSTANCE_NAME=my-microk8s-vm
MACHINE_TYPE=n1-standard-1
IMAGE_FAMILY=debian-11
GCLOUD_CREDENTIALS_JSON=/path/to/your-key.json

GATEWAY_ACCESS_ID=<akeyless-access-id>
GATEWAY_CREDENTIALS_SECRET=access-key
GATEWAY_ACCESS_KEY=<your_akeyless_access_key_here>
```

### 2. Provision the GCP VM

```bash
cd /path/to/akeyless-gateway-deployment
chmod +x scripts/create_vm.sh
./scripts/create_vm.sh
```

This will:
- Reserve and assign a static external IP
- Create a new GCP VM with that IP
- Write logs to your terminal for auditing

### 3. Transfer Files to the VM and Connect

You can transfer all required files in one command:

```bash
gcloud compute scp --zone=<ZONE>   --recurse k8s config/config.properties scripts/post_setup.sh scripts/test_gateway.sh   scripts/validate_installation.sh scripts/rollback_setup.sh <INSTANCE_NAME>:~
```

Then SSH into the VM:

```bash
gcloud compute ssh <INSTANCE_NAME> --zone=<ZONE>
```

### 4. Run the Post-Setup Script

```bash
chmod +x post_setup.sh
./post_setup.sh
```

This will:
- Install Microk8s and Docker
- Add `kubectl` and `helm` aliases
- Install cert-manager CRDs and Let's Encrypt issuer
- Apply ingress + volume definitions
- Wait for an external IP and convert it to `sslip.io`
- Patch your `gateway-values.yaml` file
- Install the Akeyless Gateway via Helm
- Log all output to `/var/log/akeyless-post-setup-<timestamp>.log`

🚨 **Important:**
If you receive a permissions error such as:
```
Insufficient permissions to access MicroK8s.
You can either try again with sudo or add the user gwolford to the 'microk8s' group:
    sudo usermod -a -G microk8s <username>
    sudo chown -R gwolford ~/.kube
```
You must run the sudo commands, log out and log back in (or restart your terminal session) for group changes to take effect. Then restart post_setup.sh

### 5. Validate and Test the Deployment

Run the validation script to check installation health:

```bash
chmod +x validate_installation.sh
./validate_installation.sh
```

✅ This script can detect and automatically fix common permission issues such as missing group memberships or socket access errors.

Run the gateway test script to confirm the gateway is reachable:

```bash
chmod +x test_gateway.sh
./test_gateway.sh
```

### 🔄 Optional: Roll Back the Environment

```bash
chmod +x rollback_setup.sh
./rollback_setup.sh
```

This removes:
- Gateway, ingress, cert-manager resources
- Helm config and aliases
- Microk8s and Docker

---

## 🔍 Troubleshooting

### Ingress IP doesn’t match STATIC_IP
- Make sure `STATIC_IP` in `config.properties` matches what’s shown in:
  ```bash
  microk8s kubectl get svc -n ingress
  ```
- `post_setup.sh` will log a warning if they differ.

### Missing or Unavailable Services
- Check that Microk8s is ready:
  ```bash
  microk8s status --wait-ready
  ```
- Restart services or view logs:
  ```bash
  sudo journalctl -u snap.microk8s.daemon-apiserver
  ```

### Verify the Gateway Secret
```bash
microk8s kubectl get secret $GATEWAY_CREDENTIALS_SECRET -o yaml
```

---

## License
Specify your license here.
