variable "vpc_id" {
	type = "string"
}

variable "consul_sg_id" {
	type = "string"
}

variable "subnets" {
	type = "list"
}

variable "cluster_size" {
	type = "string"
}

variable "cluster_name" {
	type = "string"
}

variable "ami" {
	type = "string"
}

variable "instance_type" {
	type = "string"
}

output "asg_id" {
	value = "${aws_autoscaling_group.nomad_server.id}"
}
