provider "google" {
  region = var.gcp_region
}

data "google_container_cluster" "microservice-cluster" {
  project = var.project_id
  name = var.gke_name
  location = var.gcp_region
}


resource "google_sql_database_instance" "mysql-db" {
  name             = "mysql-db"
  database_version = "MYSQL_8_0"
  region           = var.gcp_region
  project          = var.project_id
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = "true"
}

resource "google_sql_user" "users" {
  name     = "me"
  instance = google_sql_database_instance.mysql-db.name
  password = var.mysql_password
}

resource "google_redis_instance" "redis-db" {
  name           = "redis-db"
  tier           = "STANDARD_HA"
  memory_size_gb = 1
  redis_version  = "REDIS_6_X"
}

resource "google_dns_managed_zone" "prod" {
  name       = var.route53_id
  dns_name   = "private.example.com."
  visibility = "private"
}

resource "google_dns_record_set" "rds-instance" {
  name = "rds.${google_dns_managed_zone.prod.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = google_dns_managed_zone.prod.name
  rrdatas      = ["10.10.0.0/24"]
}