# Use aws-cli to create a private repository in ECR
aws ecr create-repository --repository-name php-lambda-function \
--image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true


# *accountId* - if you don't have your accountId on hand, use this command
aws sts get-caller-identity

# aws ecr get-login-password --region {region} | docker login --username AWS --password-stdin {yourAccountID}.dkr.ecr.{region} .amazonaws.com    

# tag the local with ECR format
# docker tag {image-id} {aws_account_id}.dkr.ecr.region.amazonaws.com/{my-repository:tag}

# push the image using docker push
# docker push {aws_account_id}.dkr.ecr.region.amazonaws.com/{my-repository:tag}