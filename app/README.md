# 8byte Intern Assignment – DevOps Project

This project demonstrates an end-to-end DevOps workflow to provision cloud infrastructure using Terraform and deploy a containerized Node.js application on AWS EC2 using Docker and GitHub Actions.

The goal is to show practical understanding of:

- Infrastructure as Code
- Containerization
- Cloud networking
- Secure access
- CI pipeline automation

## Tech Stack

- **Application**: Node.js (Express)
- **Containerization**: Docker
- **Infrastructure as Code**: Terraform
- **CI**: GitHub Actions
- **Cloud**: AWS (EC2, VPC, Subnet, Security Groups)

## Architecture

```
Internet
    |
Internet Gateway
    |
Route Table
    |
Public Subnet (10.0.1.0/24)
    |
EC2 Instance (Ubuntu 22.04)
    |
Docker Container (Node.js app on port 3000)
```

## Infrastructure Components

- **VPC** (CIDR 10.0.0.0/16)
- **Public subnet** (CIDR 10.0.1.0/24)
- **Internet gateway**
- **Route table and association**
- **Security group**
  - Inbound 22 from user IP
  - Inbound 3000 from public
- **EC2 instance** (Ubuntu 22.04)
  - Docker installed using EC2 user_data

## Security Design

- SSH access is restricted to a single IP address using a Terraform variable
- Only required ports are exposed
- Application runs inside a container
- Network isolation is provided using a dedicated VPC

## Project Structure

```
.
├── .github
│   └── workflows
│       └── ci.yml
├── app
│   ├── app.js
│   ├── package.json
│   ├── package-lock.json
│   ├── Dockerfile
│   ├── .dockerignore
│   └── README.md
└── terraform
    ├── provider.tf
    ├── variables.tf
    ├── main.tf
    ├── outputs.tf
    └── terraform.tfvars
```

## Prerequisites

- AWS account
- AWS CLI configured locally
- Terraform version 1.0 or higher
- Docker installed locally
- Existing EC2 key pair in AWS
- GitHub account

## Terraform Configuration

Edit file: `terraform/terraform.tfvars`

Values:

```hcl
aws_region         = "ap-south-1"
project_name       = "8byte-intern-assignment"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
instance_type      = "t2.micro"
ssh_key_name       = "your-keypair-name"
my_ip              = "YOUR_PUBLIC_IP/32"
```

Get your public IP using:

```bash
curl ifconfig.me
```

## Infrastructure Deployment

Go to terraform folder:

```bash
cd terraform
```

Run:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

After apply completes, note the outputs:

- `ec2_public_ip`
- `application_url`

## Application Deployment on EC2

Copy the application directory to the EC2 instance:

```bash
scp -i /path/to/key.pem -r app ubuntu@<EC2_PUBLIC_IP>:/home/ubuntu/
```

Connect to the instance:

```bash
ssh -i /path/to/key.pem ubuntu@<EC2_PUBLIC_IP>
```

Build and run the application:

```bash
cd ~/app

docker build -t 8byte-intern-app .

docker run -d --restart unless-stopped -p 3000:3000 --name intern-app 8byte-intern-app
```

Verify container:

```bash
docker ps
```

Test locally on the EC2 server:

```bash
curl http://localhost:3000
```

Access from browser:

```
http://<EC2_PUBLIC_IP>:3000
```

Expected output:

```
8byte Intern Assignment Successfully Deployed
```

## GitHub Actions – CI Pipeline

The GitHub Actions workflow performs:

- Checkout source code
- Setup Docker buildx
- Login to Docker Hub
- Build Docker image
- Push Docker image to Docker Hub

Workflow file: `.github/workflows/ci.yml`

### GitHub Secrets Required

- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

### Docker Image Tags

- `latest`
- commit SHA

## Local Development

From the app directory:

```bash
npm install
node app.js
```

Access at: `http://localhost:3000`

## Docker Local Test

```bash
docker build -t 8byte-intern-app .
docker run -p 3000:3000 8byte-intern-app
```

## Useful Commands

```bash
docker logs intern-app
docker stop intern-app
docker rm intern-app
```

## Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

## Limitations

- Deployment to EC2 is performed manually after image build
- No load balancer or auto-scaling is configured
- Application runs in a public subnet

These trade-offs were intentionally kept to keep the assignment simple and focused.

## Future Improvements

- Push Docker image to Amazon ECR and pull directly on EC2
- Fully automated continuous deployment after GitHub Actions build
- Application Load Balancer and Auto Scaling Group
- Private subnet architecture with NAT Gateway
- Terraform remote state using S3 and DynamoDB
- Monitoring and alerting using CloudWatch
- Security and vulnerability scanning in CI pipeline

## Author

**K. S. Sushanth**  
DevOps / Backend Engineering Candidate  
8byte Internship Assignment
