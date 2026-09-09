# 2048 on Amazon EKS

![AWS](https://img.shields.io/badge/AWS-EKS-orange)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34-blue)
![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)
![Helm](https://img.shields.io/badge/Helm-Package%20Manager-blue)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-red)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-blue)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-orange)
![Grafana](https://img.shields.io/badge/Grafana-Observability-orange)
![Trivy](https://img.shields.io/badge/Trivy-Container%20Scanning-blue)
![Checkov](https://img.shields.io/badge/Checkov-IaC%20Security-green)
![OIDC](https://img.shields.io/badge/Security-OIDC%20%2F%20IRSA-green)

A containerised 2048 application deployed on Amazon EKS, with AWS infrastructure provisioned using Terraform and application delivery managed through GitHub Actions and ArgoCD.

The project was built to bring the main parts of a modern DevOps platform together in one place: networking, Kubernetes, infrastructure as code, container delivery, GitOps, DNS, HTTPS, CI/CD, security scanning and monitoring.

<p align="center">
  <img src="assets/EKS%20Architecture.png" width="1000" alt="2048 EKS Architecture">
</p>

**Live application:** https://2048.nabilenv.com

**Detailed documentation:** [END_TO_END_DOCUMENTATION.md](END_TO_END_DOCUMENTATION.md)  
**Troubleshooting record:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Table of Contents

- [Overview](#overview)
- [Platform Demo](#platform-demo)
- [Architecture Overview](#architecture-overview)
  - [Networking](#networking)
  - [Compute](#compute)
  - [Ingress](#ingress)
  - [Application](#application)
  - [DNS and TLS](#dns-and-tls)
  - [Container Registry](#container-registry)
  - [Terraform State and Resource Tagging](#terraform-state-and-resource-tagging)
- [Repository Structure](#repository-structure)
- [GitOps Workflow](#gitops-workflow)
- [CI/CD Pipelines](#cicd-pipelines)
  - [Terraform Pipeline](#terraform-pipeline)
  - [Application Release Pipeline](#application-release-pipeline)
- [Observability](#observability)
- [Security](#security)
- [Key Technical Decisions](#key-technical-decisions)
- [Known Limitations and Future Improvements](#known-limitations-and-future-improvements)
- [Quick Start](#quick-start)
- [Technologies Used](#technologies-used)

---

## Overview

The 2048 application is packaged as a Docker image and stored in Amazon ECR. Amazon EKS runs the workload on a managed node group inside private subnets, while an internet-facing Application Load Balancer exposes the application over HTTPS.

Terraform manages the AWS infrastructure. ArgoCD manages the Kubernetes workloads from Git, and GitHub Actions provides separate pipelines for infrastructure changes and application releases.

Cloudflare manages the DNS zone, ExternalDNS maintains the application DNS record, and AWS Certificate Manager provides the TLS certificate.

The final application is available at:

**https://2048.nabilenv.com**

---

## Platform Demo

<p align="center">
  <img src="assets/2048-demo.gif" width="850" alt="2048 application running on Amazon EKS">
</p>

The demo shows the application running through the real custom domain rather than a local or temporary endpoint.

---

## Architecture Overview

The platform runs in AWS `eu-west-2` across two Availability Zones.

### Networking

- VPC: `10.0.0.0/16`
- Public subnet in `eu-west-2a`: `10.0.1.0/24`
- Public subnet in `eu-west-2b`: `10.0.2.0/24`
- Private subnet in `eu-west-2a`: `10.0.3.0/24`
- Private subnet in `eu-west-2b`: `10.0.4.0/24`
- EKS worker nodes run in the private subnets
- A single NAT Gateway provides outbound access for the private subnets
- The internet-facing ALB uses the public subnet layer

> [!NOTE]
> A single NAT Gateway was used to keep the development environment simpler and cheaper. A production design would normally consider one NAT Gateway per Availability Zone to remove that dependency.

### Compute

- Amazon EKS `1.34`
- EKS managed node group
- `t3.small` worker nodes
- `ON_DEMAND` capacity
- Minimum nodes: `1`
- Desired nodes: `3`
- Maximum nodes: `3`
- Worker nodes run in private subnets

The cluster explicitly manages the main EKS add-ons:

```text
CoreDNS
kube-proxy
VPC CNI
```

VPC CNI is configured before compute so networking is available when the managed nodes join the cluster.

EKS control-plane logging is enabled for:

```text
api
audit
authenticator
controllerManager
scheduler
```

> [!NOTE]
> The cluster originally ran with fewer workers. Installing the monitoring stack pushed the existing `t3.small` nodes past their pod capacity, so the desired node count was increased to three.

### Ingress

- AWS Load Balancer Controller watches the Kubernetes Ingress resource
- An internet-facing Application Load Balancer is provisioned automatically
- The ALB uses IP targets
- HTTP port `80` redirects to HTTPS port `443`
- AWS Certificate Manager provides the TLS certificate for `2048.nabilenv.com`
- Traffic is routed to the `app-2048` Kubernetes Service and then to the application pods

> [!NOTE]
> A separate ingress controller such as Traefik or ingress-nginx was not required. The AWS Load Balancer Controller maps the Kubernetes Ingress directly to an AWS ALB.

### Application

The application runs as a Kubernetes Deployment with two replicas.

```text
Replicas:        2
CPU request:     50m
CPU limit:       200m
Memory request:  64Mi
Memory limit:    128Mi
```

The Deployment is exposed internally through a ClusterIP Service named `app-2048`.

Each released image is tagged with the Git commit SHA, giving a direct link between a running container image and the source revision that created it.

### DNS and TLS

Cloudflare manages the `nabilenv.com` DNS zone.

ExternalDNS watches the Kubernetes Ingress and automatically maintains:

```text
2048.nabilenv.com
```

AWS Certificate Manager provides the HTTPS certificate. Certificate ownership is validated using an ACM CNAME record in Cloudflare.

The final request path is:

```text
User
  ↓
Cloudflare DNS
  ↓
2048.nabilenv.com
  ↓
AWS Application Load Balancer
  ↓
Kubernetes Ingress
  ↓
app-2048 Service
  ↓
2048 Pods
```

### Container Registry

Amazon ECR stores the `2048-app` images.

The repository has:

- immutable image tags
- ECR scan-on-push enabled
- Trivy scanning in the application release pipeline before the image is pushed

### Terraform State and Resource Tagging

Terraform state is stored remotely in S3:

```text
Bucket: 2048-eks-platform-terraform-state-2026
Key:    dev/terraform.tfstate
```

The state bucket uses versioning, server-side encryption and public-access blocking. Native S3 lock files are enabled with `use_lockfile = true`.

Terraform-managed AWS resources use a consistent tagging baseline:

```text
Project
Environment
ManagedBy = Terraform
```

Key named resources also use a `Name` tag, and the Terraform state bucket uses `Purpose = TerraformState`.

> [!NOTE]
> The AWS provider also defines `default_tags`, while important resources and modules include explicit tags in their Terraform files so ownership is visible during code review as well as in AWS.

---

## Repository Structure

```text
2048-eks-platform/
├── .github/
│   └── workflows/
│       ├── app-release.yml
│       └── terraform.yml
│
├── app/
│   ├── Dockerfile
│   ├── index.html
│   ├── js/
│   ├── meta/
│   └── style/
│
├── assets/
│   ├── 2048-demo.gif
│   ├── App-release pipeline.png
│   ├── ArgoCD.png
│   ├── EKS Architecture.png
│   ├── Grafana Dashboard.png
│   ├── terraform-apply.png
│   └── terraform-plan.png
│
├── kubernetes/
│   ├── app/
│   │   ├── deployment.yml
│   │   ├── ingress.yml
│   │   └── service.yml
│   ├── argocd/
│   │   ├── application.yml
│   │   ├── aws-lbc-app.yml
│   │   ├── external-dns-app.yml
│   │   └── monitoring-app.yml
│   ├── aws-load-balancer-controller/
│   │   ├── service-account.yml
│   │   └── values.yml
│   ├── external-dns/
│   │   └── values.yml
│   └── monitoring/
│       └── values.yml
│
├── terraform/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── environments/
│   │   └── dev/
│   │       ├── backend.tf
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       ├── providers.tf
│   │       ├── variables.tf
│   │       └── versions.tf
│   └── modules/
│       ├── ecr/
│       ├── eks/
│       ├── iam/
│       └── vpc/
│
├── END_TO_END_DOCUMENTATION.md
├── TROUBLESHOOTING.md
├── .gitignore
└── README.md
```

Terraform is separated into a bootstrap layer, a `dev` environment composition layer and reusable VPC, ECR, IAM and EKS modules.

---

## GitOps Workflow

ArgoCD manages the Kubernetes side of the platform, with Git acting as the source of truth.

```text
GitHub Repository
       ↓
     ArgoCD
       ↓
   Amazon EKS
```

ArgoCD manages:

```text
2048-app
aws-lbc
external-dns
monitoring
```

Automated sync, pruning and self-healing are enabled.

Self-healing was tested by manually scaling the application away from the value stored in Git. ArgoCD detected the drift and restored the Deployment to the two replicas defined in the repository.

The application release pipeline follows the same model. GitHub Actions does not run `kubectl apply`. Instead, it updates the image tag in `kubernetes/app/deployment.yml` and commits that change back to Git.

```text
Application change
      ↓
Docker image built
      ↓
Trivy scan
      ↓
Image pushed to ECR
      ↓
deployment.yml updated
      ↓
Commit to Git
      ↓
ArgoCD detects change
      ↓
EKS deployment updated
```

<p align="center">
  <img src="assets/ArgoCD.png" width="850" alt="ArgoCD Applications">
</p>

---

## CI/CD Pipelines

The repository has two GitHub Actions workflows:

```text
.github/workflows/terraform.yml
.github/workflows/app-release.yml
```

Both authenticate to AWS using GitHub OIDC rather than stored AWS access keys.

### Terraform Pipeline

For pull requests containing changes under `terraform/**`:

```text
Checkout
   ↓
OIDC → Terraform plan role
   ↓
Terraform init
   ↓
Terraform validate
   ↓
Checkov
   ↓
Terraform plan
```

No infrastructure changes are applied from a pull request.

After Terraform changes reach `main`:

```text
Checkout
   ↓
OIDC → Terraform apply role
   ↓
Terraform init
   ↓
Terraform validate
   ↓
Checkov
   ↓
Terraform plan
   ↓
Terraform apply
```

Separate IAM roles are used for plan and apply so pull requests do not receive the same write permissions as the main-branch deployment job.

<p align="center">
  <img src="assets/terraform-plan.png" width="320" alt="Terraform Plan Pipeline">
  <img src="assets/terraform-apply.png" width="320" alt="Terraform Apply Pipeline">
</p>

### Application Release Pipeline

Changes under `app/**` on `main`, or a manual `workflow_dispatch`, run the application release workflow:

```text
Checkout
   ↓
OIDC → Application release role
   ↓
Login to ECR
   ↓
Docker build
   ↓
Trivy scan
   ↓
Push image to ECR
   ↓
Update deployment.yml
   ↓
Commit new image tag
   ↓
ArgoCD rollout
```

Trivy checks `HIGH` and `CRITICAL` vulnerabilities. The workflow ignores vulnerabilities with no available fix and fails on findings that breach the configured policy.

<p align="center">
  <img src="assets/App-release%20pipeline.png" width="650" alt="Application Release Pipeline">
</p>

---

## Observability

Monitoring is provided by `kube-prometheus-stack` and deployed through ArgoCD.

The stack includes:

- Prometheus
- Grafana
- Alertmanager
- Node Exporter
- kube-state-metrics
- Kubernetes ServiceMonitors

Prometheus retains metrics for seven days. Grafana provides dashboards for cluster, node, pod, workload, API server, kubelet and networking metrics.

<p align="center">
  <img src="assets/Grafana%20Dashboard.png" width="850" alt="Grafana Dashboard">
</p>

---

## Security

### IAM and GitHub OIDC

GitHub Actions uses OIDC to obtain short-lived AWS credentials. Dedicated roles are used for:

```text
Terraform plan
Terraform apply
Application release
```

The trust policies restrict which GitHub repository/branch can assume each role.

### IRSA

AWS Load Balancer Controller uses IAM Roles for Service Accounts. Its Kubernetes service account is linked to a dedicated AWS IAM role rather than storing AWS credentials inside the pod.

### Infrastructure Security Scanning

Checkov scans the repository's Terraform before plan/apply continues.

### Container Security Scanning

Trivy scans the application image before it is pushed to ECR.

### Kubernetes Secrets

Sensitive values such as the Cloudflare API token and Grafana administrator password are stored as Kubernetes Secrets and are not committed to Git.

### KMS Encryption

The EKS cluster uses AWS KMS for Kubernetes secrets encryption at rest.

---

## Key Technical Decisions

### ALB instead of NLB and Traefik

The AWS Load Balancer Controller provisions an ALB directly from the Kubernetes Ingress.

> [!NOTE]
> This keeps the traffic path smaller and avoids adding another ingress controller purely for routing this application.

### GitOps instead of direct Kubernetes deployment

GitHub Actions publishes the image and changes Git. ArgoCD performs the Kubernetes reconciliation.

> [!NOTE]
> This keeps the desired application version in Git rather than allowing CI and Git to become separate deployment sources.

### Cloudflare with ExternalDNS

The domain was already managed by Cloudflare, so ExternalDNS was configured to maintain Cloudflare records rather than adding Route 53 solely for this project.

### Separate Terraform plan and apply roles

Pull requests use a read-focused plan role. Main-branch deployments use a separate apply role.

> [!WARNING]
> Some apply-role permissions are still broader than I would use in a tightly regulated production environment. Further resource-level scoping is a future improvement.

### OIDC instead of AWS access keys

No long-lived AWS access key or secret access key is required by either GitHub Actions pipeline.

### ON_DEMAND worker nodes

The node group uses `t3.small` ON_DEMAND instances for predictable availability in this portfolio environment.

> [!WARNING]
> Cluster Autoscaler or Karpenter is not configured. Node capacity is currently controlled through the managed node group and Terraform.

---

## Known Limitations and Future Improvements

This is a portfolio/development platform rather than a production service. Improvements for a larger environment would include:

- Cluster Autoscaler or Karpenter
- larger or workload-specific node groups
- one NAT Gateway per Availability Zone
- tighter Terraform apply IAM permissions
- more complete ACM/DNS automation
- External Secrets Operator or another external secret-management platform
- remote long-term Prometheus storage
- Alertmanager notification integrations
- Kubernetes admission/policy enforcement
- separate development/staging/production environments
- a controlled infrastructure destroy workflow
- private-only EKS API access where operationally practical
- multi-region resilience if the workload required it

---

## Quick Start

The steps below show the intended deployment order. For the full explanation, commands and troubleshooting history, use [END_TO_END_DOCUMENTATION.md](END_TO_END_DOCUMENTATION.md).

### Prerequisites

You will need:

- AWS account
- GitHub repository
- Cloudflare account and managed domain
- AWS CLI
- Terraform
- Docker
- kubectl
- Helm
- Git

### 1. Clone the Repository

```bash
git clone https://github.com/nabilislam30/2048-eks-platform.git
cd 2048-eks-platform
```

### 2. Replace Environment-Specific Values

This repository records the real deployed environment, so a fork cannot reuse every identifier unchanged.

Before reproducing it elsewhere, update the relevant values for your environment:

- Terraform S3 state bucket name
- AWS account ID / ECR registry
- EKS administrator IAM principal
- GitHub immutable owner/repository IDs used by the OIDC trust policies
- GitHub Actions role ARNs
- AWS Load Balancer Controller IRSA role ARN
- VPC ID in `kubernetes/aws-load-balancer-controller/values.yml`
- GitHub repository URLs in the ArgoCD Application files
- domain name in ExternalDNS/Ingress
- ACM certificate ARN

> [!IMPORTANT]
> The detailed file-by-file replacement checklist is in [END_TO_END_DOCUMENTATION.md](END_TO_END_DOCUMENTATION.md#10-how-to-reproduce-the-project-from-zero).

### 3. Configure AWS

```bash
export AWS_PROFILE=<your-profile>
aws sts get-caller-identity
```

Confirm the returned account before continuing.

### 4. Bootstrap Terraform State

```bash
cd terraform/bootstrap
terraform init

terraform apply \
  -var="aws_region=eu-west-2" \
  -var="aws_profile=<your-profile>" \
  -var="project_name=2048-eks-platform" \
  -var="state_bucket_name=<your-unique-state-bucket>"

cd ../..
```

Update `terraform/environments/dev/backend.tf` if you use a different bucket name.

### 5. Configure Local Terraform Variables

Create:

```text
terraform/environments/dev/terraform.tfvars
```

Example:

```hcl
aws_region   = "eu-west-2"
project_name = "2048-eks-platform"
environment  = "dev"

vpc_cidr = "10.0.0.0/16"

availability_zones = ["eu-west-2a", "eu-west-2b"]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.3.0/24",
  "10.0.4.0/24"
]

repository_name = "2048-app"

cluster_name    = "2048-eks-cluster"
cluster_version = "1.34"

instance_types = ["t3.small"]

min_size     = 1
max_size     = 3
desired_size = 3

capacity_type = "ON_DEMAND"

public_access_cidrs = [
  "<YOUR-PUBLIC-IP>/32"
]
```

`terraform.tfvars` is excluded from Git.

### 6. Provision the Initial AWS Infrastructure

The GitHub OIDC roles do not exist until Terraform creates them, so the first deployment must use an AWS identity that already has permission to create the infrastructure.

```bash
cd terraform/environments/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
cd ../../..
```

This creates the VPC, ECR repository, IAM roles/OIDC provider, EKS cluster, managed node group and the AWS Load Balancer Controller IRSA role.

### 7. Configure GitHub Actions

Open:

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
```

Create these **repository variables**:

| Variable | Value |
|---|---|
| `AWS_REGION` | `eu-west-2` |
| `PROJECT_NAME` | `2048-eks-platform` |
| `ENVIRONMENT` | `dev` |
| `REPOSITORY_NAME` | `2048-app` |
| `VPC_CIDR` | `10.0.0.0/16` |
| `AVAILABILITY_ZONES` | `["eu-west-2a","eu-west-2b"]` |
| `PUBLIC_SUBNET_CIDRS` | `["10.0.1.0/24","10.0.2.0/24"]` |
| `PRIVATE_SUBNET_CIDRS` | `["10.0.3.0/24","10.0.4.0/24"]` |
| `CLUSTER_NAME` | `2048-eks-cluster` |
| `CLUSTER_VERSION` | `1.34` |
| `INSTANCE_TYPES` | `["t3.small"]` |
| `MIN_SIZE` | `1` |
| `MAX_SIZE` | `3` |
| `DESIRED_SIZE` | `3` |
| `CAPACITY_TYPE` | `ON_DEMAND` |

Create this **repository secret**:

| Secret | Example |
|---|---|
| `EKS_PUBLIC_ACCESS_CIDRS` | `["203.0.113.10/32"]` |

Use your real public IP instead of the example.

> [!NOTE]
> AWS access keys are not required in GitHub Secrets because the workflows authenticate with OIDC.

### 8. Connect kubectl to EKS

```bash
aws eks update-kubeconfig \
  --region eu-west-2 \
  --name 2048-eks-cluster

kubectl get nodes
```

The workers should report `Ready`.

### 9. Publish an Initial Application Image

A new AWS account needs an image in its own ECR repository before the application can run.

After updating the app-release workflow with your account/role details, either run the `app-release` workflow manually using `workflow_dispatch`, or build and push an AMD64 image yourself.

For Apple Silicon:

```bash
aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com

docker buildx build \
  --platform linux/amd64 \
  -t <ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com/2048-app:<TAG> \
  --push \
  ./app
```

Make sure `kubernetes/app/deployment.yml` references an image tag that exists.

### 10. Create the AWS Load Balancer Controller Service Account

The Helm chart is configured with `serviceAccount.create: false`, so the IRSA-enabled service account must exist before the controller is synced:

```bash
kubectl apply -f kubernetes/aws-load-balancer-controller/service-account.yml
```

### 11. Install ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 10.4.0

kubectl get pods -n argocd
```

### 12. Create ExternalDNS and Grafana Secrets

ExternalDNS:

```bash
kubectl create namespace external-dns
read -s CF_API_TOKEN
kubectl create secret generic cloudflare-api-token \
  -n external-dns \
  --from-literal=apiToken="$CF_API_TOKEN"
unset CF_API_TOKEN
```

Grafana:

```bash
kubectl create namespace monitoring
read -s GRAFANA_PASSWORD
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$GRAFANA_PASSWORD"
unset GRAFANA_PASSWORD
```

> [!WARNING]
> Do not commit either secret value to the repository.

### 13. Configure ACM

Request an ACM certificate in `eu-west-2` for your application hostname.

Add the ACM validation CNAME to Cloudflare as **DNS only**, wait for the certificate to become `ISSUED`, then update the certificate ARN in:

```text
kubernetes/app/ingress.yml
```

### 14. Deploy the ArgoCD Applications

```bash
kubectl apply -f kubernetes/argocd/
kubectl get applications -n argocd
```

Expected final applications:

```text
2048-app       Synced   Healthy
aws-lbc        Synced   Healthy
external-dns   Synced   Healthy
monitoring     Synced   Healthy
```

### 15. Verify the Platform

```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployment 2048-app
kubectl get service app-2048
kubectl get ingress app-2048
```

DNS/HTTPS checks:

```bash
dig 2048.nabilenv.com
curl -I http://2048.nabilenv.com
curl -I https://2048.nabilenv.com
```

The HTTP request should redirect to HTTPS and the HTTPS request should return the live application.

### 16. Verify GitOps and Monitoring

Test ArgoCD self-healing:

```bash
kubectl scale deployment 2048-app --replicas=3
```

ArgoCD should restore the Deployment to the two replicas stored in Git.

Grafana can be reached locally with:

```bash
kubectl port-forward service/monitoring-grafana -n monitoring 3000:80
```

### 17. Verify CI/CD

For Terraform, open a pull request containing a safe `terraform/**` change and confirm the plan job succeeds before merge. After merge, confirm the main-branch apply job succeeds.

For the application pipeline, change a file under `app/**` or use `workflow_dispatch` and confirm:

```text
Docker build
Trivy scan
ECR push
deployment.yml update
Git commit
ArgoCD rollout
```

---

## Technologies Used

| Area | Technology |
|---|---|
| Cloud | AWS |
| Containers | Docker |
| Container Registry | Amazon ECR |
| Kubernetes | Amazon EKS |
| Infrastructure as Code | Terraform |
| Kubernetes Package Management | Helm |
| GitOps | ArgoCD |
| CI/CD | GitHub Actions |
| AWS Authentication | GitHub OIDC |
| Kubernetes AWS Permissions | IRSA |
| Ingress | AWS Application Load Balancer |
| Load Balancer Integration | AWS Load Balancer Controller |
| DNS | Cloudflare |
| DNS Automation | ExternalDNS |
| TLS | AWS Certificate Manager |
| Monitoring | Prometheus |
| Dashboards | Grafana |
| Alerting | Alertmanager |
| Container Security | Trivy |
| IaC Security | Checkov |
| Terraform State | Amazon S3 |
| Encryption | AWS KMS |
| CLI | kubectl / AWS CLI |
