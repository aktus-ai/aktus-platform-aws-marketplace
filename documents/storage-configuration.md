# EFS Storage Configuration Guide

> Create and configure Amazon EFS for Aktus AI Platform persistent storage

---

## 🗄️ EFS File System Setup (AWS Console)

### Quick EFS Creation

**Step 1: Access EFS Console**

1. Go to [EFS Console](https://console.aws.amazon.com/efs/)
2. Click **"Create file system"**

**Step 2: Basic Configuration**

1. **Name:** `aktus-ai-platform-efs`
2. **VPC:** Select the same VPC as your EKS cluster

**Step 3: File System Policy (Optional)**

- Leave default for standard access
- Can be configured later if needed

**Step 4: Review and Create**

1. Review all settings
2. Click **"Create"**
3. **Note the File System ID** (format: `fs-xxxxxxxxx`)

---

## ✅ Quick Verification

After creation, verify your EFS setup:

1. **Check Status:** Ensure status shows "Available"
2. **Note File System ID:** Copy the `fs-xxxxxxxxx` ID for deployment
3. **Verify Mount Targets:** Confirm mount targets in all required AZs

---

## 🔧 Security Group Configuration

If you need to create a new security group for EFS:

**Create Security Group:**

1. Go to [EC2 Console &gt; Security Groups](https://console.aws.amazon.com/ec2/v2/home#SecurityGroups)
2. Click **"Create security group"**
3. **Name:** `aktus-efs-sg`
4. **VPC:** Same as EKS cluster

**Add Inbound Rule:**

- **Type:** NFS
- **Port:** 2049
- **Source:** EKS cluster security group (or CIDR of EKS subnets)

---

## 📋 Prerequisites

- **EKS cluster** already created - see [Cluster Setup](cluster-setup.md)
- **VPC and subnets** identified (same as EKS cluster)
- **Security group** planning completed

---

## 🚀 Next Steps

Once your EFS is ready:

1. **Copy the EFS File System ID** (you'll need this for deployment)
2. **[Deploy Platform](marketplace-deployment.md)** - Install from AWS Marketplace

---

## 💡 Important Notes

- **EFS must be in the same VPC** as your EKS cluster
- **File System ID** is required for the deployment script
- **Security groups** must allow NFS traffic (port 2049)
- **Mount targets** are automatically created in each AZ

---

## 🆘 Troubleshooting

**Common Issues:**

**Problem: Mount Timeout**

```bash
# Check security group allows NFS (port 2049)
# Verify EFS and EKS are in same VPC
```

**Problem: Access Denied**

```bash
# Check EFS file system policy
# Verify IAM permissions for EKS nodes
```

**Problem: No Mount Targets**

```bash
# Ensure subnets are correctly configured
# Check AZ availability for EFS
```

---

## 📚 Additional Resources

- [Amazon EFS User Guide](https://docs.aws.amazon.com/efs/latest/ug/)
- [EFS Performance Guide](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
- [EKS Storage Classes](https://docs.aws.amazon.com/eks/latest/userguide/storage-classes.html)
