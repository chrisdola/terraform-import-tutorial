resource "aws_iam_role" "lambda_role_app1" {
  name               = "Test_Lambda_Function_Role_app1"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda_app1" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role_app1"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_app1" {
  role       = aws_iam_role.lambda_role_app1.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_app1.arn
}

data "archive_file" "zip_the_python_code_app1" {
  type        = "zip"
  source_dir  = "./files/app1_1"
  output_path = "./files/app1_1/hello-python.zip"
}

resource "aws_lambda_function" "terraform_lambda_func_app1" {
  filename      = "./files/app1_1/hello-python.zip"
  function_name = "Test_Lambda_Function_App1"
  role          = aws_iam_role.lambda_role_app1.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1]
}
