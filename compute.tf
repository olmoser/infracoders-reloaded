variable "nodes_count" {
    default = 2
}

data "template_file" "nodes" {
  template = "${file("nodes-cloud-init.yaml")}"
  count = "${var.nodes_count}"
  vars {
    index = "${count.index}"
    hostname = "prom-node-${count.index}"
	ssh_pubkey = "${file("${var.public_key_file}")}"
	node_exporter_version = "${var.node_exporter_version}"
	slack_webhook = "${var.slack_webhook}"
	domainname = "${var.domain}"
  }
}

data "template_file" "master" {
  template = "${file("master-cloud-init.yaml")}"
  vars {
    hostname = "prom-master-0"
	ssh_pubkey = "${file("${var.public_key_file}")}"
	prometheus_version = "${var.prometheus_version}"
	consul_version = "${var.consul_version}"
	grafana_version = "${var.grafana_version}"
	slack_webhook = "${var.slack_webhook}"
	domainname = "${var.domain}"
  }
}

resource "exoscale_compute" "master" {
    depends_on = ["cloudstack_security_group.sg-prometheus"]
    template = "Linux Ubuntu 16.04 LTS 64-bit"
    zone = "at-vie-1"
    size = "Medium"
    disk_size = 10
    key_pair = "prometheus-key"
    security_groups = ["sg-prometheus"]
    name = "prom-master-0"
    user_data = "${data.template_file.master.0.rendered}"
    connection {
        user = "ubuntu"
        type = "ssh"
        agent = false
        host = "${self.ip_address}"
        private_key = "${file(var.private_key_file)}"
    }

    provisioner "file" {
        content = "${file(var.private_key_file)}"
        destination = "/home/ubuntu/.ssh/id_rsa"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod 0600 /home/ubuntu/.ssh/id_rsa",
        ]
    }

    provisioner "local-exec" {
        command = "cat >> inventory <<EOL\n${self.ip_address}\nEOL"
    }
}

resource "exoscale_compute" "nodes" {
    depends_on = ["cloudstack_security_group.sg-prometheus"]
    count = "${var.nodes_count}"
    template = "Linux Ubuntu 16.04 LTS 64-bit"
    zone = "at-vie-1"
    size = "Small"
    disk_size = 10
    key_pair = "prometheus-key"
    security_groups = ["sg-prometheus"]
    name = "prom-node-${count.index}"
    user_data = "${element(data.template_file.nodes.*.rendered, count.index)}"
    connection {
        user = "ubuntu"
        type = "ssh"
        agent = false
        host = "${self.ip_address}"
        private_key = "${file(var.private_key_file)}"
    }

    provisioner "file" {
        content = "${file(var.private_key_file)}"
        destination = "/home/ubuntu/.ssh/id_rsa"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod 0600 /home/ubuntu/.ssh/id_rsa",
        ]
    }

    provisioner "local-exec" {
        command = "cat >> inventory <<EOL\n${self.ip_address}\nEOL"
    }
}

