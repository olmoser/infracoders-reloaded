# Prometheus Service Discovery Demo

Terraform definitions for creating a simple Prometheus demo setup.

## Gettings Started

### Prerequisites
You need an [Exoscale](https://www.exoscale.ch/) account to acquire the required API key and secret. You also need to install the [Exoscale Terraform Provider](https://github.com/exoscale/terraform-provider-exoscale).

Then, provide the values for the variables used in the terraform config via `terraform.tfvars`:

```
api_key = "xxx"
secret_key = "yyy"
private_key_file = "~/.ssh/infracoders"
public_key_file = "~/.ssh/infracoders.pub"
consul_version = "1.0.2"
grafana_version = "4.6.3"
prometheus_version = "2.0.0"
node_exporter_version = "0.15.2"
slack_webhook = "https://hooks.slack.com/services/my/slack/webhook"
domain="domain.my"
```

### Infrastructure Terraforming

First, have a look at the resource definitions to understand what they do. For instance, `compute.tf` contains all VM provisioning definitions, `dns.tf` holds the DNS resources etc.
You should also checkout the cloud-init configs `master-cloud-init.yml` and `nodes-cloud-init.yml` to understand what's happening during the bootstrapping process.

Run `terraform plan` to see what will happen:

```bash
~/infracoders-reloaded [master|✚ 1…1]
20:56 omoser@riox > terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

data.template_file.master: Refreshing state...
data.template_file.nodes[1]: Refreshing state...
data.template_file.nodes[0]: Refreshing state...

------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + cloudstack_security_group.sg-prometheus
      id:                                                  <computed>
      description:                                         "rules for the infracoders prometheus demo"
      name:                                                "sg-prometheus"
      project:                                             <computed>
...
  + exoscale_domain_record.prometheus_node_records[1]
      id:                                                  <computed>
      content:                                             "${element(exoscale_compute.nodes.*.ip_address, count.index)}"
      domain:                                              "prometheus.exokube.eu"
      name:                                                "prom-node-1"
      prio:                                                <computed>
      record_type:                                         "A"
      ttl:                                                 "30"


Plan: 12 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

and then `terraform apply` to actually make it happen:

```bash
~/infracoders-reloaded [master|✚ 1…1]
20:56 omoser@riox > terraform apply
data.template_file.nodes[0]: Refreshing state...
data.template_file.master: Refreshing state...
data.template_file.nodes[1]: Refreshing state...
cloudstack_security_group.sg-prometheus: Creating...
  description: "" => "rules for the infracoders prometheus demo"
  name:        "" => "sg-prometheus"
  project:     "" => "<computed>"
...
exoscale_domain_record.prometheus_dns_sd_records[0]: Creating...
  content:     "" => "1 8080 prom-node-0.prometheus.exokube.eu."
  domain:      "" => "prometheus.exokube.eu"
  name:        "" => "prometheus-sd"
  prio:        "" => "<computed>"
  record_type: "" => "SRV"
  ttl:         "" => "30"
exoscale_domain_record.prometheus_dns_sd_records[1]: Creating...
  content:     "" => "1 8080 prom-node-1.prometheus.exokube.eu."
  domain:      "" => "prometheus.exokube.eu"
  name:        "" => "prometheus-sd"
  prio:        "" => "<computed>"
  record_type: "" => "SRV"
  ttl:         "" => "30"
exoscale_domain_record.prometheus_dns_sd_records[0]: Creation complete after 0s (ID: 13199375)
exoscale_domain_record.prometheus_dns_sd_records[1]: Creation complete after 0s (ID: 13199376)

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

```
If you setup the Slack webhook, you should receive a notification when the nodes are ready.

### Demo Services
If everything goes as planned, you should end up with a single master and two worker node setup that runs the following services:

| Service | Master Node | Worker Node |
| --------| :--: | :--: |
| Prometheus | x | - |
| Node Exporter | - | x |
| Grafana | x | - | 
| Consul | x | - |
| Prom-Boot | - | x |

Prometheus, Grafana and Consul are setup as systemd units, so you can start/stop them via e.g. `systemctl start prometheus` and check the logs with `journalctl -u prometheus` (both require sudo).

There is also a demo microservice called `prom-boot`, it's a minimal [Spring Boot](https://projects.spring.io/spring-boot/) application that has [Spring Cloud Consul](https://cloud.spring.io/spring-cloud-consul/) enabled so that you can 
showcase the Consul service discovery in Prometheus. You can start the non-Consul version on the worker nodes via `/usr/local/bin/prom-boot-dns` and the consul enabled one using `/usr/local/bin/prom-boot-consul`. `prom-boot` runs inside a Docker container, so you can check the logs via `docker logs`.

### Trying different service discovery modes

On the master node, go to `/etc/prometheus` and check the config files there. There should be four of them:

* `prometheus.yml`: The default config, only static discovery for local Prometheus.
* `prometheus-static.yml`: Static service discovery for the two worker nodes. You might need to change the targets in this file.
* `prometheus-dns.yml`: DNS based service discovery for two `prom-boot` instances running on `prom-node-0` and `prom-node-1`.
* `prometheus-consul.yml`: Consul based service discovery for two `prom-boot` instances running on `prom-node-0` and `prom-node-1`.

To enabled a differnt config, just copy the new config to `/etc/prometheus/prometheus.yml`, e.g.

```
> cp /etc/prometheus/prometheus-dns.yml
```

to enabled DNS based SD.  Remember that you need to restart Prometheus for the changes to take effect (`systemctl restart prometheus`). Then, go to  `http://prom-master-0.your.domain:9090/targets` to validate the effect of the SD config change.

There are also two dashboards preconfigured in Grafana. Go to `http://prom-master-0.your.domain:3000` and login with `admin/admin`. Prometheus is running on `http://prom-master-0.your.domain:9090`,
and the `prom-boot` services on `8080` for DNS and `18080` for Consul based SD.


