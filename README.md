## 🇰🇷 [한국어 보기](README.ko.md)

## Overview

This infrastructure example demonstrates how to automate data backup and instance replacement with minimal downtime when an AWS EC2 Spot Instance receives an interruption warning. Upon warning detection by EventBridge, a Lambda function takes a snapshot of the data volume and creates an AMI backup, and the Auto Scaling Group’s capacity-rebalancing feature provisions a new Spot Instance. All resources are managed as code using Terraform.


## System Architecture
<img width="881" alt="image" src="https://github.com/user-attachments/assets/60075c3c-0673-483e-8f84-c4e18919eec1" />




## How It Works

1. **EventBridge** detects the two-minute Spot interruption warning (`EC2 Spot Instance Interruption Warning`).
2. The event triggers an **AWS Lambda** function, which issues an SSM Run Command to perform a graceful shutdown of the application.
3. The Lambda function then calls for an **EBS volume snapshot** and an **AMI** creation asynchronously.
4. **Auto Scaling Group** with `capacity_rebalance=true` immediately provisions a replacement Spot instance.
5. The instance runs a `user-data` script on startup, which automatically mounts the persistent EBS volume and starts the application.
6. **Alarms & Notifications**:
   - When a Spot interruption warning is received, an **SNS alert** is triggered.
   - When the `user-data` script finishes successfully on the new instance, it publishes a **success message** to SNS.

---

## Deployment & Provisioning

Follow these steps to deploy the infrastructure.

### 1. Prerequisites

- Terraform v1.2 or higher.
- AWS CLI configured with appropriate IAM permissions (EC2, SSM, Lambda, SNS, Events, IAM).
- A custom AMI pre-built with your application.

### 2. Prepare Your Environment

#### Step 2.1: Create a Custom AMI (Mandatory)

This project requires a pre-existing AMI that has your application installed and configured as a systemd service. Terraform will use this AMI to launch new Spot instances.

1.  **Launch a base instance** (e.g., Amazon Linux 2) and install your application.
2.  **Enable your application as a service** (e.g., `sudo systemctl enable myapp`).
3.  **Create an AMI** from this instance.
4.  **Tag the AMI** with `Name` and a value that matches the pattern `myapp-base-*` (e.g., `myapp-base-v1.0`). The Terraform script looks for this tag.

#### Step 2.2: Prepare Configuration File

Clone the repository and create a `terraform.tfvars` file from the example. This file will store your specific configuration values.

```bash
git clone https://github.com/YOUR_ORG/aws-spot-autorecover.git
cd aws-spot-autorecover
cp terraform.tfvars.example terraform.tfvars
```

Now, edit `terraform.tfvars` and replace the placeholder values with your actual resource information (e.g., your subnet ID and email address).

### 3. Deploy with Terraform

Once your AMI is ready and `terraform.tfvars` is configured, you can deploy the infrastructure.

```bash
# Initialize Terraform providers
terraform init

# Apply the configuration to create resources in AWS
terraform apply -auto-approve
```

### 4. Verify Deployment

1.  **Confirm SNS Subscription**: Check your email for a subscription confirmation link from AWS and click it. You will not receive alerts otherwise.
2.  **Check Resources**: In the AWS Console, verify that the Auto Scaling Group, Lambda function and EventBridge rule have been created.
3.  **Access Your Application**: Find the public IP of the newly launched `spot-app-instance` and access it via your browser to ensure the application is running.

### 5. Test Recovery

Trigger a manual interruption to simulate a Spot instance reclaim event and verify the recovery process.

1.  Get the instance ID of your running Spot instance.
2.  Run the following AWS CLI command:
    ```bash
    aws ec2 send-spot-instance-interruptions \
      --instance-ids <your-instance-id> \
      --region <your-aws-region>
    ```
3.  **Monitor the recovery**:
    - You should immediately receive an **SNS alert** for the interruption warning.
    - After two minutes, a new instance will be provisioned by the Auto Scaling Group.
    - You will receive another **SNS alert** confirming the user-data script completed successfully on the new instance.

---

## Important Notes

- Use the backup AMI only for disaster recovery. Manage production AMI updates through your CI/CD pipeline.
- Ensure snapshot and AMI creation calls complete within the two-minute warning window; AWS backend will finish the operations asynchronously.
- For multi-AZ data durability, consider replacing the EBS volume with EFS and updating the user-data script accordingly.
- Replace your own specific commands in the user-data script and Lambda handler with your own application lifecycle logic.
