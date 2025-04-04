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
  STATIC_IP=34.56.78.90
  GATEWAY_CREDENTIALS_SECRET=access-key
  GATEWAY_ACCESS_ID=...
  GATEWAY_ACCESS_KEY=...
  ```


---

## 🔐 How to Create and Use a Google Cloud Service Account Key

This section walks you through creating a service account in Google Cloud and obtaining a credentials JSON file used by the automation scripts.

### Step 1: Open the IAM & Admin Console

Visit: [https://console.cloud.google.com/iam-admin/serviceaccounts](https://console.cloud.google.com/iam-admin/serviceaccounts)

Make sure the correct GCP **project is selected** in the top bar.

---

### Step 2: Create a Service Account

1. Click **“Create Service Account”**
2. Enter:
   - **Service account name:** e.g., `akeyless-deployer`
   - **Service account ID:** leave default or customize
3. Click **Create and Continue**

#### Grant access (roles):

Add these roles:
- `Compute Admin`
- `Service Account User`
- *(Optional: `Kubernetes Engine Admin` if using GKE)*

Click **Continue** and then **Done**

---

### Step 3: Create and Download the Key

1. Click your new service account in the list
2. Go to the **“Keys”** tab
3. Click **“Add Key” > “Create new key”**
4. Choose **JSON** format and click **Create**

Your browser will download the key file, e.g., `akeyless-deployer-abc123.json`.

---

### Step 4: Store the Key and Update the Config

Move the key file to a secure location, and update this line in `config/config.properties`:

```properties
GCLOUD_CREDENTIALS_JSON=/absolute/path/to/akeyless-deployer-abc123.json
```

This will be used in the `create_vm.sh` script for authentication.

---

### Step 5: Test Authentication (Optional)

Run the following to confirm your credentials work:

```bash
gcloud auth activate-service-account --key-file=/path/to/key.json
gcloud config set project your-project-id
gcloud compute instances list
```

If you see a list of VMs or no error, it worked!

---

## 🔐 Required IAM Permissions for the Service Account

| Role Name            | Role ID                      | Purpose                                       |
|----------------------|------------------------------|-----------------------------------------------|
| Compute Admin        | roles/compute.admin          | To create/manage VM instances and IPs         |
| Service Account User | roles/iam.serviceAccountUser | To allow using the service account itself     |
| Viewer (recommended) | roles/viewer                 | Read-only access to most GCP resources        |

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

## Troubleshooting

- **Check the pods:**
```bash
kubectl get pods -n akeyless
```
If they contain a createconfig error rather than running or pending, you likely have an access-key issue. Check the pod by running:

```bash
kubectl describe pod <pod name> -n akeyless
```
 - **Test the IP:**
 ```bash
curl -vk https://<your-ip>.sslip.io
 ```
 Make sure that it works internally and externally. If it's not available externally, you may need to patch the daemonset to use hostNetwork: true

Check Status
```bash
microk8s kubectl get ingress -n akeyless
```
Your ingress should now show the external address.

- **Ingress unreachable:** Make sure the ingress address reflects your static IP, and `hostNetwork: true` is set in your ingress controller deployment. To test:
 ```bash
 kubectl describe ingress akl-gcp-gw-akeyless-gateway -n akeyless
 ```
 If the IP address is wrong, update the gateway-values.yaml file and run:

 ```bash
 helm upgrade --install akl-gcp-gw akeyless/akeyless-gateway -n akeyless -f k8s/gateway-values
.yaml
```

- **TLS not issued:** Confirm your cert-manager and ACME challenge solvers are installed and working properly.
- **CreateContainerConfigError:** Verify the access-key secret exists and contains `gateway-access-key`.

## License

MIT