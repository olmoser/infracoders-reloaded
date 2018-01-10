
resource "exoscale_domain_record" "prometheus_dns_sd_records" {
	count = "${var.nodes_count}"
	domain = "prometheus.exokube.eu"
	name = "_prometheus._tcp.prometheus-sd"
	record_type = "SRV"
	content = "1 8080 prom-node-${count.index}.prometheus.exokube.eu."
	ttl = 30
}
