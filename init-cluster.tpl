#!/bin/bash

local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
new_hostname="nomad-$${instance_id}"

# set the hostname (before starting consul and nomad)
hostnamectl set-hostname "$${new_hostname}"

if [[ "${consul_as_server}" != "true" ]]; then
  # remove consul-server.json from /etc/consul.d/
  # todo:
  #   Use environment variable for consul config directory so this rm isn't
  #   hardcoded (which would fail if the config dir changed). This requires
  #   the config directory value to be set as an environment variable early
  #   on in the build process, so needs proper testing once implemented.
  rm /etc/consul.d/consul-server.json
fi

if [[ "${nomad_as_client}" != "true" ]]; then
  # remove nomad-client.hcl from /etc/nomad.d/
  # todo: Fix hard-coding as above issue.
  rm /etc/nomad.d/nomad-client.hcl
fi

if [[ "${nomad_as_server}" != "true" ]]; then
  # remove nomad-client.hcl from /etc/nomad.d/
  # todo: Fix hard-coding as above issue.
  rm /etc/nomad.d/nomad-server.hcl
fi

if [[ "${nomad_use_consul}" != "true" ]]; then
  # remove nomad-client.hcl from /etc/nomad.d/
  # todo: Fix hard-coding as above issue.
  rm /etc/nomad.d/nomad-consul.hcl
fi

# consul agent exists on all instances in client or server configuration
systemctl enable consul
systemctl start consul

# enable and start nomad once it is configured correctly
systemctl enable nomad
systemctl start nomad
