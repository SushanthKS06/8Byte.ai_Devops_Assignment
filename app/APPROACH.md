# APPROACH.md

## Infrastructure and Tool Selection Rationale

This document explains the technical decisions made during the design and implementation of this DevOps project.

---

## 1. Cloud Provider: AWS

### Why AWS?

- **Industry Standard**: Most widely adopted cloud platform with extensive documentation
- **Free Tier**: t2.micro instances available under AWS Free Tier for cost-effective learning
- **Mature Services**: Proven reliability and extensive service ecosystem
- **Job Market Relevance**: High demand for AWS skills in DevOps roles

### Alternatives Considered

- **Azure**: Strong enterprise integration but steeper learning curve
- **GCP**: Excellent for containerized workloads but smaller market share
- **Decision**: AWS chosen for its balance of features, documentation, and industry adoption

---

## 2. Infrastructure as Code: Terraform

### Why Terraform?

- **Cloud-Agnostic**: Can manage multi-cloud infrastructure with same tooling
- **Declarative Syntax**: HCL is readable and maintainable
- **State Management**: Tracks infrastructure state for consistent deployments
- **Community Support**: Large ecosystem of modules and providers
- **Industry Adoption**: De facto standard for IaC across organizations

### Alternatives Considered

- **AWS CloudFormation**: AWS-native but vendor lock-in
- **Pulumi**: Modern but less mature ecosystem
- **AWS CDK**: Powerful but requires programming language knowledge
- **Decision**: Terraform chosen for its cloud-agnostic nature and industry standard status

### Terraform Design Decisions

**Modular Structure**: Separated into provider.tf, variables.tf, main.tf, outputs.tf for maintainability

**Data Sources**: Used `aws_ami` data source to dynamically fetch latest Ubuntu 22.04 AMI instead of hardcoding

**Variables**: Externalized configuration through variables.tf and terraform.tfvars for reusability

**Outputs**: Exposed critical information (public IP, application URL) for easy access

---

## 3. Compute: EC2 with Ubuntu 22.04

### Why EC2?

- **Full Control**: Complete control over the instance and installed software
- **Simplicity**: Straightforward deployment model for learning purposes
- **Cost-Effective**: t2.micro eligible for free tier
- **SSH Access**: Direct access for debugging and manual deployment

### Why Ubuntu 22.04?

- **LTS Release**: Long-term support until 2027
- **Docker Compatibility**: Excellent Docker support and documentation
- **Package Management**: APT package manager is reliable and well-documented
- **Community**: Large community and extensive troubleshooting resources

### Alternatives Considered

- **ECS/Fargate**: Serverless containers but adds complexity
- **EKS**: Kubernetes overkill for single container application
- **Lambda**: Not suitable for long-running HTTP server
- **Decision**: EC2 chosen for simplicity and learning objectives

---

## 4. Containerization: Docker

### Why Docker?

- **Consistency**: "Works on my machine" problem solved
- **Isolation**: Application dependencies isolated from host system
- **Portability**: Same container runs locally and in production
- **Industry Standard**: Universal adoption in modern DevOps workflows
- **Lightweight**: Minimal overhead compared to VMs

### Docker Design Decisions

**Base Image**: `node:18-alpine` chosen for small size (~170MB vs ~900MB for full node image)

**Multi-stage Build**: Not implemented due to simple application, but would be used for production

**Layer Optimization**: Package.json copied before app.js to leverage Docker layer caching

**.dockerignore**: Excluded unnecessary files to reduce build context size

---

## 5. Application: Node.js with Express

### Why Node.js?

- **Simplicity**: Minimal code required for HTTP server
- **Fast Startup**: Quick container startup times
- **Lightweight**: Small memory footprint suitable for t2.micro
- **Industry Relevance**: Widely used for microservices and APIs

### Why Express?

- **Minimal Framework**: Simple and unopinionated
- **Quick Setup**: Single file application possible
- **Well-Documented**: Extensive documentation and community support

---

## 6. CI/CD: GitHub Actions

### Why GitHub Actions?

- **Native Integration**: Built into GitHub, no external service needed
- **Free for Public Repos**: Generous free tier for learning projects
- **Simple Syntax**: YAML-based workflow easy to understand
- **Marketplace**: Extensive action marketplace for common tasks
- **No Additional Setup**: No need to configure external CI/CD tools

### Alternatives Considered

- **Jenkins**: Powerful but requires separate server and maintenance
- **GitLab CI**: Excellent but requires GitLab platform
- **CircleCI**: Good but external service dependency
- **Decision**: GitHub Actions chosen for simplicity and zero additional infrastructure

### CI Pipeline Design

**Trigger**: Push to main branch for automatic builds

**Docker Buildx**: Used for advanced build features and caching

**Multi-tagging**: Both `latest` and commit SHA tags for version tracking

**Secrets Management**: GitHub Secrets for secure credential storage

---

## 7. Networking Architecture

### VPC Design

**CIDR Block**: 10.0.0.0/16 provides 65,536 IP addresses for future expansion

**Public Subnet**: 10.0.1.0/24 provides 256 addresses, sufficient for current needs

**Single AZ**: Cost optimization for learning project; production would use multi-AZ

### Why Public Subnet?

