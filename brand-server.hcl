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

variable "BRAND_DIR" {
  default = "${BRANDING_DIR_BASE}"
}

target "brand-icons" {
  context           = ".."
  args = {
    BRAND_DIR = "${BRAND_DIR}"
  }
  target            = "export"
  dockerfile-inline = ""
  dockerfile        = "${BRANDING_DIR_BASE}/build-icons.bake.Dockerfile"
}