# Hello world flask app

## Requirements
> 1. AWS CLI
> 3. Python
> 4. pip
> 5. Docker


## Instructions

## Running application locally

### Running with python
Use the following commands to run the application using python

> 1. Setup virtual environment - `python3 -m venv env`
> 2. Activate virtual environment in env folder - `source env/bin/activate`
> 3. Check python version and folder where dependencies will be run from - `which python`
> 4. Install dependencies - `pip install -r requirements.txt`
> 5. Run application - `python3 app_flask_api.py`
> 6. Confirm application is running `http://localhost:8000/`

### Running with Docker
Use the following commands to run the application using python

> 1. Build image - `docker build -t flask-api .`
> 2. Run container - `docker run -p 8000:8000`
> 3. Confirm app is running from terminal - `curl localhost:8000` or from browser `http://localhost:8000`
> 3. Using docker compose - `docker-compose up` or `docker-compose up -d` for deamon mode


## Running application in the cloud (AWS)

## Cloud deployment (AWS EKS)

### Docker image build
> 1. `docker build -t flask-api .`

### ECR - push image to ECR (from Terraform folder)
> 1. Create repo in AWS ECR named `flask-api`.
> 2. login to ECR - `aws ecr get-login-password --region $(terraform output -raw region) | docker login --username AWS --password-stdin $(terraform output -raw aws_account_id).dkr.ecr.$(terraform output -raw region).amazonaws.com`
> 3. Tag image for ECR - `docker tag flask-api:latest <aws_ecr_repository_url>:latest`
> 4. Push image to ECR - `docker push <aws_ecr_repository_url>:latest`

## Updating manifest files
> 1. Update hostname in `ci/k8s/ingress.yml` to the desired hostname.
> 2. Update the SSL certificate for domain in `ci/k8s/ingress.yml`.
> 3. Update the container image in the `ci/k8s/app-manifest.yml` file to the ECR image URL.
   

### Deploy app to EKS cluster 
> 1. Change kubeconfig context to eks cluster - `aws eks --region <aws_region> update-kubeconfig --name <cluster_name>`
> 2. create kubernetes resources - `kubectl apply -f ci/k8s/`
>
> helm upgrade flask-api flask-api-chart/ --values flask-api-chart/values.yaml --install
> 
helm template flask-api-chart/ --values flask-api-chart/values.yaml --debug


