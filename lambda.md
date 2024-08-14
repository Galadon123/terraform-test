### Lab: Deploying a Simple AWS Lambda Function Using Terraform

## Introduction

In this lab, you'll learn how to deploy a simple AWS Lambda function using Terraform. AWS Lambda is a serverless compute service that allows you to run code without provisioning or managing servers. It automatically scales and only charges you for the compute time you consume. You'll deploy a basic Lambda function that returns a "Hello, World!" message when invoked.

## Objectives

1. Understand what an AWS Lambda function is.
2. Write a simple "Hello, World!" Lambda function using Node.js.
3. Package the Lambda function into a ZIP file.
4. Create and deploy the Lambda function using Terraform.
5. Set up an IAM role for the Lambda function with the necessary permissions.
6. Invoke the Lambda function to verify that it works correctly.

## What is an AWS Lambda Function?

AWS Lambda is a compute service that lets you run code without provisioning or managing servers. You simply write your code, upload it to Lambda, and the service handles the rest. Lambda functions are commonly used for event-driven applications, such as responding to HTTP requests, processing files in S3 buckets, or reacting to changes in a database.

## Step 1: Writing the Lambda Function

### 1.1: Create the Lambda Function

Start by creating a directory for your Lambda function:

```sh
mkdir lambda-function
cd lambda-function
```

Inside this directory, create a file named `index.js` with the following content:

```javascript
exports.handler = async (event) => {
    const response = {
        statusCode: 200,
        body: JSON.stringify('Hello, World!'),
    };
    return response;
};
```

This simple Node.js function returns a JSON response with the message "Hello, World!".

### 1.2: Package the Lambda Function

To deploy the Lambda function to AWS, you need to package it into a ZIP file:

```sh
zip function.zip index.js
```

This command will create a `function.zip` file containing your Lambda function code.

## Step 2: Setting Up Terraform

### 2.1: Create the Terraform Project Directory

Create a new directory for your Terraform project:

```sh
mkdir terraform-lambda-lab
cd terraform-lambda-lab
```

### 2.2: Create the Terraform Configuration

Create a `main.tf` file with the following content:

```hcl
provider "aws" {
  region = "us-west-2"
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }],
  })

  tags = {
    Name = "lambda-role"
  }
}

# Attach the AWSLambdaBasicExecutionRole policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create the Lambda function
resource "aws_lambda_function" "hello_world" {
  function_name = "hello-world-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  filename      = "${path.module}/function.zip"
  source_code_hash = filebase64sha256("${path.module}/function.zip")

  tags = {
    Name = "hello-world-function"
  }
}

# Create an AWS Lambda function permission to allow invocation
resource "aws_lambda_permission" "allow_invoke" {
  statement_id  = "AllowExecutionFromAny"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "lambda.amazonaws.com"
}
```

### Explanation

- **AWS Lambda Function**: Deploys the Lambda function with the Node.js runtime.
- **IAM Role**: An IAM role that the Lambda function will assume, with basic execution permissions to write logs to CloudWatch.
- **Source Code**: Specifies the ZIP file containing the Lambda function code.

## Step 3: Applying the Terraform Configuration

### 3.1: Initialize Terraform

Initialize Terraform to download the necessary providers and set up your environment:

```sh
terraform init
```

### 3.2: Apply the Configuration

Apply the Terraform configuration to create the Lambda function and related resources:

```sh
terraform apply
```

Type `yes` when prompted to confirm the creation of resources.

## Step 4: Invoking the Lambda Function

### 4.1: Use the AWS CLI to Invoke the Function

After deploying the Lambda function, you can invoke it using the AWS CLI:

```sh
aws lambda invoke \
    --function-name hello-world-function \
    --payload '{}' \
    response.json
```

This command will invoke the Lambda function and save the response to a file named `response.json`.

### 4.2: Check the Response

Check the contents of `response.json` to see the output from the Lambda function:

```sh
cat response.json
```

You should see the "Hello, World!" message in the response.

## Conclusion

In this lab, you created a simple "Hello, World!" AWS Lambda function using Node.js, packaged it into a ZIP file, and deployed it using Terraform. You also set up the necessary IAM role and permissions for the Lambda function and invoked it using the AWS CLI. This lab demonstrates the basics of deploying Lambda functions with Terraform, which you can build upon for more complex serverless applications.