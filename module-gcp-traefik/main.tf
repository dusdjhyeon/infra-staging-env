provider "helm" {
  kubernetes {
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_cert_data)
    host                   = var.kubernetes_cluster_endpoint
    token                  = var.google_client_access_token
  }
}

provider "aws" {
  region = var.gcp_region
}

resource "helm_release" "traefik-ingress" {
  name       = "ms-traefik-ingress"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"
  values = [<<EOF
    services:
      annotations:
        service.beta.kubernetes.io/ingress.class:"gce"
        externalTrafficPolicy: Local
    EOF
  ]
}