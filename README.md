# Certificate Tracker - EKS Deployment (3-tier)

Production-ready deployment of Certificate Tracker application on AWS EKS (Elastic Kubernetes Service).

## Architecture

```mermaid
flowchart TB
    Users["👥 Internet Users"]
    
    subgraph DevOps["🔧 Development & CI/CD"]
        direction LR
        ReactApp["⚛️ ReactJS App<br/>(Source Code)"]
        NodeApp["🟢 NodeJS API<br/>(Source Code)"]
        DBImage["🐘 PostgreSQL<br/>(Custom Image)"]
        AdminImage["🔧 pgAdmin<br/>(Custom Image)"]
    end
    
    subgraph Build["📦 Docker Build Process"]
        FrontendBuild["Frontend Build<br/>npm run build"]
        BackendBuild["Backend Build<br/>npm install"]
        DBBuild["DB Dockerfile<br/>+ init scripts"]
        AdminBuild["pgAdmin Dockerfile"]
    end
    
    subgraph ECR["☁️ Amazon ECR - Singapore"]
        direction TB
        FrontendImg["🔷 Frontend Image<br/>:latest"]
        BackendImg["🔷 Backend Image<br/>:latest"]
        PostgresImg["🔷 Postgres Image<br/>:latest"]
        AdminImg["🔷 pgAdmin Image<br/>:latest"]
    end
    
    subgraph AWS["🌐 AWS Cloud - ap-southeast-1"]
        subgraph VPC["Virtual Private Cloud (10.0.0.0/16)"]
            subgraph PublicSubnet["Public Subnets (2 AZs)"]
                IGW["🌐 Internet Gateway"]
                NAT["🔀 NAT Gateway"]
                ALB["⚖️ Application Load Balancers<br/>(3x AWS ELB)"]
            end
            
            subgraph PrivateSubnet["Private Subnets (2 AZs)"]
                subgraph EKS["🎯 EKS Cluster v1.30<br/>certificate-tracker"]
                    subgraph ConfigLayer["Configuration Layer"]
                        NS["📦 Namespace<br/>certificate-tracker"]
                        Secrets["🔐 Secrets<br/>DB Credentials, SMTP"]
                        PVC["💾 PVC - 10Gi<br/>gp2 EBS Volume"]
                    end
                    
                    subgraph Workloads["Workload Layer"]
                        subgraph FrontendDep["Frontend Deployment"]
                            FE1["⚛️ Pod 1<br/>ReactJS:3000"]
                            FE2["⚛️ Pod 2<br/>ReactJS:3000"]
                        end
                        
                        subgraph BackendDep["Backend Deployment"]
                            BE1["🟢 Pod 1<br/>NodeJS:5000"]
                            BE2["🟢 Pod 2<br/>NodeJS:5000"]
                        end
                        
                        subgraph DatabaseDep["Database Deployment"]
                            PG["🐘 PostgreSQL<br/>Port: 5432<br/>DB: Kgcarv2"]
                        end
                        
                        subgraph AdminDep["Admin Tool"]
                            PGA["🔧 pgAdmin<br/>Port: 80"]
                        end
                    end
                    
                    subgraph ServiceLayer["Service Layer"]
                        FESvc["Frontend Service<br/>LoadBalancer:80→3000"]
                        BESvc["Backend Service<br/>LoadBalancer:5000"]
                        PGSvc["Postgres Service<br/>ClusterIP:5432"]
                        PGASvc["pgAdmin Service<br/>LoadBalancer:80"]
                    end
                    
                    subgraph NodeGroup["🖥️ EC2 Node Group"]
                        Node1["t3.medium Node 1<br/>2 vCPU, 4GB RAM"]
                        Node2["t3.medium Node 2<br/>2 vCPU, 4GB RAM"]
                    end
                end
            end
        end
    end
    
    %% Build Process
    ReactApp --> FrontendBuild
    NodeApp --> BackendBuild
    DBImage --> DBBuild
    AdminImage --> AdminBuild
    
    FrontendBuild --> FrontendImg
    BackendBuild --> BackendImg
    DBBuild --> PostgresImg
    AdminBuild --> AdminImg
    
    %% ECR to Pods
    FrontendImg -.->|Pull Image| FE1
    FrontendImg -.->|Pull Image| FE2
    BackendImg -.->|Pull Image| BE1
    BackendImg -.->|Pull Image| BE2
    PostgresImg -.->|Pull Image| PG
    AdminImg -.->|Pull Image| PGA
    
    %% Config to Pods
    Secrets -.->|Inject Env| BE1
    Secrets -.->|Inject Env| BE2
    Secrets -.->|Inject Env| PG
    Secrets -.->|Inject Env| PGA
    PVC -.->|Mount Volume| PG
    
    %% Pod Scheduling
    FE1 & FE2 -.->|Scheduled on| Node1
    BE1 & BE2 -.->|Scheduled on| Node2
    PG & PGA -.->|Scheduled on| Node1
    
    %% Service Connections
    FE1 --> FESvc
    FE2 --> FESvc
    BE1 --> BESvc
    BE2 --> BESvc
    PG --> PGSvc
    PGA --> PGASvc
    
    %% Application Flow
    FESvc -->|HTTP Requests| BESvc
    BESvc -->|SQL Queries| PGSvc
    PGASvc -->|Admin Queries| PGSvc
    
    %% Load Balancers
    FESvc --> ALB
    BESvc --> ALB
    PGASvc --> ALB
    
    %% Internet Access
    Users --> IGW
    IGW --> ALB
    NAT -.->|Outbound Traffic| IGW
    Node1 & Node2 -.->|Internet via| NAT
    
    %% Styling
    classDef frontend fill:#61dafb,stroke:#000,stroke-width:2px,color:#000
    classDef backend fill:#68a063,stroke:#000,stroke-width:2px,color:#fff
    classDef database fill:#336791,stroke:#000,stroke-width:2px,color:#fff
    classDef aws fill:#ff9900,stroke:#000,stroke-width:3px,color:#000
    classDef storage fill:#4169e1,stroke:#000,stroke-width:2px,color:#fff
    classDef config fill:#9370db,stroke:#000,stroke-width:2px,color:#fff
    
    class FE1,FE2,FESvc,FrontendDep,ReactApp,FrontendImg,FrontendBuild frontend
    class BE1,BE2,BESvc,BackendDep,NodeApp,BackendImg,BackendBuild backend
    class PG,PGSvc,PGA,PGASvc,DatabaseDep,AdminDep,DBImage,PostgresImg,AdminImg,DBBuild,AdminBuild database
    class ECR,ALB,IGW,NAT,AWS,VPC aws
    class PVC,EBS storage
    class Secrets,NS,ConfigLayer config
```

