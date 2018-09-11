output "zREADME" {
  value = <<README
# ------------------------------------------------------------------------------
# ${var.name} Nomad
# ------------------------------------------------------------------------------

You can interact with Nomad using any of the CLI
(https://www.nomadproject.io/docs/commands/index.html) or API
(https://www.nomadproject.io/api/index.html) commands.

${format("Nomad UI: %s%s %s\n\n%s", var.lb_use_cert ? "https://" : "http://", module.nomad_lb_aws.nomad_lb_dns, !var.lb_internal ? "(Public)" : "(Internal)", !var.lb_internal ? "The Nomad nodes are in a public subnet with UI & SSH access open from the\ninternet. WARNING - DO NOT DO THIS IN PRODUCTION!" : "The Nomad node(s) are in a private subnet, UI access can only be achieved inside\nthe network.")}

Use the CLI to retrieve Nomad servers & clients, then deploy a Redis Docker
container and check it's status.

  $ nomad server members # Check Nomad's server members
  $ nomad node-status # Check Nomad's client nodes
  $ nomad init # Create a skeletion job file to deploy a Redis Docker container

  $ nomad plan example.nomad # Run a nomad plan on the example job
  $ nomad run example.nomad # Run the example job
  $ nomad status # Check that the job is running
  $ nomad status example # Check job details
  $ nomad stop example # Stop the example job
  $ nomad status # Check that the job is stopped

Use the HTTP API to deploy a Redis Docker container.

  $ nomad run -output example.nomad > example.json # Convert job file to JSON

${!var.lb_use_cert ?
"If you're making HTTP API requests to Nomad from the Bastion host,
the below env var has been set for you.

  $ export NOMAD_ADDR=http://nomad.service.consul:4646

  $ curl \\
      -X POST \\
      -d @example.json \\
      $${NOMAD_ADDR}/v1/job/example/plan | jq '.' # Run a nomad plan
  $ curl \\
      -X POST \\
      -d @example.json \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Run the example job
  $ curl \\
      -X GET \\
      $${NOMAD_ADDR}/v1/jobs | jq '.' # Check that the job is running
  $ curl \\
      -X GET \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Check job details
  $ curl \\
      -X DELETE \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Stop the example job
  $ curl \\
      -X GET \\
      $${NOMAD_ADDR}/v1/jobs | jq '.' # Check that the job is stopped"
:
"If you're making HTTPS API requests to Nomad from the Bastion host,
the below env vars have been set for you.

  $ export NOMAD_ADDR=https://nomad.service.consul:4646
  $ export NOMAD_CACERT=/opt/nomad/tls/nomad-ca.crt
  $ export NOMAD_CLIENT_CERT=/opt/nomad/tls/nomad.crt
  $ export NOMAD_CLIENT_KEY=/opt/nomad/tls/nomad.key

  $ curl \\
      -X POST \\
      -d @example.json \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/job/example/plan | jq '.' # Run a nomad plan on the example job
  $ curl \\
      -X POST \\
      -d @example.json \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Run the example job
  $ curl \\
      -X GET \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/jobs | jq '.' # Check that the job is running
  $ curl \\
      -X GET \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Check job details
  $ curl \\
      -X DELETE \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/job/example | jq '.' # Stop the example job
  $ curl \\
      -X GET \\
      -k --cacert $${NOMAD_CACERT} --cert $${NOMAD_CLIENT_CERT} --key $${NOMAD_CLIENT_KEY} \\
      $${NOMAD_ADDR}/v1/jobs | jq '.' # Check that the job is stopped"
}
README
}

output "consul_sg_id" {
  value = "${module.consul_client_sg.consul_client_sg_id}"
}

output "nomad_sg_id" {
  value = "${module.nomad_server_sg.nomad_server_sg_id}"
}

output "nomad_app_lb_sg_id" {
  value = "${module.nomad_lb_aws.nomad_app_lb_sg_id}"
}

output "nomad_lb_arn" {
  value = "${module.nomad_lb_aws.nomad_lb_arn}"
}

output "nomad_app_lb_dns" {
  value = "${module.nomad_lb_aws.nomad_app_lb_dns}"
}

output "nomad_network_lb_dns" {
  value = "${module.nomad_lb_aws.nomad_network_lb_dns}"
}

output "nomad_tg_tcp_22_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_tcp_22_arn}"
}

output "nomad_tg_tcp_4646_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_tcp_4646_arn}"
}

output "nomad_tg_http_4646_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_http_4646_arn}"
}

output "nomad_tg_https_4646_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_https_4646_arn}"
}

output "nomad_tg_http_3030_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_http_3030_arn}"
}

output "nomad_tg_https_3030_arn" {
  value = "${module.nomad_lb_aws.nomad_tg_https_3030_arn}"
}

output "nomad_asg_id" {
  value = "${element(concat(aws_autoscaling_group.nomad.*.id, list("")), 0)}" # TODO: Workaround for issue #11210
}

output "nomad_username" {
  value = "${lookup(var.users, var.os)}"
}
