## --- Tag-based resource group ---
# Gives you a single console view of everything in this deployment,
# replacing myApplications (which stops accepting new applications on
# 2026-07-30; AWS points at Resource Groups as the successor).
#
# Nothing is explicitly "added" to this group - it's a saved query.
# Any resource carrying Project=<project_name> shows up automatically,
# which is why the provider's default_tags block matters: it stamps that
# tag on every taggable resource without each module having to remember.
# Modules added later are picked up with no changes here.
resource "aws_resourcegroups_group" "pz" {
  name        = var.project_name
  description = "All resources belonging to the ${var.project_name} deployment"

  resource_query {
    # TAG_FILTERS_1_0 is the tag-query format. The only alternative,
    # CLOUDFORMATION_STACK_1_0, groups by CloudFormation stack - not
    # applicable to a Terraform-managed deployment.
    type = "TAG_FILTERS_1_0"

    query = jsonencode({
      # Widest net Resource Groups allows, so EC2, EBS, VPC, DLM and
      # anything added later are all covered without listing types.
      ResourceTypeFilters = ["AWS::AllSupported"]

      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        }
      ]
    })
  }

  tags = {
    Name = "${var.project_name}-group"
  }
}
