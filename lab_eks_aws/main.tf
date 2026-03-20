# 1. Proveedores
provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # Esto fuerza a generar un token nuevo en el momento exacto
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec ={
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
    }
  }
}

# 2. VPC (Red sencilla)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = "eks-lab-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets      = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true # Para ahorrar costos en el lab
}

# 3. Cluster EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "lab-prometheus-grafana"
  cluster_version = "1.31"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    nodes = {
      min_size     = 2
      max_size     = 4
      desired_size = 3
      instance_types = ["m7i-flex.large"] # t3.medium es lo mínimo recomendado para K8s
    }
  }
}

resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true

  # Usamos un bloque de valores YAML para sobreescribir la configuración por defecto
  values = [
    <<-EOT
    grafana:
      enabled: true
      service:
        type: LoadBalancer
    EOT
  ]
  depends_on = [module.eks]
}