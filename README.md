# Terraform Resource/State Relocation Tutorial

Foobar is a Python library for dealing with word pluralization.


## Goals

- Demonstrate how resources can be moved between state files.
- Explore Terraform versions & limiations for state management.

## Requirements
- Terraform CLI
- Terraform Enterprise or Cloud Workspaces (optional)
- AWS Credentials

## Installation

Clone the repo locally.

```bash
git clone 
```
Create three separate workspaces in either TFC or TFE. 
- 1x shared workspace (initially will contain all resources)
- 2x app workspaces (i.e. app1_workspace & app2_workspace)

 
> It is possible to do this with local workspaces as well. Simply update the terraform.config.tf files and remove the cloud blocks. 

## Apply the combined resources

Move into the shared-mono-repo directory

```bash
cd shared-mono-repo
```

Initialize the workspace
```bash
terraform init
```

Apply the combined resources
```bash
terraform apply -auto-approve
```

This will create the following resources for 3 separate "applications":
- aws_iam_role
- aws_iam_policy
- aws_iam_role_policy_attachment
- aws_lambda_function

### Analyze the current state

View the current infrastructure in the shared workspace's state file. If using TFE/TFC, this is also viewable in the workspace's State page.
```bash
$ terraform state list

data.archive_file.zip_the_python_code_app1
data.archive_file.zip_the_python_code_app2
data.archive_file.zip_the_python_code_app3
aws_iam_policy.iam_policy_for_lambda_app1
aws_iam_policy.iam_policy_for_lambda_app2
aws_iam_policy.iam_policy_for_lambda_app3
aws_iam_role.lambda_role_app1
aws_iam_role.lambda_role_app2
aws_iam_role.lambda_role_app3
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app3
aws_lambda_function.terraform_lambda_func_app1
aws_lambda_function.terraform_lambda_func_app2
aws_lambda_function.terraform_lambda_func_app3
```

When migrating resources to a different state file (or moving them within an existing state file) all the datasources in state can be ignored. Those will only need the config blocks copied to the new config files. 

# ```terraform import```

# Move App 1 to Dedicated Workspace

### Get the Resource Info from the Currrent State

The next step will require analyzing the current state file for all App1 resources that will need to be moved. In order to move resources both the *address* and *ID* of the resource are required. To get this information, the command below can be run from the shared workspace. This will get the current state in json format (using the ```terraform show -json``` command) and then massage the data to get all resources that containe the QUERY_STRING variable.

Quick side note.. Touching state is something that is very intrusive and can easily result in unintented resources, managed resources in multiple state files, etc. It is ***strongly*** suggested that any changes be reviewed multiple times by multiple people before actually performing any modifications. It is fine to use commands (like the one below) to get general information about resources in state, but it is advisable to only use it as a guide and to validate each resource's address/ID manually to ensure that everything is correct.

```bash
$ QUERY_STRING="app1"
$ CURRENT_STATE=$(terraform show -json); for r in $(terraform state list | grep $QUERY_STRING); do id=$(echo "${CURRENT_STATE}" | jq ".values.root_module.resources[] | select (.address==\"${r}\") | .values.id"); echo "${r}:${id}";done

data.archive_file.zip_the_python_code_app1:"cfc99df41de9aa81204927020820cfec0e2c8812"
aws_iam_policy.iam_policy_for_lambda_app1:"arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1"
aws_iam_role.lambda_role_app1:"Test_Lambda_Function_Role_app1"
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1:"Test_Lambda_Function_Role_app1-20250124030144877000000001"
aws_lambda_function.terraform_lambda_func_app1:"Test_Lambda_Function_App1"
```
Three is one "gotcha' here. The ```aws_iam_role_policy_attachment``` resource's actual ID is not the ID field in the state file.. It is actually ```role/ARN```. Terraform itself has no control over the import functionality since that is driven by the provider (in this case AWS). Trying to import the ```aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1``` resource into state will result in an error that the ID can't be found. 

To get the correct ID that will be needed, run the following command:
```bash
$terraform state show aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1

# aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1:
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_app1" {
    id         = "Test_Lambda_Function_Role_app1-20250124030144877000000001"
    policy_arn = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1"
    role       = "Test_Lambda_Function_Role_app1"
}
```
Now combine the information from both commands to get a full list of App1 resources that exist in the current workspace. Take note of the ID for the policy_attachment resource.

