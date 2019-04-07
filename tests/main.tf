resource "null_resource" "byeeee" {
  triggers {
    uuid = "${uuid()}"
  }

  provisioner "local-exec" {
    command = "echo ${self.triggers.uuid}"
  }
}
