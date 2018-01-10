variable "api_key" {}
variable "secret_key" {}
variable "private_key_file" {}
variable "public_key_file" {}


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

