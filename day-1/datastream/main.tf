**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.31.0"
    }
  }
}

provider "google" {

}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"  
}

resource "google_compute_firewall" "vpc_network_firewall" {
  name    = "firewall"
  
  network = google_compute_network.vpc_network.name
  
  source_service_accounts = ["${google_service_account.data_pipeline_access.email}"]

  allow {
    protocol = "tcp"
    ports    = ["12345", "12346"]
  }
}

resource "google_service_account" "data_pipeline_access" {
  project = var.project_id
  account_id = "datastreampipeline"
  display_name = "Datastream pipeline access"
}
resource "google_project_iam_member" "dataflow_service_agent" {
  project = var.project_id
  role = "roles/dataflow.serviceAgent"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}
resource "google_project_iam_member" "dataflow_admin_role" {
  project = var.project_id
  role = "roles/dataflow.admin"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}

resource "google_project_iam_member" "dataflow_worker_role" {
  project = var.project_id
  role = "roles/dataflow.worker"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}
resource "google_project_iam_member" "datastream_admin_role" {
  project = var.project_id
  role = "roles/datastream.admin"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}
resource "google_project_iam_binding" "binding" {
  project = var.project_id
  role = "roles/iam.serviceAccountUser"
  members = ["serviceAccount:${google_service_account.data_pipeline_access.email}"]
}

resource "google_project_iam_member" "storage_admin_role" {
  project = var.project_id
  role = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}

resource "google_project_iam_member" "dataflow_bigquery_role" {
  project = var.project_id
  role = "roles/bigquery.admin"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}

resource "google_project_iam_member" "dataflow_pub_sub_subscriber" {
  project = var.project_id
  role = "roles/pubsub.admin"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}

resource "google_project_iam_member" "dataflow_pub_sub_viewer" {
  project = var.project_id
  role = "roles/pubsub.viewer"
  member = "serviceAccount:${google_service_account.data_pipeline_access.email}"
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"

  disable_on_destroy = false
}
resource "google_project_service" "dataflow" {
  service = "dataflow.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "random_id" "name" {
  byte_length = 2
}

resource "google_sql_database_instance" "master" {    
    name = "mysql-instance"
    database_version = "MYSQL_8_0"
    region = "us-central1"
    deletion_protection =  "false"
    settings {
        tier = "db-n1-standard-2"
        backup_configuration { 
            binary_log_enabled = true
            enabled = true
            }
        ip_configuration {
            ipv4_enabled = true
            authorized_networks { 
                name = "net1"
                value = "34.72.28.29"
            }
            authorized_networks {
                name = "net2"
                value = "34.67.234.134"
            }
            authorized_networks {
                name = "net3"
                value = "34.67.6.157"
            }
            authorized_networks {
                name = "net4"
                value = "34.72.239.218"
            }
            authorized_networks {
                name = "net5"
                value = "34.71.242.81"
            }
        }
    }
}

resource "google_sql_user" "users" {
name = "root"
instance = "${google_sql_database_instance.master.name}"
host = "%"
password = "password123"
}

resource "google_pubsub_topic" "ps_topic" {
  name = "datastream"

  labels = {
    created = "terraform"
  }

  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_subscription" "ps_subscription" {
  name  = "datastream-subscription"
  topic = google_pubsub_topic.ps_topic.name

  labels = {
    created = "terraform"
  }
  
  retain_acked_messages      = false

  ack_deadline_seconds = 20


  retry_policy {
    minimum_backoff = "10s"
  }

  enable_message_ordering    = false
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
  }

data "google_storage_project_service_account" "gcs_account" {
}
resource "google_pubsub_topic_iam_binding" "binding" {
  project = var.project_id
  topic   = google_pubsub_topic.ps_topic.name
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.gcs_bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.ps_topic.name
  
 depends_on = [google_pubsub_topic_iam_binding.binding]
}

resource "google_bigquery_dataset" "bq_dataset" {
  dataset_id                  = "dataset"
  friendly_name               = "dataset"
  description                 = "This is a test description"
  location                    = "US"
  
  delete_contents_on_destroy = true

  labels = {
    env = "default"
  }
}

resource "google_bigquery_table" "bq_table" {
  dataset_id = google_bigquery_dataset.bq_dataset.dataset_id
  table_id   = "sql-table"
  deletion_protection = false

  labels = {
    env = "default"
  }

}

resource "google_storage_bucket" "dataflow_gcs_bucket" {
    name = "${var.project_id}-staging-gcs-dataflow"
    location = "us-central1" 
    force_destroy = true
}
resource "google_storage_bucket" "gcs_bucket" {
    name = "${var.project_id}"
    location = "us-central1" 
    force_destroy = true
}
