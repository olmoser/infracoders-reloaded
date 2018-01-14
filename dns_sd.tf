
resource "exoscale_domain_record" "prometheus_dns_sd_records" {
	count = "${var.nodes_count}"
	domain = "${var.domain}"
	name = "prometheus-sd"
	record_type = "SRV"
	content = "1 8080 prom-node-${count.index}.${var.domain}."
	ttl = 30
}
