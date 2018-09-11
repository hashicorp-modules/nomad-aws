terraform {
  required_version = ">= 0.11.6"
}

module "consul_auto_join_instance_role" {
  source = "github.com/hashicorp-modules/consul-auto-join-instance-role-aws"

  create = "${var.create ? 1 : 0}"
  name   = "${var.name}"
}

data "aws_ami" "nomad" {
  count       = "${var.create && var.image_id == "" ? 1 : 0}"
  most_recent = true
  name_regex  = "nomad-image_${lower(var.release_version)}_nomad_${lower(var.nomad_version)}_consul_${lower(var.consul_version)}_${lower(var.os)}_${var.os_version}.*"

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "nomad_init" {
  count    = "${var.create ? 1 : 0}"
  template = "${file("${path.module}/templates/init-systemd.sh.tpl")}"

  vars = {
    name      = "${var.name}"
    user_data = "${var.user_data != "" ? var.user_data : "echo 'No custom user_data'"}"
  }
}

module "nomad_server_sg" {
  # source = "github.com/hashicorp-modules/nomad-server-ports-aws"
  source = "../nomad-server-ports-aws"

  create      = "${var.create ? 1 : 0}"
  name        = "${var.name}-nomad-server"
  vpc_id      = "${var.vpc_id}"
  cidr_blocks = ["${var.vpc_cidr}"]
  tags        = "${var.tags}"
}

module "consul_client_sg" {
  # source = "github.com/hashicorp-modules/consul-client-ports-aws"
  source = "../consul-client-ports-aws"

  create      = "${var.create ? 1 : 0}"
  name        = "${var.name}-nomad-consul-client"
  vpc_id      = "${var.vpc_id}"
  cidr_blocks = ["${var.vpc_cidr}"]
  tags        = "${var.tags}"
}

resource "aws_security_group_rule" "ssh" {
  count = "${var.create ? 1 : 0}"

  security_group_id = "${module.nomad_server_sg.nomad_server_sg_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["${split(",", length(compact(var.lb_cidr_blocks)) > 0 ? join(",", compact(var.lb_cidr_blocks)) : var.vpc_cidr)}"]
  description       = "SSH access to Nomad node"
}

resource "aws_security_group_rule" "wetty_tcp" {
  count = "${var.create ? 1 : 0}"

  security_group_id = "${module.nomad_server_sg.nomad_server_sg_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 3030
  to_port           = 3030
  cidr_blocks       = ["${split(",", length(compact(var.lb_cidr_blocks)) > 0 ? join(",", compact(var.lb_cidr_blocks)) : var.vpc_cidr)}"]
  description       = "Wetty inbound TCP traffic to Nomad node"
}

resource "aws_launch_configuration" "nomad" {
  count = "${var.create ? 1 : 0}"

  name_prefix                 = "${format("%s-nomad-", var.name)}"
  associate_public_ip_address = "${!var.lb_internal}"
  ebs_optimized               = false
  instance_type               = "${var.instance_type}"
  image_id                    = "${var.image_id != "" ? var.image_id : element(concat(data.aws_ami.nomad.*.id, list("")), 0)}" # TODO: Workaround for issue #11210
  iam_instance_profile        = "${var.instance_profile != "" ? var.instance_profile : module.consul_auto_join_instance_role.instance_profile_id}"
  user_data                   = "${data.template_file.nomad_init.rendered}"
  key_name                    = "${var.ssh_key_name}"

  security_groups = [
    "${module.nomad_server_sg.nomad_server_sg_id}",
    "${module.consul_client_sg.consul_client_sg_id}",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

module "nomad_lb_aws" {
  # source = "github.com/hashicorp-modules/nomad-lb-aws"
  source = "../nomad-lb-aws"

  create             = "${var.create}"
  name               = "${var.name}"
  vpc_id             = "${var.vpc_id}"
  cidr_blocks        = ["${split(",", length(compact(var.lb_cidr_blocks)) > 0 ? join(",", compact(var.lb_cidr_blocks)) : var.vpc_cidr)}"]
  subnet_ids         = ["${var.subnet_ids}"]
  lb_internal        = "${var.lb_internal}"
  lb_use_cert        = "${var.lb_use_cert}"
  lb_cert            = "${var.lb_cert}"
  lb_private_key     = "${var.lb_private_key}"
  lb_cert_chain      = "${var.lb_cert_chain}"
  lb_ssl_policy      = "${var.lb_ssl_policy}"
  lb_bucket          = "${var.lb_bucket}"
  lb_bucket_override = "${var.lb_bucket_override}"
  lb_bucket_prefix   = "${var.lb_bucket_prefix}"
  lb_logs_enabled    = "${var.lb_logs_enabled}"
  tags               = "${var.tags}"
}

resource "aws_autoscaling_group" "nomad" {
  count = "${var.create ? 1 : 0}"

  name_prefix          = "${aws_launch_configuration.nomad.name}"
  launch_configuration = "${aws_launch_configuration.nomad.id}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  max_size             = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  min_size             = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  desired_capacity     = "${var.count != -1 ? var.count : length(var.subnet_ids)}"
  default_cooldown     = 30
  force_delete         = true

  target_group_arns = ["${compact(concat(
    list(
      module.nomad_lb_aws.nomad_tg_http_4646_arn,
      module.nomad_lb_aws.nomad_tg_https_4646_arn,
    ),
    var.target_groups
  ))}"]

  tags = ["${concat(
    list(
      map("key", "Name", "value", format("%s-nomad-node", var.name), "propagate_at_launch", true),
      map("key", "Consul-Auto-Join", "value", var.name, "propagate_at_launch", true)
    ),
    var.tags_list
  )}"]

  lifecycle {
    create_before_destroy = true
  }
}
