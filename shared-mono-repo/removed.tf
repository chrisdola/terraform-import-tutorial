
# ###
# ## Remove App 2 resources
# ###

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
