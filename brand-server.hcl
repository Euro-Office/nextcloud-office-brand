variable "BRANDING_DIR_BASE" {
  default = "build/brands/nextcloud-office-brand"
}
variable "COMPANY_NAME" {
  default = "Nextcloud Office"
}
variable "PRODUCT_NAME" {
  default = "DocumentServer"
}


#######################################
#### Do not change below this line ####
#######################################

variable "BRANDING_DIR" {
  default = "../${BRANDING_DIR_BASE}/generated"
}

target "brand-icons" {
  context    = "../${BRANDING_DIR_BASE}"
  dockerfile = "build-icons.bake.Dockerfile"
  output     = ["type=local,dest=${BRANDING_DIR}"]
}