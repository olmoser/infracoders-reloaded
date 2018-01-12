variable "api_key" {}
variable "secret_key" {}
variable "private_key_file" {}
variable "public_key_file" {}
variable "prometheus_version" {}
variable "consul_version" {}
variable "grafana_version" {}
variable "slack_webhook" {}
variable "node_exporter_version" {}


#
# provider settings
#
provider "exoscale" {
  token = "${var.api_key}"
  secret = "${var.secret_key}"
  timeout = 60
}

provider "template" {}

provider "cloudstack" {
  api_url    = "https://api.exoscale.ch/compute"
  api_key    = "${var.api_key}"
  secret_key = "${var.secret_key}"
  timeout = 60
}