## Component Details

### Application Tier
| Component | Replicas | Technology | Port | Purpose |
|-----------|----------|------------|------|---------|
| **Frontend** | 2 | ReactJS | 3000 | User Interface |
| **Backend** | 2 | NodeJS | 5000 | REST API & Business Logic |
| **Database** | 1 | PostgreSQL | 5432 | Data Persistence |
| **pgAdmin** | 1 | pgAdmin4 | 80 | Database Management |

### Infrastructure Tier
| Resource | Type | Specification | Purpose |
|----------|------|---------------|---------|
| **EKS Cluster** | v1.30 | Managed Kubernetes | Container Orchestration |
| **Worker Nodes** | t3.medium | 2 vCPU, 4GB RAM | Application Runtime |
| **Storage** | EBS gp2 | 10Gi | Database Persistence |
| **Load Balancers** | AWS ELB | 3 instances | Public Access |
| **VPC** | 10.0.0.0/16 | 2 Public + 2 Private Subnets | Network Isolation |
| **ECR** | Private Registry | ap-southeast-1 | Container Images |

**Infrastructure:**
- **Cloud Provider**: AWS (Singapore - ap-southeast-1)
- **Kubernetes**: Amazon EKS 1.30
- **Container Registry**: Amazon ECR
- **Storage**: EBS Volumes (gp2)
- **Load Balancers**: AWS ELB

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** configured with credentials
   ```bash
   aws configure
   ```

2. **Terraform** (>= 1.9)
   ```bash
   terraform --version
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **Docker images** pushed to ECR:
   - `346273507930.dkr.ecr.ap-southeast-1.amazonaws.com/certificate-tracker/frontend:latest`
   - `346273507930.dkr.ecr.ap-southeast-1.amazonaws.com/certificate-tracker/backend:latest`
   - `346273507930.dkr.ecr.ap-southeast-1.amazonaws.com/certificate-tracker/postgres:latest`
   - `346273507930.dkr.ecr.ap-southeast-1.amazonaws.com/certificate-tracker/pgadmin:latest`

## Project Structure

```
.
├── terraform/           # Infrastructure as Code
│   ├── provider.tf      # AWS provider configuration
│   ├── variables.tf     # Customizable settings
│   ├── vpc.tf          # Network (VPC, subnets, NAT gateway)
│   ├── eks.tf          # EKS cluster & node groups
│   └── outputs.tf      # Important outputs after deployment
│
└── k8s/                # Kubernetes manifests
    ├── namespace.yaml           # certificate-tracker namespace
    ├── secret.yaml             # Database & app credentials
    ├── postgres-pvc.yaml       # Database storage (10Gi)
    ├── postgres-deployment.yaml # PostgreSQL database
    ├── postgres-service.yaml    # Database service
    ├── backend-deployment.yaml  # NodeJS backend (2 replicas)
    ├── backend-service.yaml     # Backend service
    ├── frontend-deployment.yaml # ReactJS frontend (2 replicas)
    ├── frontend-service.yaml    # Frontend LoadBalancer
    ├── pgadmin-deployment.yaml  # pgAdmin admin tool
    └── pgadmin-service.yaml     # pgAdmin LoadBalancer
