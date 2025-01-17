config {
  call_module_type = "all"
}

rule "terraform_module_pinned_source" {
  enabled = true
  style = "flexible"
  default_branches = ["master"]
}