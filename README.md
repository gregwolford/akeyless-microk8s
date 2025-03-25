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
# Static IP configuration
STATIC_IP_NAME=my-gateway-ip
REGION=us-central1

# Akeyless Access Key (used for authentication)
GATEWAY_ACCESS_KEY=<your_akeyless_access_key_here>
   PROJECT_ID=my-gcp-project
   ZONE=us-central1-a
   MACHINE_TYPE=n1-standard-1
   IMAGE_FAMILY=debian-10
   INSTANCE_NAME=my-microk8s-vm

   # Akeyless Gateway Settings
   GATEWAY_ACCESS_ID=p-ia0cysqaq6dsam
   GATEWAY_CREDENTIALS_SECRET=access-key

   # Add any additional configuration as needed...
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
   The script sets your active GCP project and creates the VM using parameters from the config file. A startup script is embedded to install Microk8s automatically.

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
     If you prefer a graphical FTP/SFTP client, ensure that your account has the appropriate permissions and that firewall rules allow SFTP access. Refer to your client’s documentation for detailed instructions.

2. **SSH into Your VM:**  
   Use the gcloud CLI for a simple connection:
   ```bash
   gcloud compute ssh [INSTANCE_NAME] --zone=[ZONE]
   ```

### 4. Run the Post-Setup Script on the VM

1. **Set Execution Permissions and Open the Script:**  
   Once connected to your VM:
   ```bash
   chmod +x ~/post_setup.sh
   ```
   You can view or edit the script using a terminal editor like `nano`:
   ```bash
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

After the post-setup script finishes, verify that all pods and services are running:
```bash
sudo microk8s kubectl get all
```

## Troubleshooting Common Issues

### FTP/SCP Transfer Problems
- **Insufficient Permissions:**  
  - Ensure that you have set the correct file permissions using `chmod +x [filename]`.
  - Check that your GCP firewall rules allow the transfer protocols (SCP/SFTP) you are using.
  - If using an FTP client, verify your authentication credentials and connection settings.

- **File Not Found Errors:**  
  - Confirm that you are specifying the correct paths both locally and on the VM.
  - Use the `ls` command on the VM to verify the files are present in the expected directories.

### GCP-Specific Issues
- **Insufficient GCP Permissions:**  
  - Make sure your GCP account has the required roles (e.g., Compute Instance Admin) to create and manage VM instances.
  - If you run into errors during VM creation, check the GCP Console for more detailed error messages.

- **VM Startup Issues:**  
  - If Microk8s is not installing correctly on VM startup, SSH into the VM and check the logs using:
    ```bash
    sudo journalctl -u snap.microk8s.daemon-apiserver
    ```
  - You may also verify the status of Microk8s:
    ```bash
    sudo microk8s status --wait-ready
    ```

### YAML Deployment Issues
- **YAML File Errors:**  
  - Ensure that the YAML files have been correctly copied to the VM.
  - Use `sudo microk8s kubectl apply -f <filename>` individually to isolate any errors and then inspect the output.

## Additional Resources

- [GCP Documentation](https://cloud.google.com/docs)
- [Microk8s Documentation](https://microk8s.io/docs)
- [Akeyless Documentation](https://docs.akeyless.io)

## License

Specify your license information here.

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


---

## 🔑 Verifying the Akeyless Access Key Secret
After the post-setup script runs, you can verify that the secret was created correctly with:

```bash
sudo microk8s kubectl get secret $GATEWAY_CREDENTIALS_SECRET -o yaml
```

You should see `gateway-access-key` in the `data` section (base64-encoded).