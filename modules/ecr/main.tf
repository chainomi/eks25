resource "aws_ecr_repository" "ecr" {
  for_each             = toset(var.repo_list)
  name                 = each.key
  image_tag_mutability = var.image_tag_mutability

}