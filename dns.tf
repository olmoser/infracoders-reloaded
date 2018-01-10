resource "exoscale_domain" "prometheus" {
	name = "prometheus.exokube.eu"
}

resource "exoscale_domain_record" "prometheus_master_record" {
	domain = "prometheus.exokube.eu"
	name = "${exoscale_compute.master.name}"
	record_type = "A"
	content = "${exoscale_compute.master.ip_address}"
	ttl = 30
}

resource "exoscale_domain_record" "prometheus_node_records" {
	count = "${var.nodes_count}"
	domain = "prometheus.exokube.eu"
	name = "${element(exoscale_compute.nodes.*.name, count.index)}"
	record_type = "A"
	content = "${element(exoscale_compute.nodes.*.ip_address, count.index)}"
	ttl = 30
}

