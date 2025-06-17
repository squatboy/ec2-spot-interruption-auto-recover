## 🇰🇷 [한국어 보기](README.ko.md)

## Overview

This infrastructure example demonstrates how to automate data backup and instance replacement with minimal downtime when an AWS EC2 Spot Instance receives an interruption warning. Upon warning detection by EventBridge, a Lambda function takes a snapshot of the data volume and creates an AMI backup, and the Auto Scaling Group’s capacity-rebalancing feature provisions a new Spot Instance. All resources are managed as code using Terraform.


## System Architecture
<img width="893" alt="image" src="https://github.com/user-attachments/assets/31387c36-775d-4f0a-890f-1db616e03439" />



## How It Works

1. **EventBridge** detects the two-minute Spot interruption warning (`EC2 Spot Instance Interruption Warning`).
2. The event triggers an **AWS Lambda** function, which issues an SSM Run Command to perform a graceful shutdown of the application.
3. The Lambda function then calls for an **EBS volume snapshot** and an **AMI** creation asynchronously.
4. **Auto Scaling Group** with `capacity_rebalance=true` immediately provisions a replacement Spot instance.
5. Finally, the Lambda function **re-associates** the Elastic IP to the new instance, completing a seamless recovery without IP changes.


## Deployment & Provisioning

### 1. Prerequisites

- Terraform v1.2 or higher
- AWS CLI configured with appropriate IAM permissions (EC2, SSM, Lambda, Events)
- (Optional) GitHub Actions enabled for CI

### 2. Clone & Configure Variables

```bash
git clone <https://github.com/><YOUR_ORG>/aws-spot-autorecover.git
cd aws-spot-autorecover/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to set region, availability_zone, private_subnets, etc.

```

### 3. Apply Terraform

```bash
terraform init
terraform apply -auto-approve

```

### 4. Verify Deployment

- Check Auto Scaling Group, Lambda function, EventBridge rule, and Elastic IP in the AWS Console.
- Ensure the Spot instance launches with the correct tags and resources.

### 5. Test Recovery

- Simulate a Spot interruption in a low-cost Spot instance.
- Monitor CloudWatch Logs and Lambda logs to verify each recovery step completes successfully.



## Important Notes

- Use the backup AMI only for disaster recovery. Manage production AMI updates through your CI/CD pipeline.
- Ensure snapshot and AMI creation calls complete within the two-minute warning window; AWS backend will finish the operations asynchronously.
- For multi-AZ data durability, consider replacing the EBS volume with EFS and updating the user-data script accordingly.

