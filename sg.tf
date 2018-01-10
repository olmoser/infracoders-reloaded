
resource "cloudstack_security_group" "sg-prometheus" {
  name = "sg-prometheus"
  description = "the prometheus host/jump box for the prometheus infra"
}

resource "cloudstack_security_group_rule" "sg-prometheus-rules" {
  security_group_id = "${cloudstack_security_group.sg-prometheus.id}"

  rule {
    cidr_list = ["0.0.0.0/0"]
    protocol  = "tcp"
    ports     = ["22", "9090", "9093", "9100", "3000"]
  }

  rule {
  	user_security_group_list = ["sg-prometheus"]
	protocol = "tcp"
	ports = ["1-65535"]
  }

}
