variable "BRANDING_DIR" {
  default = "build/brands/nextcloud-office-brand/generated"
}
variable "COMPANY_NAME" {
  default = "Nextcloud Office"
}
variable "PRODUCT_NAME" {
  default = "Desktop Editors"
}


#######################################
#### Do not change below this line ####
#######################################

target "brand-icons" {
  context    = "."
  dockerfile = "build-icons.bake.Dockerfile"
  output     = ["type=local,dest=generated"]
}