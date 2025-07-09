# Aktus AI Platform — Installation Documentation
> Comprehensive guides for deploying Aktus AI Platform on AWS Marketplace

---

## 🚀 Quick Start

| Step | Guide | Purpose |
|------|-------|---------|
| **📺** | **[Installation Videos](installation-video.md)** | Complete video series (Coming Soon) |
| **1** | **[Cluster Setup](cluster-setup.md)** | Create EKS cluster with auto mode |
| **2** | **[Storage Configuration](storage-configuration.md)** | Create EFS file system and storage classes |
| **3** | **[Marketplace Deployment](marketplace-deployment.md)** | Deploy from AWS Marketplace |

---

## ⚡ Deployment Sequence

**Infrastructure Setup:**
1. Create_EKS_Cluster_Auto `30 min`
2. Setup_EFS_Storage `10 min`  
3. Configure_IAM_Roles `15 min`
4. Install_AWS_LB_Controller `10 min`

**Deploy & Test:**
5. Deploy `10 min` → Apply Patch `5 min` → Wait 5 minutes → Embed → Test

> **Total Time:** ~80 minutes + document processing

---

## 📋 Prerequisites

Before starting deployment, ensure you have:

- **AWS Account** with appropriate permissions
- **EKS cluster** (created with auto mode)
- **EFS file system** in the same VPC as your cluster
- **kubectl** configured to access your cluster
- **Helm 3.x** installed (minimum version 3.7.1)
- **AWS CLI** configured with appropriate permissions
- **eksctl** for IAM service account creation

---

## 🚀 Next Steps

Once your EKS cluster is ready:

1. **[Configure Storage](storage-configuration.md)** - Set up EFS file system
2. **[Deploy Platform](marketplace-deployment.md)** - Install from AWS Marketplace

---

## 📚 Additional Resources

- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/auto-mode.html)
- [EKS Getting Started Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
- [AWS CLI EKS Commands](https://docs.aws.amazon.com/cli/latest/reference/eks/)
- [eksctl Documentation](https://eksctl.io/)

---

## 🆘 Troubleshooting

**Common Issues:**
- Ensure AWS CLI is configured with proper permissions
- Verify region settings match your infrastructure
- Check IAM roles have required EKS permissions
- Confirm cluster status is "ACTIVE" before proceeding

For detailed troubleshooting guides, see individual documentation files.
