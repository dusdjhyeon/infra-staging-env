terraform {
  backend "gcs" {
    bucket = "dh-env-bucket"
    prefix = "terraform/state"
  }
}

data "google_client_config" "provider" {}

locals {
  env_name        = "staging"
  project_id      = "my-first-msa"
  gcp_region      = "asia-northeast3"
  k8s_engine_name = "dh-gke"
}

variable "mysql_password" {
  type        = string
  description = "Expected to be retrieved from environment variable TF_VAR_mysql_password"
}

provider "google" {
  region = local.gcp_region
}

module "gcp-network" {
  source = "git::https://github.com/dusdjhyeon/module-gcp-network"

  project_id   = local.project_id
  env_name     = local.env_name
  vpc_name     = "dh-VPC"
  cluster_name = local.k8s_engine_name
  region       = local.gcp_region
  subnet_cidr  = "10.10.0.0/24"
}


module "gcp-gke" {
  source = "git::https://github.com/dusdjhyeon/module-gcp-kubernetes"

  project_id                 = local.project_id
  gke_namespace              = "microservices"
  env_name                   = local.env_name
  region                     = local.gcp_region
  cluster_name               = local.k8s_engine_name
  vpc_name                   = module.gcp-network.vpc_network
  subnet_id                  = module.gcp-network.subnet_id
  google_client_access_token = data.google_client_config.provider.access_token
  gke_machine_type           = "e2-medium"
}

# Create namespace
# Use kubernetes provider to work with the kubernetes cluster API
provider "kubernetes" {
  cluster_ca_certificate = base64decode(module.gcp-gke.gke_cert_data)
  host                   = module.gcp-gke.gke_cluster_endpoint
  token                  = data.google_client_config.provider.access_token
}

# Create a namespace for microservice pods
resource "kubernetes_namespace" "ms-namespace" {
  metadata {
    name = "microservices"
  }
}

//db와 reverse proxy의 경우 repository를 따로 만들지 않고 그냥 root 폴더의 하위 폴더에 구현함
module "gcp-databases" {
  source = "./module-gcp-db"

  gcp_region     = local.gcp_region
  mysql_password = var.mysql_password
  project_id     = local.project_id
  gke_name       = module.gcp-gke.gke_cluster_name
  route53_id     = "dh-zone"
}

module "traefik" {
  source = "./module-gcp-traefik"

  gcp_region                   = local.gcp_region
  kubernetes_cluster_name      = module.gcp-gke.gke_cluster_name
  kubernetes_cluster_cert_data = module.gcp-gke.gke_cert_data
  kubernetes_cluster_endpoint  = module.gcp-gke.gke_cluster_endpoint
  google_client_access_token   = data.google_client_config.provider.access_token

  gke_nodegroup_id = module.gcp-gke.gke_cluster_node_pool_id
}