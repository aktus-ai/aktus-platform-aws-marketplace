# AWS Marketplace Deployment Guide

> Step-by-step instructions for deploying Aktus AI Platform from AWS Marketplace

---

## 📋 Prerequisites

Before starting deployment, ensure you have:

- **EKS cluster** (created with auto mode) - see [Cluster Setup](cluster-setup.md)
- **EFS file system** in the same VPC as your cluster - see [Storage Configuration](storage-configuration.md)
- **kubectl** configured to access your cluster
- **Helm 3.6.3** installed 
- **AWS CLI** configured with appropriate permissions
- **eksctl** for IAM service account creation

---

## 🛠️ Step-by-Step Deployment

### Step 1: Create IAM Role and Service Account

Create the required namespace and IAM service account for AWS Marketplace metering:

```bash
kubectl create namespace aktus-ai-platform-dev

eksctl create iamserviceaccount \
    --name aktus-ai-platform-sa \
    --namespace aktus-ai-platform-dev \
    --cluster <ENTER_YOUR_CLUSTER_NAME_HERE> \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSMarketplaceMeteringFullAccess \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSMarketplaceMeteringRegisterUsage \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AWSLicenseManagerConsumptionPolicy \
    --approve \
    --override-existing-serviceaccounts
```

### Step 2: Pull Helm Chart from ECR

Download the Aktus AI Platform Helm chart from AWS ECR:

```bash
export HELM_EXPERIMENTAL_OCI=1

aws ecr get-login-password \
    --region us-east-1 | helm registry login \
    --username AWS \
    --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

mkdir awsmp-chart && cd awsmp-chart

helm pull oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/aktus-ai/aktus-ai-platform-aws-marketplace-ecr --version 1.0.4

tar xf $(pwd)/* && find $(pwd) -maxdepth 1 -type f -delete
```

### Step 3: Download Management Script

1. **Download the management script** from: [Google Drive Link](https://drive.google.com/file/d/1PfF4LItn6gMQ5DWQAk-v2CByAYj409pr/view?usp=sharing)
2. **Place the script** at the same level as the `aktus-platform/` folder:

   ```
   awsmp-chart/
   ├── aktus-platform/
   └── aktus-platform-manager.sh
   ```
3. **Make the script executable:**

   ```bash
   chmod +x aktus-platform-manager.sh
   ```

### Step 4: Deploy Platform

**🚀 Initial Installation (Required):**

```bash
./aktus-platform-manager.sh install <efs-file-system-id>
```

**Example:**

```bash
./aktus-platform-manager.sh install fs-0d4fb6758c6f3f465
```

**🔧 Apply Patch (Required):**

After installation, apply the patch to enable complete service integration:

```bash
./aktus-platform-manager.sh patch
```

**✅ Verify Deployment:**

Check all service endpoints are available:

```bash
./aktus-platform-manager.sh endpoints
```

---

## 🎮 Management Commands

| Command              | Purpose                                            |
| -------------------- | -------------------------------------------------- |
| `install <efs-id>` | Initial platform deployment with EFS configuration |
| `patch`            | Updates service endpoints for full functionality   |
| `endpoints`        | Display all service URLs                           |
| `uninstall`        | Complete platform removal                          |

---

## ⚠️ Important Notes

- **Both `install` and `patch` commands are required** for a fully functional deployment
- Replace `<efs-file-system-id>` with your actual EFS file system ID
- Services are deployed to `aktus-ai-platform-dev` namespace
- LoadBalancer services use AWS ALB/NLB for external access
- The management script automates EFS configuration and storage class creation

---

## 🔧 Alternative Helm Installation

If you prefer manual Helm installation without the management script:

```bash
helm install aktus-ai-platform \
    --namespace aktus-ai-platform-dev ./*
```

> **⚠️ Note:** This method requires manual EFS and storage configuration.

---

## 🔍 Verification Steps

After deployment, verify your installation:

1. **Check Pod Status:**

   ```bash
   kubectl get pods -n aktus-ai-platform-dev
   ```
2. **Check Services:**

   ```bash
   kubectl get services -n aktus-ai-platform-dev
   ```
3. **Check Ingress/LoadBalancers:**

   ```bash
   kubectl get ingress -n aktus-ai-platform-dev
   ```
4. **View Logs (if needed):**

   ```bash
   kubectl logs -n aktus-ai-platform-dev deployment/<service-name>
   ```

---

## 🆘 Troubleshooting

### Common Deployment Issues

**Problem: IAM Service Account Creation Fails**

```bash
# Check if service account exists
kubectl get serviceaccount -n aktus-ai-platform-dev

# Verify IAM role
aws iam get-role --role-name eksctl-<cluster-name>-addon-iamserviceaccount-Role
```

**Problem: ECR Login Fails**

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check ECR permissions
aws ecr describe-repositories --region us-east-1
```

**Problem: EFS Mount Issues**

```bash
# Check EFS file system
aws efs describe-file-systems --file-system-id <efs-id>

# Verify VPC connectivity
kubectl describe pv | grep efs
```

**Problem: Services Not Accessible**

```bash
# Check LoadBalancer status
kubectl get services -n aktus-ai-platform-dev -o wide

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

### Getting Help

1. Check pod logs for specific services
2. Verify EFS mount points are accessible
3. Ensure security groups allow necessary traffic
4. Confirm IAM roles have required permissions

---

## 📚 Additional Resources

- [AWS Marketplace Documentation](https://docs.aws.amazon.com/marketplace/)
- [Helm Chart Troubleshooting](https://helm.sh/docs/chart_best_practices/troubleshooting/)
- [EKS Troubleshooting Guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

## 🎯 Next Steps

After successful deployment:

1. **Configure your domain** (if using custom domains)
2. **Set up monitoring** and logging
3. **Configure backup strategies** for your data
4. **Review security settings** and access controls
