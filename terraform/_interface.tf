variable "vpc_id" {
	type = "string"
}

variable "consul_sg_id" {
	type = "string"
}

variable "tls_kms_arn" {
	type = "string"
}

variable "tls_key_bucket_arn" {
	type = "string"
}

variable "subnets" {
	type = "list"
}

variable "backup_bucket_name" {
	type = "string"
}

variable "backup_bucket_arn" {
	type = "string"
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

variable "nomad_serf_key" {
	type = "string"
}

variable "nomad_circonus_token" {
	type = "string"
}

variable "tls_key_bucket_name" {
	type = "string"
}

output "asg_id" {
	value = "${aws_autoscaling_group.nomad_server.id}"
}
