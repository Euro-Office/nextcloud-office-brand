variable "BRANDING_DIR_BASE" {
  default = "build/brands/nextcloud-office-brand"
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

variable "SVG_DIR" {
  default = "${BRANDING_DIR_BASE}/svg"
}

target "brand-icons" {
  context           = "../../.."
  args = {
    SVG_DIR = "${SVG_DIR}"
  }
  target            = "export"
  dockerfile-inline = ""
  dockerfile        = "${BRANDING_DIR_BASE}/build-icons.bake.Dockerfile"
}