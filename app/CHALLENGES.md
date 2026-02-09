# CHALLENGES.md

## Technical Challenges and Solutions

This document details the technical hurdles encountered during the project and how they were resolved.

---

## 1. Docker Installation on EC2

### Challenge

Initial user_data script failed to install Docker properly. The instance would boot, but Docker was not available when SSH'ing into the instance.

### Root Cause

- User_data script errors were not visible
- Script execution timing issues
- Package repository not properly configured

### Solution

```bash
#!/bin/bash
set -e  # Exit on any error
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
```

### Key Learnings

- Always use `set -e` in bash scripts to catch errors
- Follow official Docker installation documentation exactly
- Add ubuntu user to docker group for non-root access
- Wait 2-3 minutes after instance launch for user_data completion

### Verification

```bash
# Check user_data logs
sudo cat /var/log/cloud-init-output.log

# Verify Docker installation
docker --version
systemctl status docker
```

---

## 2. AMI ID Hardcoding Issue

### Challenge

Initially hardcoded Ubuntu AMI ID, which:
- Varies by region
- Becomes outdated as new AMIs are released
- Breaks when deploying to different regions

### Root Cause

Lack of understanding of Terraform data sources and AWS AMI lifecycle.

### Solution

Used Terraform data source to dynamically fetch the latest Ubuntu 22.04 AMI:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami = data.aws_ami.ubuntu.id
  # ...
}
```

### Key Learnings

- Never hardcode AMI IDs
- Use data sources for dynamic resource lookup
- Canonical's AWS account ID is 099720109477
- Filter by name pattern for specific Ubuntu versions

---

## 3. Security Group Configuration

### Challenge

Application was not accessible from browser even though container was running on EC2.

### Root Cause

Security group was not properly configured to allow inbound traffic on port 3000.

### Solution

```hcl
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Security group for Node.js application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Node.js App"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public access
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Debugging Steps

1. Verified container was running: `docker ps`
2. Tested locally on EC2: `curl localhost:3000` (worked)
3. Checked security group rules in AWS Console
4. Added port 3000 ingress rule
5. Tested from browser (worked)

### Key Learnings

- Security groups are stateful (return traffic automatically allowed)
- Always test locally first, then check network rules
- Use descriptive names for security group rules
- Document why each port is opened

---

## 4. GitHub Actions Docker Build Context

### Challenge

GitHub Actions workflow failed with error: "unable to prepare context: unable to evaluate symlinks in Dockerfile path"

### Root Cause

Dockerfile was in `app/` directory, but workflow was using root directory as build context.

### Initial Configuration (Failed)

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v4
  with:
    context: .  # Wrong: Dockerfile not in root
    push: true
```

### Solution

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v4
  with:
    context: ./app
    file: ./app/Dockerfile
    push: true
    tags: |
      ${{ secrets.DOCKER_USERNAME }}/8byte-intern-assignment:latest
      ${{ secrets.DOCKER_USERNAME }}/8byte-intern-assignment:${{ github.sha }}
```

### Key Learnings

- Build context must contain Dockerfile and all files referenced in COPY commands
- Explicitly specify Dockerfile path when not in root
- Use multi-line YAML syntax for better readability

---

## 5. Docker Hub Authentication

### Challenge

GitHub Actions workflow failed with "unauthorized: incorrect username or password" error.

### Root Cause

- Initially used Docker Hub password instead of access token
- Token had insufficient permissions

### Solution

1. Created Docker Hub Access Token with Read & Write permissions
2. Added secrets to GitHub repository:
   - `DOCKER_USERNAME`: Docker Hub username
   - `DOCKER_PASSWORD`: Docker Hub access token (not password)

```yaml
- name: Log in to Docker Hub
  uses: docker/login-action@v2
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

### Key Learnings

- Use access tokens instead of passwords for better security
- Tokens can be scoped with specific permissions
- Tokens can be revoked without changing password
- Store credentials in GitHub Secrets, never in code

---

## 6. Terraform State Locking

### Challenge

Encountered "Error acquiring the state lock" when running terraform apply after a previous failed run.

### Root Cause

Previous terraform operation was interrupted, leaving state file locked.

### Solution

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# Or delete local lock file
rm .terraform.tfstate.lock.info
```