- **Simplicity**: Direct internet access without NAT Gateway costs
- **Learning Focus**: Easier to understand and troubleshoot
- **Cost**: No NAT Gateway charges (~$32/month)
- **Trade-off**: Less secure than private subnet architecture

### Security Group Design

**Principle of Least Privilege**: Only required ports opened

**SSH Restriction**: Limited to specific IP address via variable

**Port 3000**: Public access for application demonstration

**Egress**: All outbound allowed for package installation and updates

---

## 8. Automation Strategy

### User Data Script

**Docker Installation**: Automated via EC2 user_data for consistency

**Official Repository**: Used Docker's official APT repository for latest stable version

**Service Enablement**: Docker service enabled and started automatically

**User Permissions**: ubuntu user added to docker group for non-root access

### Why User Data?

- **Automation**: No manual installation steps required
- **Consistency**: Same setup every time instance is created
- **Documentation**: Installation steps codified in Terraform

---

## 9. Deployment Strategy

### Manual Deployment Choice

**Why Manual?**

- **Learning Objective**: Understand each deployment step
- **Simplicity**: Avoid complexity of automated deployment tools
- **Transparency**: Clear visibility into what's happening
- **Debugging**: Easier to troubleshoot issues

### Production Considerations

For production, would implement:
- Automated deployment via GitHub Actions
- Blue-green or rolling deployments
- Health checks and rollback mechanisms
- Infrastructure monitoring and alerting

---

## 10. State Management

### Local State

**Current Approach**: Terraform state stored locally

**Why Local?**

- **Simplicity**: No additional infrastructure required
- **Single User**: No collaboration conflicts
- **Learning Focus**: Understand state before remote backends

### Production Approach

Would use:
- **S3 Backend**: Centralized state storage
- **DynamoDB Locking**: Prevent concurrent modifications
- **State Encryption**: Secure sensitive data
- **Versioning**: State history and rollback capability

---

## 11. Security Considerations

### Implemented Security

- **IP Whitelisting**: SSH access restricted to specific IP
- **Security Groups**: Stateful firewall rules
- **Container Isolation**: Application runs in isolated container
- **VPC Isolation**: Dedicated network environment
- **No Hardcoded Credentials**: Variables and secrets used

### Production Enhancements

Would add:
- **Private Subnets**: Application in private subnet with NAT Gateway
- **Bastion Host**: Secure SSH access pattern
- **WAF**: Web Application Firewall for HTTP protection
- **Secrets Manager**: Secure credential storage
- **IAM Roles**: Instance profiles instead of access keys
- **SSL/TLS**: HTTPS with ACM certificates
- **Security Scanning**: Vulnerability scanning in CI pipeline

---

## 12. Monitoring and Observability

### Current State

- **Docker Logs**: Basic container logging
- **Manual Monitoring**: SSH access for troubleshooting

### Production Requirements

Would implement:
- **CloudWatch Logs**: Centralized log aggregation
- **CloudWatch Metrics**: CPU, memory, disk monitoring
- **CloudWatch Alarms**: Automated alerting
- **Application Metrics**: Custom application metrics
- **Distributed Tracing**: Request tracing for debugging

---

## 13. Cost Optimization

### Design Decisions

- **t2.micro**: Free tier eligible, sufficient for demo
- **Single AZ**: Reduced data transfer costs
- **No NAT Gateway**: Saved ~$32/month
- **No Load Balancer**: Saved ~$16/month
- **Public Subnet**: Direct internet access, no NAT costs

### Estimated Monthly Cost

- **EC2 t2.micro**: $0 (free tier) or ~$8.50/month
- **EBS Storage**: $0.80/month (8GB gp3)
- **Data Transfer**: Minimal for demo purposes
- **Total**: ~$1-10/month depending on free tier eligibility

---

## 14. Scalability Considerations

### Current Limitations

- **Single Instance**: No high availability
- **Manual Scaling**: No auto-scaling capability
- **Single AZ**: No fault tolerance

### Production Scaling Strategy

Would implement:
- **Auto Scaling Group**: Automatic horizontal scaling
- **Application Load Balancer**: Traffic distribution
- **Multi-AZ Deployment**: High availability
- **ECS/EKS**: Container orchestration for complex applications
- **RDS**: Managed database with read replicas
- **ElastiCache**: Caching layer for performance

---

## 15. Development Workflow

### Chosen Workflow

1. **Local Development**: Test application locally with Node.js
2. **Local Docker Build**: Verify containerization works
3. **Infrastructure Provisioning**: Deploy AWS resources with Terraform
4. **Manual Deployment**: SSH and deploy container on EC2
5. **CI Pipeline**: Automated Docker builds on code changes

### Why This Workflow?

- **Incremental Validation**: Catch issues early at each stage
- **Learning Focused**: Understand each component before automation
- **Debugging Friendly**: Easy to identify where problems occur
- **Production Path**: Clear evolution to full automation

---

## Conclusion

This architecture balances:

- **Learning Objectives**: Clear understanding of each component
- **Best Practices**: Industry-standard tools and patterns
- **Cost Efficiency**: Minimal AWS costs for demonstration
- **Production Readiness**: Clear path to production-grade deployment
- **Simplicity**: Focused on core DevOps concepts without unnecessary complexity

The chosen approach provides a solid foundation for understanding modern DevOps practices while maintaining simplicity and cost-effectiveness for a learning project.
