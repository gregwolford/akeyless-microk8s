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
