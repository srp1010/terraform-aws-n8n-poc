# n8n Workflow Automation on AWS (Terraform Template)

This Terraform template deploys a minimal, low-cost n8n workflow automation instance on AWS, with restricted access for proof of concept use.

## Prerequisites

- **AWS account** with required permissions to create EC2, VPC, and IAM resources
- **Authentication** Correctly authenticated to target AWS Account before running Terraform commands
- **Terraform CLI** installed on your local machine
- **Your public IP address** (to restrict access)

## Setup

1. **Clone or download** the Terraform files to a new directory.
2. **Create a `terraform.tfvars` file** with the following content:

   ```
   aws_region            = "YOUR_AWS_REGION"
   allowed_ip            = "YOUR_IP/32"
   n8n_basic_auth_user   = "admin"
   n8n_basic_auth_password = "your_secure_password"
   ```

   Replace `YOUR_AWS_REGION` with your desired AWS Region and `YOUR_IP/32` with your current public IP address in CIDR notation.

3. **Initialize Terraform**:

   ```
   terraform init
   ```

4. **Review the deployment plan**:

   ```
   terraform plan
   ```

5. **Apply the configuration**:

   ```
   terraform apply
   ```

   Confirm the action when prompted.

## Accessing n8n

After successful deployment, Terraform will output the n8n web interface URL and INSTANCE_ID. Use the basic authentication credentials you set in `terraform.tfvars` to log in to n8n, or use `aws ssm start-session --target INSTANCE_ID --region AWS_REGION`

## Destroying Resources

To completely remove all deployed resources and avoid ongoing charges, run:

    ```
    terraform destroy
    ```

Confirm the action when prompted.

## Notes

- **All access is restricted to your specified IP address** for security.
- **No open SSH access to server, use AWS SSM** for security.
- **POC ONLY** no ssl for simplicity (Not recommeded for non POC).
- **The deployment uses AWS spot instances** for minimal cost.
- **No persistent storage is configured**—data will be lost if the instance is terminated.
- **The IAM role has minimal permissions by default**—add more as needed for your workflows.
