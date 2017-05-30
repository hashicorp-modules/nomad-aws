#!/bin/bash

instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
new_hostname="nomad-$${instance_id}"

# set the hostname (before starting consul and nomad)
hostnamectl set-hostname "$${new_hostname}"

# add the consul group to the config with jq
jq ".retry_join_ec2 += {\"tag_key\": \"Environment-Name\", \"tag_value\": \"${environment_name}\"}" < /etc/consul.d/consul-default.json.example > /etc/consul.d/consul-default.json
chown consul:consul /etc/consul.d/consul-default.json

# configure nomad to listen on private ip address for rpc and serf
cp /etc/nomad.d/nomad-default.hcl.example /etc/nomad.d/nomad-default.hcl
echo "advertise {
  http = \"127.0.0.1\"
  rpc = \"$${local_ipv4}\"
  serf = \"$${local_ipv4}\"
}" | tee -a /etc/nomad.d/nomad-default.hcl
chown nomad:nomad /etc/nomad.d/nomad-default.hcl

if [[ "${consul_as_server}" = "true" ]]; then
  # add the cluster instance count to the config with jq
  jq ".bootstrap_expect = ${cluster_size}" < /etc/consul.d/consul-server.json.example > /etc/consul.d/consul-server.json
  chown consul:consul /etc/consul.d/consul-server.json
fi

if [[ "${nomad_as_client}" = "true" ]]; then
  # add the nomad client config
  cp /etc/nomad.d/nomad-client.hcl.example /etc/nomad.d/nomad-client.hcl
  chown nomad:nomad /etc/nomad.d/nomad-client.hcl
fi

if [[ "${nomad_as_server}" = "true" ]]; then
  # add the cluster instance count to the nomad server config
  sed -e "s/bootstrap_expect = 1/bootstrap_expect = ${cluster_size}/g" /etc/nomad.d/nomad-server.hcl.example > /etc/nomad.d/nomad-server.hcl
  chown nomad:nomad /etc/nomad.d/nomad-server.hcl
fi

if [[ "${nomad_use_consul}" = "true" ]]; then
  # add consul stanza to nomad config
  cp /etc/nomad.d/nomad-consul.hcl.example /etc/nomad.d/nomad-consul.hcl
  chown nomad:nomad /etc/nomad.d/nomad-consul.hcl
fi

# consul agent exists on all instances in client or server configuration
systemctl enable consul
systemctl start consul

# enable and start nomad once it is configured correctly
systemctl enable nomad
systemctl start nomad
