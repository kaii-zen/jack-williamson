resource "null_resource" "byeeee" {
  provisioner "local-exec" {
    command = "echo OHAI"
  }
}
