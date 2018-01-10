resource "cloudstack_ssh_keypair" "prometheus-key" {
    name = "prometheus-key"
	public_key = "${file("${var.public_key_file}")}"
}
