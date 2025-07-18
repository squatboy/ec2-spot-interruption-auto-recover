## 🇰🇷 [한국어 보기](README.ko.md)

## Overview

This infrastructure example demonstrates how to automate data backup and instance replacement with minimal downtime when an AWS EC2 Spot Instance receives an interruption warning. Upon warning detection by EventBridge, a Lambda function takes a snapshot of the data volume, and the Auto Scaling Group's capacity-rebalancing feature provisions a new Spot Instance. All resources are managed as code using Terraform.

## System Architecture
<img width="1209" alt="docker_arch" src="https://github.com/user-attachments/assets/279e0244-f1ae-4e90-abb8-1bfa8a00ecec" />


## How It Works

1.  **EventBridge** detects the two-minute Spot interruption warning (`EC2 Spot Instance Interruption Warning`).
2.  The event triggers an **AWS Lambda** function, which issues an SSM Run Command to perform a graceful shutdown of the Docker container.
3.  The Lambda function then calls for an **EBS volume snapshot** creation asynchronously to back up the data.
4.  **Auto Scaling Group** with `capacity_rebalance=true` immediately provisions a replacement Spot instance.
5.  The new instance runs a `user-data` script on startup, which automatically mounts the persistent EBS volume, pulls the latest Docker image from ECR, and starts the container.
6.  **Alarms & Notifications**:
    *   When a Spot interruption warning is received, an **SNS alert** is triggered.
    *   When the `user-data` script finishes successfully on the new instance, it publishes a **success message** to SNS.

---

## Deployment & Provisioning

Follow these steps to deploy the infrastructure.

### 1. Prerequisites

-   Terraform v1.2 or higher.
-   AWS CLI configured with appropriate IAM permissions (EC2, SSM, Lambda, SNS, Events, IAM, ECR).
-   A Docker image containing your application, pushed to Amazon ECR.
-   A custom AMI with the Docker engine installed.
-   Create an RSA key pair named "spot-instance-key" for SSH access (optional).

### 2. Prepare Your Environment

#### Step 2.1: Create SSH Key Pair (Optional)

You can create a key pair in advance for debugging purposes when SSH access to instances is needed.

```bash
# Create AWS EC2 key pair
aws ec2 create-key-pair --key-name spot-instance-key --query 'KeyMaterial' --output text > ~/.ssh/spot-instance-key.pem

# Set key file permissions
chmod 400 ~/.ssh/spot-instance-key.pem
```

#### Step 2.2: Create a Custom AMI (Mandatory)

This project requires a pre-existing AMI with the **Docker engine installed**.

1.  **Launch a base instance**: Start an instance with a base OS like Amazon Linux 2.
2.  **Install and enable Docker**: Run `sudo yum install -y docker` and `sudo systemctl enable docker` to install and enable the Docker service.
3.  **Create and tag the AMI**: Create an AMI from the configured instance and tag it with `Name` and a value like `docker-base-v1`. Terraform uses this tag to find the AMI.

#### Step 2.3: Prepare Docker Image and Push to ECR

1.  Create a `Dockerfile` for your application
2.  Build the Docker image.
3.  Create a repository in AWS ECR.
4.  Push the built image to your ECR repository.

#### Step 2.4: Prepare Configuration File

Clone the repository and create a `terraform.tfvars` file from the example. This file will store your specific configuration values.

```bash
git clone https://github.com/YOUR_ORG/aws-spot-autorecover.git
cd aws-spot-autorecover
cp terraform.tfvars.example terraform.tfvars
```

Now, edit `terraform.tfvars` and replace the placeholder values with your actual resource information (e.g., your subnet ID, email address, and ECR repository URL).

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
2.  **Check Resources**: In the AWS Console, verify that the Auto Scaling Group, Lambda function, and EventBridge rule have been created.
3.  **Access Your Application**: Find the public IP of the newly launched `spot-app-instance` and access it to ensure the application is running correctly.

### 5. Test Recovery

Use [amazon-ec2-spot-interrupter](https://github.com/aws/amazon-ec2-spot-interrupter) tool to simulate a Spot instance interruption event and verify the recovery process.

#### 5.1 Install the Tool

```bash
# Install EC2 Spot Interrupter via Homebrew
brew tap aws/tap
brew install ec2-spot-interrupter
```

#### 5.2 Execute Recovery Test

1.  Get the instance ID of your running Spot instance.
2.  Simulate an interruption event with the following command:
    ```bash
    ec2-spot-interrupter --instance-ids <your-instance-id>
    ```
3.  **Monitor the recovery**:
    -   You should immediately receive an **SNS alert** for the interruption warning.
    -   After two minutes, a new instance will be provisioned by the Auto Scaling Group.
    -   You will receive another **SNS alert** confirming the user-data script completed successfully on the new instance.

---

## Important Notes

-   The EBS snapshot is used for disaster recovery. Manage your production Docker images through a separate CI/CD pipeline.
-   The snapshot creation call must complete within the two-minute warning window; the AWS backend will finish the backup operation asynchronously.
-   For multi-AZ data durability, consider replacing the EBS volume with EFS and updating the user-data script accordingly.
-   Customize the commands within the user-data script and Lambda handler to match your specific application requirements.