```bash
aws_iam_policy.iam_policy_for_lambda_app1:"arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1"
aws_iam_role.lambda_role_app1:"Test_Lambda_Function_Role_app1"
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1:"Test_Lambda_Function_Role_app1/arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1"
aws_lambda_function.terraform_lambda_func_app1:"Test_Lambda_Function_App1"
```

### Import the resources into the App1 workspace

Migrating to this workspace will provide an example of using the ```terraform import``` CLI command to import resources. One limitation of the Import command is that it will only process a single resource at a time. This is designed for instances where only 1 or 2 resources are being moved. 


Change to the App1 workspace folder
```bash
cd ../app1_repo
```

Update the terraform.config.tf file with the correct workspace/org values

```bash
terraform {
  cloud {

    organization = "<org>"

    workspaces {
      name = "<workspace_name>"
    }
  }
}
```
Initialize the new workspace
```bash
terraform init
```


Update the AWS region in the terraform.tfvars
```bash
region = "<region>"
```

For each resource individually, uncomment the resource in the app1.tf file and then run the import command for that resource.

Example
```bash
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
```

Run the import command using the resource address & ID's that were identified earlier. 
```bash
$ terraform import aws_iam_role.lambda_role_app1 Test_Lambda_Function_Role_app1 

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.

```

Repeat the same action for all other resources that are being moved. Uncomment each resource in app1.tf, save the file, run the import. 

```bash
$ terraform import aws_iam_policy.iam_policy_for_lambda_app1 arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.

$ terraform import aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1 Test_Lambda_Function_Role_app1/arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.

Releasing state lock. This may take a few moments...

$ terraform import aws_lambda_function.terraform_lambda_func_app1 Test_Lambda_Function_App1

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.

```

Run a ```terraform plan``` to ensure that all the resources are shown and that no replaces/deletes/creates are going to be made during apply.

```bash
terraform plan
Running plan in HCP Terraform. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/chrisl/app1-repo/runs/run-6doh72bMkFRzNYDU

Waiting for the plan to start...

Terraform v1.10.5
on linux_amd64
Initializing plugins and modules...
data.archive_file.zip_the_python_code_app1: Refreshing...
data.archive_file.zip_the_python_code_app1: Refresh complete after 0s [id=cfc99df41de9aa81204927020820cfec0e2c8812]
aws_iam_policy.iam_policy_for_lambda_app1: Refreshing state... [id=arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1]
aws_iam_role.lambda_role_app1: Refreshing state... [id=Test_Lambda_Function_Role_app1]
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1: Refreshing state... [id=Test_Lambda_Function_Role_app1-arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app1]
aws_lambda_function.terraform_lambda_func_app1: Refreshing state... [id=Test_Lambda_Function_App1]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_lambda_function.terraform_lambda_func_app1 will be updated in-place
  ~ resource "aws_lambda_function" "terraform_lambda_func_app1" {
      + filename                       = "./files/app1_1/hello-python.zip"
        id                             = "Test_Lambda_Function_App1"
      ~ last_modified                  = "2025-01-24T03:01:53.329+0000" -> (known after apply)
      + publish                        = false
        tags                           = {}
        # (26 unchanged attributes hidden)

        # (3 unchanged blocks hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

In this case since the files are being uploaded by the resource, it's going to do an in-place update for the aws_lambda_function resource. But it's important to note that all the other resources are unchanged and nothing is actually being created.. 


### Remove the App1 resources from the shared workspace's state

Now that we are sure that the import was successfully and the resources are being managed by the new workspace, the App1 resources can be removed from the old shared workspace.

Change back to the shared-mon-repo directory.
```bash
cd ../shared-mono-repo
```

Rename the ```app1.tf``` file to ```app1.tf.bkp``` or comment out the entire contents of the file. 

For each resource, run the ```terraform state rm``` CLI command.

```bash
terraform state rm aws_iam_role.lambda_role_app1

