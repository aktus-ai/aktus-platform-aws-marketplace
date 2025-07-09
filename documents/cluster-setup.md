# EKS Cluster Setup Guide
> Create and configure an EKS cluster with auto mode for Aktus AI Platform

---

## 🏗️ EKS Cluster Creation (Auto Mode)

### Quick Cluster Setup

Create an EKS cluster with auto mode using AWS Console or CLI:

**Option 1: AWS Console (Recommended)**
1. Go to [EKS Console](https://console.aws.amazon.com/eks/)
2. Click "Create cluster"
3. Choose "Auto mode" for simplified setup
4. AWS automatically configures networking, node groups, and add-ons

**Option 2: AWS CLI**
```bash
# Create EKS cluster with auto mode
aws eks create-cluster \
    --name aktus-ai-platform-cluster \
    --version 1.28 \
    --role-arn arn:aws:iam::ACCOUNT_ID:role/eksServiceRole \
    --resources-vpc-config subnetIds=subnet-xxx,subnet-yyy \
    --compute-config nodeGroups='[{
        "nodegroupName": "aktus-nodegroup",
        "instanceTypes": ["m5.xlarge"],
        "scalingConfig": {
            "minSize": 2,
            "maxSize": 10,
            "desiredSize": 3
        }
    }]'
```

**Option 3: eksctl (Simple)**
```bash
# Create cluster with eksctl
eksctl create cluster \
    --name aktus-ai-platform-cluster \
    --region us-east-1 \
    --nodegroup-name aktus-nodegroup \
    --nodes 3 \
    --nodes-min 2 \
    --nodes-max 10 \
    --node-type m5.xlarge \
    --managed
```

### Post-Creation Setup

After cluster creation, configure kubectl:
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name aktus-ai-platform-cluster

# Verify connection
kubectl get nodes
```

---

## 📋 Prerequisites

Before creating your cluster, ensure you have:

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with proper credentials
- **kubectl** installed locally
- **eksctl** installed (for Option 3)
- **IAM roles** for EKS service (auto-created in console mode)

---

## 🔧 Configuration Details

### Recommended Cluster Configuration

- **Kubernetes Version:** 1.28 or later
- **Node Type:** m5.xlarge (minimum)
- **Node Count:** 3 nodes (min: 2, max: 10)
- **Auto Mode:** Enabled for simplified management
- **Region:** us-east-1 (or your preferred region)

### Auto Mode Benefits

- **Automatic networking** configuration
- **Managed node groups** with auto-scaling
- **Pre-installed add-ons** (AWS Load Balancer Controller, EBS CSI Driver)
- **Simplified maintenance** and updates

---

## ✅ Verification Steps

After cluster creation, verify your setup:

1. **Check Cluster Status:**
   ```bash
   aws eks describe-cluster --name aktus-ai-platform-cluster --query cluster.status
   ```

2. **Verify Node Groups:**
   ```bash
   aws eks describe-nodegroup --cluster-name aktus-ai-platform-cluster --nodegroup-name aktus-nodegroup
   ```

3. **Test kubectl Connection:**
   ```bash
   kubectl get nodes -o wide
   ```

4. **Check Add-ons:**
   ```bash
   aws eks list-addons --cluster-name aktus-ai-platform-cluster
   ```

---

## 🆘 Troubleshooting

### Common Issues

**Problem: Cluster Creation Fails**
```bash
# Check IAM permissions
aws sts get-caller-identity

# Verify service roles
aws iam list-roles --query 'Roles[?contains(RoleName, `eks`)]'
```

**Problem: kubectl Cannot Connect**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name aktus-ai-platform-cluster

# Check AWS CLI configuration
aws configure list
```

**Problem: Nodes Not Ready**
```bash
# Check node status
kubectl describe nodes

# Check for system pods
kubectl get pods -n kube-system
```

### Getting Help

1. Check AWS CloudTrail for detailed error logs
2. Verify VPC and subnet configurations
3. Ensure proper IAM permissions for cluster creation
4. Review AWS EKS service quotas

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
- [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

---

## 🎯 Cluster Management

### Useful Commands

```bash
# Scale node group
aws eks update-nodegroup-config \
    --cluster-name aktus-ai-platform-cluster \
    --nodegroup-name aktus-nodegroup \
    --scaling-config minSize=2,maxSize=15,desiredSize=5

# Update cluster version
aws eks update-cluster-version \
    --name aktus-ai-platform-cluster \
    --kubernetes-version 1.29

# Delete cluster (when needed)
eksctl delete cluster --name aktus-ai-platform-cluster
```
