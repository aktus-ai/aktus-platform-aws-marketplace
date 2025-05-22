# aktus-platform-aws-marketplace
Configuration and deployment resources for Aktus AI Platform on AWS Marketplace.

# Aktus AI Platform
**Enterprise AI for Research, Knowledge Management, and Data Processing**

Welcome to the Aktus AI Platform—a comprehensive enterprise solution to build, deploy, and manage AI services. This package is available on AWS Marketplace for streamlined deployment on Amazon EKS.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [AWS Marketplace Deployment](#deploying-from-aws-marketplace)
  - [Helm Installation](#installing-via-helm)
- [Usage](#usage)
  - [Accessing the Research Service](#accessing-the-research-service)
  - [Default Credentials](#default-credentials)
- [Backup and Restore](#backup-and-restore)
- [Updating and Scaling](#updating-and-scaling)
- [Deleting the Application](#deleting-the-application)
- [Billing](#billing)
- [API Documentation](#api-documentation)
- [Troubleshooting & FAQ](#troubleshooting--faq)

---

## Overview

Aktus AI Platform empowers organizations with a unified interface and robust backend to conduct AI research, deploy models with GPU acceleration, manage databases, and process multimodal data. Whether you are exploring semantic search via embeddings or running intensive inference tasks, our platform is designed for high availability and performance on AWS infrastructure.

---

## Features

- **Research Service:** A web interface for research and knowledge exploration.  
- **Inference Service:** Machine learning model inference with GPU acceleration on EC2 instances.  
- **Database Service:** Robust data management and storage solutions with RDS integration.  
- **Multimodal Data Ingestion:** Process documents and images efficiently using S3 storage.  
- **Embedding Service:** Generate vector embeddings for semantic searches.

---

## Prerequisites

- **Amazon EKS:** Kubernetes cluster version 1.19 or higher is required.
- **kubectl:** Command-line tool for Kubernetes operations, properly configured for your EKS cluster.
- **Helm:** Version 3.0 or later.
- **AWS CLI:** Configured with appropriate IAM permissions.
- **Application CRD:** Install the required Custom Resource Definition.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/application/master/config/crd/bases/app.k8s.io_applications.yaml
```

### Required AWS Permissions

Ensure your AWS IAM role has the following permissions:
- EKS cluster access
- EC2 instance management (for GPU nodes)
- S3 bucket access
- CloudWatch logs access
- AWS Marketplace metering permissions

---

## Installation

### Deploying from AWS Marketplace

1. Open the [AWS Marketplace Console](https://aws.amazon.com/marketplace/).
2. Search for "Aktus AI Platform" and select the listing.
3. Click **Continue to Subscribe**.
4. Review pricing and click **Subscribe**.
5. After subscription confirmation, click **Continue to Configuration**.
6. Select your preferred delivery method:
   - **Container Image**: For deployment on existing EKS clusters
   - **CloudFormation Template**: For automated infrastructure provisioning
7. Choose your region and software version.
8. Click **Continue to Launch**.
9. Configure launch options:
   - Select **Launch CloudFormation** for automated deployment
   - Or choose **Usage Instructions** for manual EKS deployment
10. Complete the deployment process.

### Installing via Helm

For those preferring Helm deployment on existing EKS clusters:

```bash
# Update helm repositories
helm repo update

# Install the Aktus Platform chart
helm install aktus-platform aktus/aktus-platform \
  --namespace aktus \
  --create-namespace \
  --set name=aktus-platform \
  --set serviceAccount.name=aktus-platform-sa \
  --set cloud.provider=aws \
  --set aws.region=${AWS_REGION}
```

---

## Usage

### Accessing the Research Service

After deployment, access the Research Service via your browser. The service will be available through an AWS Application Load Balancer:

```
https://<alb-dns-name>
```

To retrieve the load balancer DNS name:

```bash
kubectl get svc aktus-research -n <namespace>
# Or if using ALB Ingress Controller:
kubectl get ingress aktus-research-ingress -n <namespace>
```

### Default Credentials

- **Username:** guest  
- **Password:** guest

> **Note:** It is strongly recommended to change these credentials for production environments and integrate with AWS IAM or AWS Cognito for authentication.

---

## Backup and Restore

### Backing Up PostgreSQL Data

For RDS PostgreSQL instances:

```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier aktus-postgres \
  --db-snapshot-identifier aktus-backup-$(date +%Y%m%d-%H%M%S)
```

For containerized PostgreSQL:

```bash
kubectl exec -n <namespace> aktus-postgres-0 -- pg_dump -U <username> <database> > backup.sql
```

### Restoring PostgreSQL Data

From RDS snapshot:

```bash
# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier aktus-postgres-restored \
  --db-snapshot-identifier <snapshot-id>
```

For containerized PostgreSQL:

```bash
kubectl cp backup.sql <namespace>/aktus-postgres-0:/tmp/
kubectl exec -n <namespace> aktus-postgres-0 -- psql -U <username> <database> -f /tmp/backup.sql
```

---

## Updating and Scaling

### Image Updates

To update the platform to a newer version:

```bash
helm upgrade aktus-platform aktus/aktus-platform \
  --namespace <namespace> \
  --set imageTag=<new-version>
```

### Scaling Inference Service

Adjust the number of replicas for the Inference Service:

```bash
kubectl scale deployment aktus-inference -n <namespace> --replicas=2
```

### Auto Scaling with AWS

Configure Horizontal Pod Autoscaler for automatic scaling:

```bash
kubectl autoscale deployment aktus-inference \
  --namespace <namespace> \
  --cpu-percent=70 \
  --min=1 \
  --max=10
```

---

## Deleting the Application

To remove the application:

```bash
helm delete aktus-platform -n <namespace>
```

Cleanup any residual persistent volumes:

```bash
kubectl delete pvc -l app.kubernetes.io/name=aktus-platform -n <namespace>
```

If deployed via CloudFormation, delete the stack:

```bash
aws cloudformation delete-stack --stack-name aktus-platform-stack
```

---

## API Documentation

*API documentation is in progress. Visit our [documentation portal](#) for the latest information or check the AWS Marketplace listing for API references.*

---

## Troubleshooting & FAQ

- **Issue:** Cannot access the Research Service.  
  **Solution:** Ensure your AWS Load Balancer is properly configured and security groups allow inbound traffic on the required ports. Check the ALB target group health.

- **Issue:** EKS cluster nodes cannot pull container images.  
  **Solution:** Verify that your EKS node groups have the necessary IAM permissions to access ECR. Check the `AmazonEKSWorkerNodePolicy` and `AmazonEKS_CNI_Policy`.

- **Issue:** GPU instances not being utilized.  
  **Solution:** Ensure GPU-enabled node groups are configured in your EKS cluster and the NVIDIA device plugin is installed.

- **Issue:** Backup/Restore commands fail.  
  **Solution:** Verify AWS credentials and IAM permissions. For RDS operations, ensure the database is in an available state.

- **Issue:** Marketplace billing not working.  
  **Solution:** Check that the IAM role for service accounts (IRSA) is properly configured with marketplace metering permissions.

### Common AWS-Specific Issues

- **VPC Configuration:** Ensure your EKS cluster has proper subnet configuration with both public and private subnets.
- **Security Groups:** Verify that security groups allow necessary traffic between cluster components.
- **IAM Permissions:** Review CloudTrail logs for any access denied errors.

**For Further Help:** Contact our support team at [support@aktus.ai](mailto:support@aktus.ai) or refer to our [community forum](#).

---

## AWS Integration Features

### S3 Integration
- Automatic document storage and retrieval
- Multimodal data processing with S3 event triggers
- Lifecycle policies for cost optimization

### EC2 GPU Instances
- Optimized for ML inference workloads
- Support for NVIDIA A100, V100, and T4 instances
- Auto Scaling Groups for cost-effective scaling

---

## Conclusion

This README provides comprehensive guidance for deploying, using, and managing the Aktus AI Platform on AWS Marketplace. The platform is optimized for AWS infrastructure, providing seamless integration with EKS, RDS, S3, and other AWS services. For further inquiries or custom deployment requirements, please contact our [support](mailto:support@aktus.ai) team or refer to our online documentation.