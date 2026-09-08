variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  description = "snet-appgw subnet ID (from the network module) — dedicated, per Azure's requirement."
  type        = string
}

variable "backend_address" {
  description = <<-EOT
    Public IP of the AKS ingress controller's LoadBalancer Service. Not known
    until AKS + the ingress controller are actually running — get it with:
    kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Leave as the placeholder default until then; this module errors loudly
    (via a precondition) rather than silently deploying a broken backend.
  EOT
  type        = string
  default     = "0.0.0.0"
}

variable "tags" {
  type    = map(string)
  default = {}
}
