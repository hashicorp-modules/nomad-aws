terraform {
  required_version = ">= 0.9.3"
}

module "images-aws" {
  source        = "git@github.com:hashicorp-modules/images-aws.git?ref=dan-refactor"
  nomad_version = "${var.nomad_version}"
  os            = "${var.os}"
  os_version    = "${var.os_version}"
}

resource "aws_iam_role" "nomad_server" {
  name               = "${var.cluster_name}-NomadServer"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "nomad_server" {
  name   = "SelfAssembly"
  role   = "${aws_iam_role.nomad_server.id}"
  policy = "${data.aws_iam_policy_document.nomad_server.json}"
}

resource "aws_iam_instance_profile" "nomad_server" {
  name = "${var.cluster_name}-NomadServer"
  role = "${aws_iam_role.nomad_server.name}"
}

data "template_file" "init" {
  template = "${file("${path.module}/init-cluster.tpl")}"

  vars = {
    consul_as_server = "${var.consul_as_server}"
    nomad_as_client  = "${var.nomad_as_client}"
    nomad_as_server  = "${var.nomad_as_server}"
    nomad_use_consul = "${var.nomad_use_consul}"
  }
}

resource "aws_launch_configuration" "nomad_server" {
  image_id      = "${module.images-aws.nomad_image}"
  instance_type = "${var.instance_type}"
  user_data     = "${data.template_file.init.rendered}"
  key_name      = "${var.ssh_key_name}"

  security_groups = [
    "${aws_security_group.nomad_server.id}",
    "${var.consul_server_sg_id}",
  ]

  associate_public_ip_address = false
  ebs_optimized               = false
  iam_instance_profile        = "${aws_iam_instance_profile.nomad_server.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nomad_server" {
  launch_configuration = "${aws_launch_configuration.nomad_server.id}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  name                 = "${var.cluster_name} Nomad Servers"
  max_size             = "${var.cluster_size}"
  min_size             = "${var.cluster_size}"
  desired_capacity     = "${var.cluster_size}"
  default_cooldown     = 30
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "${format("%s Nomad Server", var.cluster_name)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster-Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }
}