Removed aws_iam_role.lambda_role_app1
Successfully removed 1 resource instance(s).
```

Now do the same for all other resources
```bash
$ terraform state rm aws_iam_policy.iam_policy_for_lambda_app1 
Removed aws_iam_policy.iam_policy_for_lambda_app1
Successfully removed 1 resource instance(s).

$ terraform state rm aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1
Removed aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app1
Successfully removed 1 resource instance(s).

$ terraform state rm aws_lambda_function.terraform_lambda_func_app1              
Removed aws_lambda_function.terraform_lambda_func_app1
Successfully removed 1 resource instance(s).
```

# ```import``` Block
Requires TF CLI >= 1.5.x

### Move App 2 to Dedicated Workspace

Move to App2 directory
```bash
cd ../app2_repo
```

Initialize the new workspace
```bash
terraform init
```

Update the terraform.config.tf file with the correct workspace/org values

```bash
terraform {
  cloud {

    organization = "<org>"

    workspaces {
      name = "<workspace_name>"
    }
  }
}
```

Update the AWS region in the terraform.tfvars
```bash
region = "<region>"
```

Update the resource info in the imports.tf to match what was retrieved earlier. 
```bash
import {
  to = aws_iam_policy.iam_policy_for_lambda_app2
  id = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
}

import {
  to = aws_iam_role.lambda_role_app2
  id = "Test_Lambda_Function_Role_app2"
}

import {
  to = aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2
  id = "Test_Lambda_Function_Role_app2/arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
}

import {
  to = aws_lambda_function.terraform_lambda_func_app2
  id = "Test_Lambda_Function_App2"
}
```

Run a plan to view the resources that will be imported. With the import blocks this will show the imports before actually importing the resources.
```bash
$ terraform plan

Running plan in HCP Terraform. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/chrisl/app2-repo/runs/run-nTASPjsw7untZvP4

Waiting for the plan to start...