### Prevention

- Always let terraform operations complete
- Use Ctrl+C gracefully if must interrupt
- Implement remote state with DynamoDB locking for team environments

### Key Learnings

- State locking prevents concurrent modifications
- Local state is fragile for team collaboration
- Remote state with S3 + DynamoDB is production best practice

---

## 7. EC2 Instance Not Getting Public IP

### Challenge

EC2 instance launched but had no public IP address, making it inaccessible.

### Root Cause

Subnet was not configured to auto-assign public IPs.

### Solution

```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true  # Critical setting
  availability_zone       = data.aws_availability_zones.available.names[0]
}
```

### Key Learnings

- Public subnets need `map_public_ip_on_launch = true`
- Can also enable on instance level with `associate_public_ip_address`
- Verify in AWS Console that instance has public IP before troubleshooting further

---

## 8. Docker Permission Denied

### Challenge

After SSH'ing into EC2, got "permission denied" error when running docker commands.

### Root Cause

ubuntu user was not in the docker group, requiring sudo for all docker commands.

### Solution

Added to user_data script:

```bash
usermod -aG docker ubuntu
```

### Workaround (if not in user_data)

```bash
# Add user to docker group
sudo usermod -aG docker ubuntu

# Log out and back in for group changes to take effect
exit
ssh -i key.pem ubuntu@<IP>

# Or use newgrp to activate group without logout
newgrp docker
```

### Key Learnings

- Docker daemon runs as root by default
- Users need to be in docker group for non-root access
- Group changes require new login session to take effect

---

## 9. Container Not Restarting After Reboot

### Challenge

After EC2 instance reboot, Docker container did not automatically restart.

### Root Cause

Container was started without restart policy.

### Solution

```bash
docker run -d --restart unless-stopped -p 3000:3000 --name intern-app 8byte-intern-app
```

### Restart Policy Options

- `no`: Never restart (default)
- `on-failure`: Restart only on failure
- `always`: Always restart
- `unless-stopped`: Always restart unless manually stopped

### Key Learnings

- Always specify restart policy for production containers
- `unless-stopped` is best for most use cases
- Can update existing container: `docker update --restart unless-stopped <container>`

---

## 10. Terraform Variables Not Being Applied

### Challenge

Terraform was using default values instead of values from terraform.tfvars.

### Root Cause

Running terraform commands from wrong directory (root instead of terraform/).

### Solution

```bash
# Always run from terraform directory
cd terraform
terraform init
terraform apply

# Or specify var file explicitly
terraform apply -var-file="terraform.tfvars"
```

### Key Learnings

- Terraform looks for terraform.tfvars in current directory
- Can use `-var-file` flag to specify alternate location
- Use `-var` flag for individual variable overrides

---

## 11. SSH Connection Timeout

### Challenge

Unable to SSH into EC2 instance - connection timeout error.

### Root Cause

Multiple possible causes:
1. Security group not allowing SSH from my IP
2. Wrong key pair used
3. Instance not fully initialized

### Debugging Process

```bash
# 1. Verify security group allows your IP
curl ifconfig.me  # Get your public IP

# 2. Check security group in AWS Console
# Ensure port 22 allows your IP

# 3. Verify key pair name matches
terraform output

# 4. Wait for instance initialization
# Check System Status Checks in AWS Console

# 5. Test with verbose SSH
ssh -v -i key.pem ubuntu@<IP>
```

### Solution

Updated terraform.tfvars with correct IP in CIDR format:

```hcl
my_ip = "203.0.113.45/32"  # /32 for single IP
```

### Key Learnings

- Always use CIDR notation for IP addresses
- Security groups are stateful (return traffic allowed)
- Wait 2-3 minutes for instance initialization
- Use verbose SSH (-v) for debugging connection issues

---

## 12. Docker Build Failing on EC2

### Challenge

Docker build failed with "unable to prepare context" error on EC2.

### Root Cause

Files were not properly copied to EC2 instance.

### Solution

