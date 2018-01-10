#!/usr/bin/env python2

#
# inspired by https://github.com/CiscoCloud/terraform.py
#

"""\
Builds an kubespray compatible ansible inventory for tfstate files in current directory
"""

import argparse
import datetime
import json
import os
from plumbum import local
import sys
import pprint

VERSION = '0.0.2'


def find_state_files(root=None):
    root = root or os.getcwd()
    for dir_path, _, file_names in os.walk(root):
        for name in file_names:
            suffix = os.path.splitext(name)[-1]
            if suffix== '.tfstate':
                yield os.path.join(dir_path, name)


def build_resource_iter(state):
    for mod in state['modules']:
        name = mod['path'][-1]
        for key, resource in mod['resources'].items():
            yield name, key, resource


def build_resource_iter_from_files(file_names):
    for file_name in file_names:
        with open(file_name, 'r') as json_file:
            state = json.load(json_file)
            return build_resource_iter(state)


def build_resource_iter_from_string(tf_json):
    try:
        state = json.loads(tf_json)
    except ValueError, e:
        print >> sys.stderr, "Unparsable state"
        print >> sys.stderr, "Exception: %s" % str(e)
        sys.exit(1)

    return build_resource_iter(state)


def _parse_prefix(source, prefix, sep='.'):
    for compkey, value in source.items():
        try:
            curprefix, rest = compkey.split(sep, 1)
        except ValueError:
            continue

        if curprefix != prefix or rest == '#':
            continue

        yield rest, value


def parse_dict(source, prefix, sep='.'):
    return dict(_parse_prefix(source, prefix, sep))


def parse_exoscale_resource(resource):
    resource_attributes = resource['primary']['attributes']
    name = resource_attributes.get('name')
    meta_data = parse_dict(resource_attributes, 'metadata')
    groups = ['etcd', 'master', 'node']
    attrs = {
        'metadata': meta_data,
        'ansible_ssh_port': meta_data.get('ssh_port', 22),
        'ansible_ssh_user': meta_data.get('ssh_user', 'root'),
        'ansible_ssh_host': resource_attributes['networks.0.ip4address'],
        'ip4address' : resource_attributes['networks.0.ip4address'],
        'provider': 'exoscale',
    }

    role = 'none'

    if 'kube-role' in meta_data:
        role = meta_data.get('kube-role')
    else:
        for group in groups:
            if group in name:
                role = group

    attrs.update({
        'kube_role': role
    })

    return name, attrs


def resource_parser_iter(resources):
    for module_name, key, resource in resources:
        resource_type, name = key.split('.', 1)
        if resource_type == 'exoscale_compute':
            yield parse_exoscale_resource(resource)


def generate_inventory(hosts, inventory_type):
    out = ['## kubespray inventory based on terraform state generated at ' + str(datetime.datetime.now().isoformat()) + ' ##']

    ansible_hosts, groups = generate_groups(hosts)

    out.append('\n'.join(ansible_hosts))

    if inventory_type == 'spray':
        out.append('\n[kube-master]')
        out.append('\n'.join(groups['master']))
        out.append('\n[kube-node]')
        out.append('\n'.join(groups['node']))
        out.append('\n[etcd]')
        out.append('\n'.join(groups['etcd']))
        out.append('\n[k8s-cluster:children]\nkube-node\nkube-master')

    return '\n'.join(out)

def generate_groups(hosts):
    ansible_hosts = []
    groups = {
        'master': [],
        'node': [],
        'etcd': [],
    }

    for name, attrs in sorted(hosts):
        ansible_hosts.append('{} ansible_ssh_host={}'.format(name.ljust(20), attrs['ansible_ssh_host']))

        for group in groups.keys():
            if group in attrs['kube_role']:
                groups[group].append(name)

    return ansible_hosts, groups


