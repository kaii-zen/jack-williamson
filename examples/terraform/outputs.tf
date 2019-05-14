output "toast_out" {
  value = "${null_resource.toast.triggers.uuid}"
}
