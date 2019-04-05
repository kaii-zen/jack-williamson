{
  resource.null_resource.toast = {
    triggers.uuid = "\${uuid()}";

    provisioner = [
      {
        local-exec.command = "echo hello \${self.triggers.uuid}";
      }
    ];
  };
}