```

## Deployment Steps

### 1. Create EKS Cluster

```bash
# Navigate to terraform directory
cd terraform/

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Create cluster (~15 minutes)
terraform apply -auto-approve
```

### 2. Configure kubectl

```bash
# Connect kubectl to your EKS cluster
aws eks update-kubeconfig --region ap-southeast-1 --name certificate-tracker-cluster

# Verify connection
kubectl get nodes
```

### 3. Deploy Application

```bash
# Navigate back to project root
cd ..

# Deploy in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/pgadmin-deployment.yaml
kubectl apply -f k8s/pgadmin-service.yaml

# Or deploy all at once
kubectl apply -f k8s/
```

### 4. Initialize Database

```bash
# Copy SQL initialization file to postgres pod
kubectl cp init-combined.sql certificate-tracker/$(kubectl get pod -n certificate-tracker -l app=postgres -o jsonpath='{.items[0].metadata.name}'):/tmp/init-combined.sql

# Execute SQL file
kubectl exec -i deployment/postgres -n certificate-tracker -- psql -U postgres -d Kgcarv2 < init-combined.sql

# Restart backend to clear cache
kubectl rollout restart deployment/backend -n certificate-tracker
```

### 5. Get Application URLs

```bash
# Get all service URLs
kubectl get svc -n certificate-tracker

# Frontend URL
kubectl get svc frontend-service -n certificate-tracker -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Backend API URL
kubectl get svc backend-service -n certificate-tracker -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# pgAdmin URL
kubectl get svc pgadmin-service -n certificate-tracker -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Configuration

### Environment Variables

All sensitive data is stored in `k8s/secret.yaml`:

- **Database**: `Kgcarv2` on port `5432`
- **DB User**: `postgres`
- **SMTP**: Configured for email notifications
- **Ports**: Backend `5000`, Frontend `3000`

### Cluster Settings (terraform/variables.tf)

- **Cluster Name**: `certificate-tracker-cluster`
- **Kubernetes Version**: `1.30`
- **Node Type**: `t3.medium` (2 vCPU, 4GB RAM)
- **Node Count**: 2 (min: 1, max: 4)
- **VPC CIDR**: `10.0.0.0/16`

## Management Commands

### Check Application Status

```bash
# View all resources
kubectl get all -n certificate-tracker

# Check pod status
kubectl get pods -n certificate-tracker

# Check pod logs
kubectl logs -f deployment/backend -n certificate-tracker
kubectl logs -f deployment/frontend -n certificate-tracker
kubectl logs -f deployment/postgres -n certificate-tracker
```

### Update Deployments

```bash
# After pushing new Docker image to ECR
kubectl rollout restart deployment/backend -n certificate-tracker
kubectl rollout restart deployment/frontend -n certificate-tracker

# Check rollout status
kubectl rollout status deployment/backend -n certificate-tracker
```

### Access Database

**Via pgAdmin:**
- URL: Get from LoadBalancer
- Email: `admin@admin.com`
- Password: `admin`

**Via kubectl:**
```bash
# Connect to database directly
kubectl exec -it deployment/postgres -n certificate-tracker -- psql -U postgres -d Kgcarv2

# Run SQL query
kubectl exec -it deployment/postgres -n certificate-tracker -- psql -U postgres -d Kgcarv2 -c "SELECT * FROM users;"
```

## Troubleshooting

### Backend can't connect to database
```bash
# Check database is running
kubectl get pods -l app=postgres -n certificate-tracker

# Check backend logs
kubectl logs deployment/backend -n certificate-tracker
```

### Frontend can't connect to backend
```bash
# Verify backend is running
kubectl get svc backend-service -n certificate-tracker

# Frontend needs to be rebuilt with correct backend URL
```

### LoadBalancer pending
```bash
# Wait a few minutes (2-5 min normal)
kubectl get svc -n certificate-tracker -w
```

## Cleanup

### Delete Application Only
```bash
kubectl delete namespace certificate-tracker
```

### Delete Everything (Cluster + Application)
```bash
cd terraform/
terraform destroy -auto-approve
```

**Warning**: This will delete all data and resources. Backup database first!

## Production Checklist

Before going live:
- [ ] Configure custom domain with Route53
- [ ] Set up SSL/TLS certificates (ACM + AWS Load Balancer Controller)
- [ ] Add resource limits to all deployments
- [ ] Add health probes (readiness/liveness)
- [ ] Implement database backup strategy
- [ ] Set up monitoring (CloudWatch/Prometheus)
- [ ] Configure autoscaling
- [ ] Use AWS Secrets Manager instead of Kubernetes secrets
- [ ] Secure pgAdmin (remove public access)
- [ ] Set up CI/CD pipeline

## Support

For issues or questions:
- Check pod logs: `kubectl logs deployment/<name> -n certificate-tracker`
- Describe resources: `kubectl describe pod/<name> -n certificate-tracker`
- View events: `kubectl get events -n certificate-tracker --sort-by='.lastTimestamp'`

---

**Deployed by**: Terraform + Kubernetes
**Maintained by**: rxnjitth
**Last Updated**: January 26, 2026
