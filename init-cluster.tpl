#!/bin/bash

instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
new_hostname="nomad-$${instance_id}"

# stop consul and nomad so they can be configured correctly
systemctl stop nomad
systemctl stop consul

# clear the consul and nomad data directory ready for a fresh start
rm -rf /opt/consul/data/*
rm -rf /opt/nomad/data/*

# set the hostname (before starting consul and nomad)
hostnamectl set-hostname "$${new_hostname}"

# seeing failed nodes listed  in consul members with their solo config
# try a 2 min sleep to see if it helps with all instances wiping data
# in a similar time window
sleep 120

# add the consul group to the config with jq
jq ".retry_join_ec2 += {\"tag_key\": \"Environment-Name\", \"tag_value\": \"${environment_name}\"}" < /etc/consul.d/consul-default.json > /tmp/consul-default.json.tmp
sed -i -e "s/127.0.0.1/$${local_ipv4}/" /tmp/consul-default.json.tmp
mv /tmp/consul-default.json.tmp /etc/consul.d/consul-default.json
chown consul:consul /etc/consul.d/consul-default.json

# configure nomad to listen on private ip address for rpc and serf
echo "advertise {
  http = \"$${local_ipv4}\"
  rpc = \"$${local_ipv4}\"
  serf = \"$${local_ipv4}\"
}" | tee -a /etc/nomad.d/nomad-default.hcl

if [[ "${consul_as_server}" = "true" ]]; then
  # add the cluster instance count to the config with jq
  jq ".bootstrap_expect = ${cluster_size}" < /etc/consul.d/consul-server.json > /tmp/consul-server.json.tmp
  mv /tmp/consul-server.json.tmp /etc/consul.d/consul-server.json
  chown consul:consul /etc/consul.d/consul-server.json
else
  # remove the consul as server config
  rm /etc/consul.d/consul-server.json
fi

if [[ ! "${nomad_as_client}" = "true" ]]; then
  # remove the nomad client config
  rm /etc/nomad.d/nomad-client.hcl
fi

if [[ "${nomad_as_server}" = "true" ]]; then
  # add the cluster instance count to the nomad server config
  sed -e "s/bootstrap_expect = 1/bootstrap_expect = ${cluster_size}/g" /etc/nomad.d/nomad-server.hcl > /tmp/nomad-server.hcl.tmp
  mv /tmp/nomad-server.hcl.tmp /etc/nomad.d/nomad-server.hcl
else
  # remove the nomad server config
  rm /etc/nomad.d/nomad-server.hcl
fi

if [[ ! "${nomad_use_consul}" = "true" ]]; then
  # remove consul from nomad config
  rm /etc/nomad.d/nomad-consul.hcl
fi

# start consul and nomad once they are configured correctly
systemctl start consul
systemctl start nomad
systemctl start docker

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts
echo 'JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")'|  sudo tee --append /home/ubuntu/.bashrc

DOCKER_BRIDGE_IP_ADDRESS=(`ifconfig docker0 2>/dev/null|awk '/inet/ {print $2}'|sed 's/addr://'`)
echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf
