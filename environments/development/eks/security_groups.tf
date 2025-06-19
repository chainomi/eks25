resource "aws_security_group" "cluster_access" {
  name        = "${local.cluster_name}-cluster-access-sg"
  description = "Allow traffic into ${local.cluster_name} cluster endpoint"
  vpc_id      = module.eks.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "cluster_access" {
  security_group_id = aws_security_group.cluster_access.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "cluster_access" {
  security_group_id = aws_security_group.cluster_access.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
