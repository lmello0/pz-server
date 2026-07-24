## --- EBS volume for save data ---
# Lives independently of the instance. When Terraform replaces the EC2
# instance (which it does whenever user_data changes), this volume is
# untouched and simply reattaches - so worlds, characters, and player
# data survive rebuilds.
resource "aws_ebs_volume" "saves" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = "gp3"
  encrypted         = true

  # Guardrail: without this, a `terraform destroy` (or a change to a
  # forces-new-resource attribute like availability_zone) would silently
  # delete every save. Terraform will refuse and make you remove this
  # line deliberately.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name   = "${var.project_name}-saves"
    Backup = "true" # DLM finds volumes by tag, not by ID - this is the hook
  }
}

## --- Attach it to the instance ---
resource "aws_volume_attachment" "saves" {
  device_name = "/dev/sdf" # Ubuntu/nitro exposes this as /dev/nvme1n1
  volume_id   = aws_ebs_volume.saves.id
  instance_id = var.instance_id
}
