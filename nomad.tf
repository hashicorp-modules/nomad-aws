terraform {
  required_version = ">= 0.9.3"
}

data "aws_ami" "nomad" {
  most_recent = true
  owners      = ["362381645759"] # hc-se-demos Hashicorp Demos New Account

  filter {
    name   = "tag:System"
    values = ["Nomad"]
  }

  filter {
    name   = "tag:Environment"
    values = ["${var.environment}"]
  }

  filter {
    name   = "tag:Product-Version"
    values = ["${var.nomad_version}"]
  }

  filter {
    name   = "tag:OS"
    values = ["${var.os}"]
  }

  filter {
    name   = "tag:OS-Version"
    values = ["${var.os_version}"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "nomad_server" {
  name               = "${var.cluster_name}-Nomad-Server"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "nomad_server" {
  name   = "SelfAssembly"
  role   = "${aws_iam_role.nomad_server.id}"
  policy = "${data.aws_iam_policy_document.nomad_server.json}"
}

resource "aws_iam_instance_profile" "nomad_server" {
  name = "${var.cluster_name}-Nomad-Server"
  role = "${aws_iam_role.nomad_server.name}"
}

data "template_file" "init" {
  template = "${file("${path.module}/init-cluster.tpl")}"

  vars = {
    cluster_size     = "${var.cluster_size}"
    consul_as_server = "${var.consul_as_server}"
    environment_name = "${var.environment_name}"
    nomad_as_client  = "${var.nomad_as_client}"
    nomad_as_server  = "${var.nomad_as_server}"
    nomad_use_consul = "${var.nomad_use_consul}"
  }
}

resource "aws_launch_configuration" "nomad_server" {
  associate_public_ip_address = false
  ebs_optimized               = false
  iam_instance_profile        = "${aws_iam_instance_profile.nomad_server.id}"
  image_id                    = "${data.aws_ami.nomad.id}"
  instance_type               = "${var.instance_type}"
  user_data                   = "${data.template_file.init.rendered}"
  key_name                    = "${var.ssh_key_name}"

  security_groups = [
    "${aws_security_group.nomad_server.id}",
    "${var.consul_server_sg_id}",
  ]

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

  tag {
    key                 = "Environment-Name"
    value               = "${var.environment_name}"
    propagate_at_launch = true
  }
}
