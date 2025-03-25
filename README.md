# Akeyless Unified Gateway Deployment on GCP with Microk8s

This repository provides a set of scripts and configuration files to help you set up a Google Cloud Platform (GCP) Virtual Machine with Microk8s and deploy an Akeyless unified gateway along with required Kubernetes resources. The package is designed so that end users can simply provide or update configuration variables, then run the provided scripts. It also contains troubleshooting sections for common issues.

## Repository Structure

```
.
├── README.md                     # This file: documentation and troubleshooting instructions
├── .gitignore                    # Excludes sensitive files from GitHub (e.g., config.properties)
├── config
│   └── config.properties         # Contains environment and sensitive configuration variables (do not commit)
├── scripts
│   ├── create_vm.sh              # Script to provision the GCP VM using gcloud CLI
│   └── post_setup.sh             # Script to install Microk8s and deploy the YAML files after SSHing into the VM
└── k8s
    ├── gateway-values.yaml       # Akeyless gateway configuration
    ├── lets-encrypt-prod-issuer.yml  # Let's Encrypt ClusterIssuer definition
    ├── nginx-ingress-service.yaml    # Nginx Ingress Service definition
    ├── pv.yml                        # Persistent Volume definition
    └── storageclass.yml              # StorageClass definition
```

## Prerequisites

- **GCP CLI (gcloud):** Install and authenticate the [Google Cloud SDK](https://cloud.google.com/sdk).
- **SSH Client:** To connect to your VM (gcloud provides a wrapper command).
- **Bash Shell:** The scripts are written in bash.
- **Basic File Transfer Tools:** (e.g., `scp` or `gcloud compute scp`) if you need to manually copy files into your VM.

## Setup Instructions

### 1. Configure the Environment

1. **Clone or Extract the Package:**  
   Place the **akeyless-gateway-deployment** folder on your local machine.

2. **Edit Configuration:**  
   Open `config/config.properties` in your favorite text editor and set your project-specific variables. For example:

```properties
# GCP Settings
PROJECT_ID=microk8s-454218
ZONE=us-central1-a
MACHINE_TYPE=n1-standard-1
IMAGE_FAMILY=debian-11
INSTANCE_NAME=my-microk8s-vm

# Static IP configuration
STATIC_IP_NAME=my-gateway-ip
REGION=us-central1

# Akeyless Gateway Settings
GATEWAY_ACCESS_ID=p-ia0cysqaq6dsam
GATEWAY_CREDENTIALS_SECRET=access-key
GATEWAY_ACCESS_KEY=<your_akeyless_access_key_here>

# Path to your GCP service account credentials JSON file
GCLOUD_CREDENTIALS_JSON=/home/gwolford/keys/microk8s-454218-e90180037e1f.json
```

**Note:** This file is listed in `.gitignore` so it will not be committed to GitHub.

### 2. Provision the GCP VM

1. **Open a Terminal and Navigate to the Package Root:**  
   ```bash
   cd /path/to/akeyless-gateway-deployment
   ```

2. **Run the VM Provisioning Script:**  
   This script reads the configuration and creates a new GCP VM.
   - Reserves a **static external IP** if it doesn't already exist
   - Assigns the static IP to the VM for consistency
   - Uses the static IP with `sslip.io` for TLS certificate provisioning

   ```bash
   chmod +x scripts/create_vm.sh
   ./scripts/create_vm.sh
   ```

3. **Troubleshooting – Insufficient Permissions:**  
   - If you get permission errors (e.g., “Permission denied” when running the script), check that your user has execution rights:
     ```bash
     chmod +x scripts/create_vm.sh
     ```
   - Ensure your GCP account has the necessary permissions to create VM instances. Visit the [IAM & Admin page](https://console.cloud.google.com/iam-admin/iam) on the GCP Console to verify.

### 3. Transfer Files and Connect to the VM

1. **Transferring the YAML Files and Post-Setup Script:**  
   There are two ways to get your files into the VM:
   - **Using gcloud compute scp:**  
     For example, to copy the entire `k8s` directory:
     ```bash
     gcloud compute scp --recurse k8s [INSTANCE_NAME]:~/k8s --zone=[ZONE]
     ```
     And similarly, copy the `scripts/post_setup.sh`:
     ```bash
     gcloud compute scp scripts/post_setup.sh [INSTANCE_NAME]:~/post_setup.sh --zone=[ZONE]
     ```
   - **Using FTP/SFTP Clients:**  
     If you prefer a graphical FTP/SFTP client, ensure that your account has the appropriate permissions and that firewall rules allow SFTP access.

2. **SSH into Your VM:**  
   ```bash
   gcloud compute ssh [INSTANCE_NAME] --zone=[ZONE]
   ```

### 4. Run the Post-Setup Script on the VM

1. **Set Execution Permissions and Open the Script:**  
   ```bash
   chmod +x ~/post_setup.sh
   nano ~/post_setup.sh
   ```

2. **Execute the Post-Setup Script:**  
   This script will enable necessary Microk8s add-ons and deploy your Kubernetes resources:
   - Replaces the placeholder domain in `gateway-values.yaml` with your actual static IP (e.g., `34.56.78.90.sslip.io`)
   - Creates a Kubernetes secret using your access key (`GATEWAY_ACCESS_KEY`) and names it based on `GATEWAY_CREDENTIALS_SECRET`

   ```bash
   ./post_setup.sh
   ```

### 5. Verify the Deployment

```bash
sudo microk8s kubectl get all
```

## Troubleshooting Common Issues

### FTP/SCP Transfer Problems

- Ensure that you have set the correct file permissions using `chmod +x [filename]`.
- Check that your GCP firewall rules allow the transfer protocols (SCP/SFTP).
- Use `ls` on the VM to verify files landed correctly.

### GCP-Specific Issues

- Make sure your GCP account has the correct roles:
  - `Compute Admin`
  - `Service Account User`
  - `Viewer`
- Run `gcloud config list` and `gcloud auth list` to verify your identity and project settings.

### Microk8s & YAML Deployment Issues

- Check Microk8s status:
  ```bash
  sudo microk8s status --wait-ready
  ```
- View logs:
  ```bash
  sudo journalctl -u snap.microk8s.daemon-apiserver
  ```

## 🔐 How to Create and Use a Google Cloud Service Account Key

Visit: [https://console.cloud.google.com/iam-admin/serviceaccounts](https://console.cloud.google.com/iam-admin/serviceaccounts)

1. Create a new service account
2. Assign these roles:
   - `Compute Admin`
   - `Service Account User`
   - `Viewer`
3. Generate and download a **JSON key**
4. Set the key path in `config/config.properties`:
   ```properties
   GCLOUD_CREDENTIALS_JSON=/absolute/path/to/key.json
   ```

### 🔑 Verifying the Akeyless Access Key Secret

```bash
sudo microk8s kubectl get secret $GATEWAY_CREDENTIALS_SECRET -o yaml
```

---

## 🔐 Required IAM Permissions for the Service Account

| Role Name              | Role ID                    | Purpose                                      |
|------------------------|----------------------------|----------------------------------------------|
| Compute Admin          | `roles/compute.admin`      | To create/manage VM instances and IPs       |
| Service Account User   | `roles/iam.serviceAccountUser` | To allow using the service account itself   |
| Viewer (recommended)   | `roles/viewer`             | Read-only access to most GCP resources       |
