# Akeyless Unified Gateway Deployment on GCP with Microk8s

This package helps you automate the setup of a Microk8s-based Akeyless Gateway on a GCP VM.

...

## 🔐 Required IAM Permissions for the Service Account

To run these scripts successfully, your service account must have the following roles **granted on the target GCP project**:

| Role Name              | Role ID                    | Purpose                                      |
|------------------------|----------------------------|----------------------------------------------|
| Compute Admin          | `roles/compute.admin`      | To create/manage VM instances and IPs       |
| Service Account User   | `roles/iam.serviceAccountUser` | To allow using the service account itself   |
| Viewer (recommended)   | `roles/viewer`             | Read-only access to most GCP resources       |

You can assign these roles in the [IAM Console](https://console.cloud.google.com/iam-admin/iam):

1. Select your project
2. Locate or add your service account (e.g., `your-sa@your-project.iam.gserviceaccount.com`)
3. Click the ✏️ edit icon
4. Click **“Add Another Role”** and select the roles listed above

If you prefer least-privilege access, you may instead create a **custom role** with only the following permissions:
- `resourcemanager.projects.get`
- `compute.instances.*`
- `compute.addresses.*`

> ⚠️ You must perform this as a user with sufficient privileges (e.g., Project Owner or IAM Admin).