```bash
# Copy entire app directory
scp -i key.pem -r app ubuntu@<EC2_IP>:/home/ubuntu/

# Verify files copied
ssh -i key.pem ubuntu@<EC2_IP>
ls -la ~/app

# Build from correct directory
cd ~/app
docker build -t 8byte-intern-app .
```

### Key Learnings

- Use `scp -r` for recursive directory copy
- Verify files exist before running docker build
- Build context must contain all files referenced in Dockerfile

---

## 13. Application Not Responding After Container Start

### Challenge

Container started successfully but application not responding to requests.

### Debugging Process

```bash
# 1. Check container is running
docker ps

# 2. Check container logs
docker logs intern-app

# 3. Test from inside container
docker exec -it intern-app sh
wget -O- localhost:3000

# 4. Test from EC2 host
curl localhost:3000

# 5. Check port mapping
docker port intern-app
```

### Common Issues Found

- Port mapping incorrect: `-p 3000:3000` required
- Application not listening on 0.0.0.0 (listening on 127.0.0.1 only)
- Container crashed immediately after start

### Key Learnings

- Always check container logs first
- Test connectivity at each network layer
- Ensure application listens on 0.0.0.0, not 127.0.0.1

---

## 14. Terraform Destroy Hanging

### Challenge

`terraform destroy` hung indefinitely when trying to delete resources.

### Root Cause

- Dependencies between resources not properly handled
- Network interfaces still attached to instances

### Solution

```bash
# Force stop instance first
aws ec2 stop-instances --instance-ids <instance-id>

# Wait for instance to stop
aws ec2 wait instance-stopped --instance-ids <instance-id>

# Then run destroy
terraform destroy
```

### Prevention

Terraform should handle dependencies automatically, but sometimes manual intervention needed:

```bash
# Destroy specific resource first
terraform destroy -target=aws_instance.app

# Then destroy everything else
terraform destroy
```

### Key Learnings

- Terraform dependency graph usually handles order correctly
- Sometimes AWS resources get stuck in transitional states
- Can use `-target` flag to destroy specific resources first

---

## 15. GitHub Actions Workflow Not Triggering

### Challenge

Pushed code to main branch but GitHub Actions workflow did not trigger.

### Root Cause

Workflow file had syntax errors or was not in correct location.

### Solution

1. Verify file location: `.github/workflows/ci.yml`
2. Check YAML syntax: https://www.yamllint.com/
3. Verify branch name matches: `main` vs `master`
4. Check workflow file is committed and pushed

```bash
# Verify workflow file exists
git ls-files .github/workflows/

# Check for syntax errors
cat .github/workflows/ci.yml

# Manually trigger workflow (if configured)
# GitHub UI: Actions → Select workflow → Run workflow
```

### Key Learnings

- Workflow files must be in `.github/workflows/` directory
- YAML is whitespace-sensitive
- Check Actions tab in GitHub for error messages
- Can add `workflow_dispatch` trigger for manual runs

---

## Key Takeaways

### Most Important Lessons

1. **Read Error Messages Carefully**: Most issues have clear error messages if you read them
2. **Test Incrementally**: Validate each component before moving to next
3. **Check Logs**: Always check logs (cloud-init, docker, application)
4. **Use Official Documentation**: Follow official docs, not random blog posts
5. **Version Control Everything**: Commit working states frequently

### Debugging Methodology

1. **Reproduce**: Ensure you can consistently reproduce the issue
2. **Isolate**: Narrow down to specific component
3. **Research**: Check documentation and error messages
4. **Test**: Try solution in isolated environment first
5. **Document**: Record solution for future reference

### Tools That Helped

- **AWS Console**: Visual verification of resources
- **Docker logs**: Container debugging
- **SSH verbose mode**: Connection troubleshooting
- **Terraform plan**: Preview changes before applying
- **GitHub Actions logs**: CI/CD debugging

---

## Conclusion

Every challenge encountered provided valuable learning opportunities. The key to overcoming technical hurdles is:

- Systematic debugging approach
- Reading documentation thoroughly
- Testing incrementally
- Documenting solutions for future reference

These challenges and their solutions form the foundation of practical DevOps experience.