def generate_hostsfile(hosts, append_domain = ''):
    out = ['## begin hosts entries based on tfstate ##']
    out.extend(
        '{}\t{}{}'.format(attrs['ansible_ssh_host'].ljust(16), name, append_domain)
        for name, attrs in hosts
    )

    out.append('## begin hosts entries based on tfstate ##')
    return '\n'.join(out)

def generate_json(hosts):
    ansible_hosts, groups = generate_groups(hosts)

    return json.dumps(groups, indent = 4)

def generate_dns(hosts, domain):
    records = []
    sd_records = []
    # template for resource section
    dns_template = """
    resource "exoscale_dns" "prometheus" {
        name = "@@DOMAIN_NAME@@"
        @@RECORDS@@
        @@SD_RECORDS@@
    }
    """

    # template for record section
    record_template = """
        record = {
            name = "@@NODE@@"
            type = "A"
            content = "@@IP_ADDRESS@@"
        }"""

    for name, attrs in sorted(hosts):
        ip4address = attrs['ip4address']
        kube_role = attrs['kube_role']
        records.append(record_template.replace("@@NODE@@", name).replace("@@IP_ADDRESS@@", ip4address))
        sd_records.append(record_template.replace("@@NODE@@", "prometheus-sd").replace("@@IP_ADDRESS@@", ip4address))

    dns_template = dns_template.replace("@@DOMAIN_NAME@@", domain)
    return dns_template.replace("@@RECORDS@@", '\n'.join(records)).replace("@@SD_RECORDS@@", '\n'.join(sd_records))
        

def main():
    parser = argparse.ArgumentParser(
        __file__, __doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter, )

    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--generate',
                       action='store_true',
                       help='dump an ansible inventory that can be used for kubespray to stdout')

    modes.add_argument('--dns',
                       action='store_true',
                       help='generate a terraform config for DNS provisioning')

    modes.add_argument('--hosts-file',
                       action='store_true',
                       help='dump hosts in /etc/hosts format')

    modes.add_argument('--json',
                       action='store_true',
                       help='dump hosts JSON format')

    modes.add_argument('--version',
                       action='store_true',
                       help='print version and exit')

    default_root = os.environ.get('TERRAFORM_STATE_ROOT',
                                  os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))
    parser.add_argument('--root',
                        default=default_root,
                        help='custom root to search for `.tfstate`s in')

    parser.add_argument('--state-file',
                        default="",
                        help='use given terraform state file')

    parser.add_argument('--domain',
                       default='',
                       help='append given domain to hosts in hostfile')

    parser.add_argument('--type',
                       default='spray',
                       help='sets format for inventory. Choices: spray (default), plain')

    parser.add_argument('--pull-state',
                       action='store_true',
                       help='fetch terraform remote state via "terraform state pull"')


    args = parser.parse_args()

    if args.version:
        print('%s %s' % (__file__, VERSION))
        parser.exit()

    resources = []
    if args.root and args.state_file == "" and not args.pull_state:
        resources = resource_parser_iter(build_resource_iter_from_files(find_state_files(args.root)))
    
    if args.state_file and args.state_file != "":
        resources = resource_parser_iter(build_resource_iter_from_files([args.state_file]))

    if args.pull_state:
        cwd = os.getcwd()
        if args.root:
            tf_root = os.path.dirname(os.path.realpath(args.root))
            os.chdir(tf_root)

        terraform = local["terraform"]
        remote_state = terraform["state", "pull"]()

        resources = resource_parser_iter(build_resource_iter_from_string(remote_state))
        os.chdir(cwd)


    if args.generate:
        output = generate_inventory(resources, args.type)
        print(output)

    if args.dns:
        if not args.domain:
            print("For --dns, --domain is mandatory")
            parser.exit()

        output = generate_dns(resources, args.domain)
        print(output)

    if args.json:
        output = generate_json(resources)
        print(output)

    if args.hosts_file:
        output = generate_hostsfile(resources, args.domain)
        print(output)

    parser.exit()


if __name__ == '__main__':
    main()