Terraform v1.5.7
on linux_amd64
Initializing plugins and modules...
data.archive_file.zip_the_python_code_app2: Refreshing...
data.archive_file.zip_the_python_code_app2: Refresh complete after 0s [id=14b3d1c8b9bb0eeff29c739e9f50b239fb64356c]
aws_iam_role.lambda_role_app2: Refreshing state... [id=Test_Lambda_Function_Role_app2]
aws_iam_policy.iam_policy_for_lambda_app2: Refreshing state... [id=arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2]
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2: Refreshing state... [id=Test_Lambda_Function_Role_app2-arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2]
aws_lambda_function.terraform_lambda_func_app2: Refreshing state... [id=Test_Lambda_Function_App2]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_iam_policy.iam_policy_for_lambda_app2 will be imported
    resource "aws_iam_policy" "iam_policy_for_lambda_app2" {
        arn              = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
        attachment_count = 1
        description      = "AWS IAM Policy for managing aws lambda role"
        id               = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
        name             = "aws_iam_policy_for_terraform_aws_lambda_role_app2"
        name_prefix      = null
        path             = "/"
        policy           = jsonencode(
            {
                Statement = [
                    {
                        Action   = [
                            "logs:CreateLogGroup",
                            "logs:CreateLogStream",
                            "logs:PutLogEvents",
                        ]
                        Effect   = "Allow"
                        Resource = "arn:aws:logs:*:*:*"
                    },
                ]
                Version   = "2012-10-17"
            }
        )
        policy_id        = "ANPASFUIRN7PHVPAC4LLJ"
        tags             = {}
        tags_all         = {}
    }

  # aws_iam_role.lambda_role_app2 will be imported
    resource "aws_iam_role" "lambda_role_app2" {
        arn                   = "arn:aws:iam::149536468958:role/Test_Lambda_Function_Role_app2"
        assume_role_policy    = jsonencode(
            {
                Statement = [
                    {
                        Action    = "sts:AssumeRole"
                        Effect    = "Allow"
                        Principal = {
                            Service = "lambda.amazonaws.com"
                        }
                        Sid       = ""
                    },
                ]
                Version   = "2012-10-17"
            }
        )
        create_date           = "2025-01-24T03:01:44Z"
        description           = null
        force_detach_policies = false
        id                    = "Test_Lambda_Function_Role_app2"
        managed_policy_arns   = [
            "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2",
        ]
        max_session_duration  = 3600
        name                  = "Test_Lambda_Function_Role_app2"
        name_prefix           = null
        path                  = "/"
        permissions_boundary  = null
        tags                  = {}
        tags_all              = {}
        unique_id             = "AROASFUIRN7PKY5KT5ZMQ"
    }

  # aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2 will be imported
    resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_app2" {
        id         = "Test_Lambda_Function_Role_app2-arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
        policy_arn = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
        role       = "Test_Lambda_Function_Role_app2"
    }

  # aws_lambda_function.terraform_lambda_func_app2 will be updated in-place
  # (imported from "Test_Lambda_Function_App2")
  ~ resource "aws_lambda_function" "terraform_lambda_func_app2" {
        architectures                  = [
            "x86_64",
        ]
        arn                            = "arn:aws:lambda:us-east-1:149536468958:function:Test_Lambda_Function_App2"
        code_sha256                    = "XW2VFBGQ2T3CgMn2AxGvJVpykr19fPcUi+kaaaHKhIk="
        code_signing_config_arn        = null
        description                    = null
      + filename                       = "./files/app2_1/hello-python.zip"
        function_name                  = "Test_Lambda_Function_App2"
        handler                        = "index.lambda_handler"
        id                             = "Test_Lambda_Function_App2"
        image_uri                      = null
        invoke_arn                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:149536468958:function:Test_Lambda_Function_App2/invocations"
        kms_key_arn                    = null
      ~ last_modified                  = "2025-01-24T03:01:59.075+0000" -> (known after apply)
        layers                         = []
        memory_size                    = 128
        package_type                   = "Zip"
      + publish                        = false
        qualified_arn                  = "arn:aws:lambda:us-east-1:149536468958:function:Test_Lambda_Function_App2:$LATEST"
        qualified_invoke_arn           = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:149536468958:function:Test_Lambda_Function_App2:$LATEST/invocations"
        reserved_concurrent_executions = -1
        role                           = "arn:aws:iam::149536468958:role/Test_Lambda_Function_Role_app2"
        runtime                        = "python3.8"
        signing_job_arn                = null
        signing_profile_version_arn    = null
        skip_destroy                   = false
        source_code_hash               = null
        source_code_size               = 379
        tags                           = {}
        tags_all                       = {}
        timeout                        = 3
        version                        = "$LATEST"

        ephemeral_storage {
            size = 512
        }

        logging_config {
            application_log_level = null
            log_format            = "Text"
            log_group             = "/aws/lambda/Test_Lambda_Function_App2"
            system_log_level      = null
        }

        tracing_config {
            mode = "PassThrough"
        }
    }

Plan: 4 to import, 0 to add, 1 to change, 0 to destroy.

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
```

Run apply to import the resources. 
```bash
$ terraform apply
...
...

Plan: 4 to import, 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions in workspace "app2-repo"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_lambda_function.terraform_lambda_func_app2: Modifying... [id=Test_Lambda_Function_App2]
aws_lambda_function.terraform_lambda_func_app2: Modifications complete after 5s [id=Test_Lambda_Function_App2]

Apply complete! Resources: 4 imported, 0 added, 1 changed, 0 destroyed.

```

Now that the resources are imported for App2, it's time to remove the resources from the shared repo's state.

This could be accomplished using the ```terraform state rm``` commands that were used before, but the easier option is to use the ```removed``` blocks added in 1.7.x

Change back to the shared-mon-repo directory
```bash
cd ../shared-mono-repo
```

Open the removed.tf file and uncomment all the lines for the App2 resources. Each resource that is being removed is added in this file. 

The ```lifecycle``` block controls whether or not the resources are destroy when the resources are removed. Since it is set to false, the resources will only be removed from state.

```bash
removed {
  from = aws_iam_policy.iam_policy_for_lambda_app2

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role.lambda_role_app2

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_lambda_function.terraform_lambda_func_app2

  lifecycle {
    destroy = false
  }
}
```

Additionally, comment out all the resources/datasources in the app2.tf file.

Run a plan
```bash
terraform plan
```


```bash
terraform plan      
Running plan in HCP Terraform. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/chrisl/shared-mono-repo/runs/run-kRMTM3woZgFkfUp1

