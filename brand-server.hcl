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


target "brand-icons" {
  context           = "../${BRANDING_DIR_BASE}"
  dockerfile-inline = ""
  dockerfile        = "build-icons.bake.Dockerfile"
}