## --- IAM role for Data Lifecycle Manager ---
# DLM is an AWS service that acts on your behalf, so it needs a role it
# can assume. The trust policy below says "the dlm.amazonaws.com service
# is allowed to become this role" - without it, DLM can't touch anything.
resource "aws_iam_role" "dlm" {
  name = "${var.project_name}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS maintains this managed policy with exactly the permissions DLM
# needs (create/delete snapshots, describe volumes, tag resources).
# Better than hand-rolling the permission list ourselves.
resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

## --- The snapshot schedule ---
resource "aws_dlm_lifecycle_policy" "saves" {
  description        = "Daily snapshots of the Project Zomboid save volume"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    # Matches the Backup=true tag on the save volume. Any volume with
    # this tag gets picked up; anything without it is ignored (so the
    # root volume is never snapshotted, which is what we want - it holds
    # nothing worth keeping).
    target_tags = {
      Backup = "true"
    }

    schedule {
      name = "Daily"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        # UTC. 06:00 UTC is 03:00 in Sao Paulo - late enough that a
        # session is unlikely to be running mid-snapshot.
        times = ["06:00"]
      }

      retain_rule {
        count = var.retain_count
      }

      # Carry the volume's tags onto the snapshot, so snapshots are
      # identifiable in the console rather than anonymous.
      copy_tags = true

      tags_to_add = {
        SnapshotCreator = "DLM"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-backup-policy"
  }
}