Waiting for the plan to start...

Terraform v1.7.5
on linux_amd64
Initializing plugins and modules...
data.archive_file.zip_the_python_code_app3: Refreshing...
data.archive_file.zip_the_python_code_app3: Refresh complete after 0s [id=c4fc28b9d7f9b85a740ea1058cb2dd5055bc5b73]
aws_iam_role.lambda_role_app2: Refreshing state... [id=Test_Lambda_Function_Role_app2]
aws_iam_role.lambda_role_app3: Refreshing state... [id=Test_Lambda_Function_Role_app3]
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2: Refreshing state... [id=Test_Lambda_Function_Role_app2-20250124030144889900000002]
aws_iam_policy.iam_policy_for_lambda_app3: Refreshing state... [id=arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app3]
aws_iam_policy.iam_policy_for_lambda_app2: Refreshing state... [id=arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2]
aws_lambda_function.terraform_lambda_func_app2: Refreshing state... [id=Test_Lambda_Function_App2]
aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app3: Refreshing state... [id=Test_Lambda_Function_Role_app3-20250124030144921300000003]
aws_lambda_function.terraform_lambda_func_app3: Refreshing state... [id=Test_Lambda_Function_App3]
aws_lambda_function.terraform_lambda_func_app2: Drift detected (update)
aws_iam_policy.iam_policy_for_lambda_app2: Drift detected (update)
aws_iam_role.lambda_role_app3: Drift detected (update)
aws_iam_role.lambda_role_app2: Drift detected (update)
aws_lambda_function.terraform_lambda_func_app3: Drift detected (update)
aws_iam_policy.iam_policy_for_lambda_app3: Drift detected (update)
╷
│ Warning: Some objects will no longer be managed by Terraform
│ 
│ If you apply this plan, Terraform will discard its tracking information for
│ the following objects, but it will not delete them:
│  - aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2
│  - aws_iam_policy.iam_policy_for_lambda_app2
│  - aws_iam_role.lambda_role_app2
│  - aws_lambda_function.terraform_lambda_func_app2
│ 
│ After applying this plan, Terraform will no longer manage these objects.
│ You will need to import them into Terraform to manage them again.
╵

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:

Terraform will perform the following actions:

 # aws_iam_policy.iam_policy_for_lambda_app2 will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_iam_policy" "iam_policy_for_lambda_app2" {
        id               = "arn:aws:iam::149536468958:policy/aws_iam_policy_for_terraform_aws_lambda_role_app2"
        name             = "aws_iam_policy_for_terraform_aws_lambda_role_app2"
        tags             = {}
        # (8 unchanged attributes hidden)
    }

 # aws_iam_role.lambda_role_app2 will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_iam_role" "lambda_role_app2" {
        id                    = "Test_Lambda_Function_Role_app2"
        name                  = "Test_Lambda_Function_Role_app2"
        tags                  = {}
        # (12 unchanged attributes hidden)
    }

 # aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_app2 will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_app2" {
        id         = "Test_Lambda_Function_Role_app2-20250124030144889900000002"
        # (2 unchanged attributes hidden)
    }

 # aws_lambda_function.terraform_lambda_func_app2 will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_lambda_function" "terraform_lambda_func_app2" {
        id                             = "Test_Lambda_Function_App2"
        tags                           = {}
        # (29 unchanged attributes hidden)

        # (3 unchanged blocks hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

Run an apply to remove the resources. Notice that there is nothing added, changed, or destroyed
```bash
$ terraform apply
...
...
Do you want to perform these actions in workspace "shared-mono-repo"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes


Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

## Recapping

To recap what has been accomplished:
- Applied the resources for the shared workspace. 
- Moved the App1 resources to a dedicated workspace using the ```terraform import``` command.
- Removed the App1 resources from the shared workspace using the ```terraform state rm``` command.
- Moved the App2 resources to a dedicated workspace using the ```import``` blocks.
- Removed the App2 resources from the shared workspace using the ```removed``` blocks.

## License

[MIT](https://choosealicense.com/licenses/mit/)