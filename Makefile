# region := $(shell cd environments/development/eks && terraform output -raw region)
# cluster_name := $(shell cd environments/development/eks && terraform output -raw cluster_name)


# plan:
# 	cd environments/development/eks && terraform init
# 	cd environments/development/eks && terraform validate
# 	cd environments/development/eks && terraform plan -out tf.plan && terraform show -no-color tf.plan > tfplan.txt

# apply:
# 	cd environments/development/eks && terraform init
# 	cd environments/development/eks && terraform apply --auto-approve

# destroy:
# 	cd environments/development/eks && terraform init
# 	cd environments/development/eks && terraform destroy --auto-approve

# lint:
# 	terraform fmt -recursive .
	
# eks-auth:
# 	cd environments/development/eks && aws eks --region $(region) update-kubeconfig --name $(cluster_name) --alias $(cluster_name)

.DEFAULT_GOAL := help

service ?= eks
EKS_DIR := environments/development/$(service)
TF := cd $(EKS_DIR) && terraform
REGION := $(shell cd $(EKS_DIR) && terraform output -raw region 2>/dev/null || echo unknown)
CLUSTER_NAME := $(shell cd $(EKS_DIR) && terraform output -raw cluster_name 2>/dev/null || echo unknown)
AWS_ACCOUNT_ID := $(shell cd $(EKS_DIR) && terraform output -raw aws_account_id 2>/dev/null || echo unknown)
ECR_REPO := 488144151286.dkr.ecr.us-west-1.amazonaws.com/flask-api

.PHONY: plan apply destroy lint eks-auth help

plan: ## Run terraform plan in specified service dir
	$(TF) init
	$(TF) validate
	$(TF) plan -out tf.plan
	$(TF) show -no-color tf.plan > tfplan.txt

apply: ## Run terraform apply
	$(TF) init
	$(TF) apply --auto-approve

destroy: ## Destroy terraform-managed resources
	$(TF) init
	$(TF) destroy --auto-approve

lint: ## Run terraform fmt
	terraform fmt -recursive .

eks-auth: ## Update kubeconfig for EKS
	cd $(EKS_DIR) && aws eks --region $(REGION) update-kubeconfig --name $(CLUSTER_NAME) --alias $(CLUSTER_NAME)

build-push-flask-image:
	cd flask-app-istio && docker build -t flask-api .
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
	docker tag flask-api:latest $(ECR_REPO):latest
	docker push $(ECR_REPO):latest
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'