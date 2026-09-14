# syntax=docker/dockerfile:1
FROM alpine:3.20 AS render

RUN apk add --no-cache \
        rsvg-convert \
        icoutils \
        bash \
        libxml2-utils \
        fontconfig \
        font-roboto

SHELL ["/bin/bash", "-c"]

WORKDIR /work

# Build args you can override from bake
ARG BRAND_DIR=.

# Bring in the SVGs from the build context
COPY ${BRAND_DIR}/svg /work/svg/

COPY ${BRAND_DIR}/config /work/config/

RUN <<'EOF' 
set -euo pipefail


### Directories that need changed icons ###
DESKTOP_1=/out/desktop-apps/win-linux/res/icons
DESKTOP_2=/out/desktop-apps/package/common/linux/icons-eo
DESKTOP_3=/out/desktop-apps/common/loginpage/res/img

SERVER_1=/out/server/AdminPanel/client/src/assets

PACKAGE_1=/out/document-server-package/common/documentserver-example/welcome/css

INTEGRATION_1=/out/document-server-integration/web/documentserver-example/nodejs/public/images

WIN_RES=/out/desktop-apps/win-linux/res/icons

# SetupIconFile in package/inno/common.iss resolves to this folder, and
# ProjIcons.pro embeds the same file - this is the icon on the installer
# title bar and taskbar button.
PROJICONS=/out/desktop-apps/win-linux/extras/projicons/res/icons

# APP_ICON_PATH in UpdateDaemon.pro
UPDATER_ICONS=/out/desktop-apps/win-linux/extras/update-daemon/res/icons

# Inno Setup wizard artwork (WizImage-* / WizSmallImage-*)
INNO_RES=/out/desktop-apps/package/inno/res

### /Directories that need changed icons ###


mkdir -p "$DESKTOP_1" "$DESKTOP_2" "$DESKTOP_3" "$SERVER_1" "$PACKAGE_1" \
         "$INTEGRATION_1" "$WIN_RES" "$PROJICONS" "$UPDATER_ICONS" "$INNO_RES"

# The existing icotool call produces a single 75px layer. Windows scales
# that for Explorer, the taskbar and alt-tab - each one blurry.
render_multi_ico() {
    local src="$1" out="$2"; shift 2
    local pngs=() s
    for s in "$@"; do
        rsvg-convert --width="$s" --height="$s" --keep-aspect-ratio \
            --background-color=none "$src" -o "/tmp/ico-$s.png"
        pngs+=("/tmp/ico-$s.png")
    done
    mkdir -p "$(dirname "$out")"
    icotool -c -o "$out" "${pngs[@]}"
    rm -f "${pngs[@]}"
}
# The size list upstream ships in desktopeditors.ico - Windows picks a layer
# per DPI scaling, and anything it has to resample itself looks soft.
ICO_SIZES=( 16 20 24 28 30 32 36 40 48 56 60 64 72 80 96 256 )

# Consumed through resources.qrc, which aliases it to app.ico
render_multi_ico /work/svg/logo-light.svg "$WIN_RES/desktopeditors-eo.ico" "${ICO_SIZES[@]}"

# These three are hardcoded as "desktopeditors.ico" by common.iss (SetupIconFile)
# and by APP_ICON_PATH in ASCDocumentEditor.pro / ProjIcons.pro / UpdateDaemon.pro,
# so they have to be overwritten under their original names.
render_multi_ico /work/svg/logo-light.svg "$WIN_RES/desktopeditors.ico"       "${ICO_SIZES[@]}"
render_multi_ico /work/svg/logo-light.svg "$PROJICONS/desktopeditors.ico"     "${ICO_SIZES[@]}"
render_multi_ico /work/svg/logo-light.svg "$UPDATER_ICONS/desktopeditors.ico" "${ICO_SIZES[@]}"

# --- Inno Setup wizard artwork -------------------------------------------
#
# Inno picks the layer closest to the current DPI out of the comma separated
# list in the .iss, so every size below has to exist as its own file. The
# names must stay exactly as they are - they are referenced by
# WizardImageFile / WizardSmallImageFile.
#
# WizImage  : 164x314 base ratio, portrait splash  -> wizard-{light,dark}.svg
# WizSmall  : square app logo, transparent         -> logo-{light,dark}.svg

WIZ_SIZES=( 416x797 366x700 315x604 290x556 240x459 202x386 164x314 )
WIZ_SMALL_SIZES=( 147 129 112 103 85 71 58 )

render_wiz_images() {
    local src="$1" variant="$2" spec w h
    for spec in "${WIZ_SIZES[@]}"; do
        w="${spec%x*}"
        h="${spec#*x}"
        # No --keep-aspect-ratio on purpose: the official sizes deviate from
        # 164:314 by up to 0.3%, and fitting instead of filling would leave a
        # transparent one pixel seam on the edge of an otherwise opaque image.
        rsvg-convert \
            --width="$w" --height="$h" \
            --background-color=none \
            "$src" \
            -o "$INNO_RES/WizImage-${variant}-${spec}.png"
    done
}

render_wiz_small_images() {
    local src="$1" variant="$2" size
    for size in "${WIZ_SMALL_SIZES[@]}"; do
        rsvg-convert \
            --width="$size" --height="$size" \
            --keep-aspect-ratio \
            --background-color=none \
            "$src" \
            -o "$INNO_RES/WizSmallImage-${variant}-${size}x${size}.png"
    done
}

render_wiz_images       /work/svg/wizard-light.svg Light
render_wiz_images       /work/svg/wizard-dark.svg  Dark
render_wiz_small_images /work/svg/logo-light.svg   Light
render_wiz_small_images /work/svg/logo-dark.svg    Dark

# NOTE: the wizard-image.png / wizard-image-small.png block under
# win-linux/package/windows/data is gone. Those feed the dialogpicture*.bmp and
# dialogicon*.bmp directives in package/inno/help.iss, and help.iss is not
# included by common.iss - it is never compiled. Nothing read them.

# --- HiDPI assets for the win/linux res/icons folder ----------------------

render() {
    local scale="$1" suffix="$2"
    local w h
    w=$(awk -v v="$width"  -v s="$scale" 'BEGIN { printf "%.0f", v * s }')
    h=$(awk -v v="$height" -v s="$scale" 'BEGIN { printf "%.0f", v * s }')
    rsvg-convert \
        --width="$w" --height="$h" \
        --keep-aspect-ratio \
        --background-color=none \
        "$src" \
        -o "$DESKTOP_1/${out_base}${suffix}.png"
}

process_svg() {
    local src="$1" out_base="$2"
    local width height
    width=$(xmllint  --xpath 'string(/*[local-name()="svg"]/@width)'  "$src")
    height=$(xmllint --xpath 'string(/*[local-name()="svg"]/@height)' "$src")

    render 1.00 ""
    render 1.25 "@1.25x"
    render 1.50 "@1.5x"
    render 1.75 "@1.75x"
}

process_svg /work/svg/logo-large-dark.svg  logo-dark-eo
process_svg /work/svg/logo-large-light.svg logo-light-eo

# --- Linux app icons (square SVG → fixed pixel sizes) ---------------------

render_linux_icons() {
    local src="$1"
    local size
    for size in 16 24 32 48 64 128 256; do
        rsvg-convert \
            --width="$size" --height="$size" \
            --keep-aspect-ratio \
            --background-color=none \
            "$src" \
            -o "$DESKTOP_2/${size}x${size}.png"
    done
}

render_linux_icons /work/svg/logo-light.svg

# NOTE: the old "render_square_ico ... desktopeditors-eo.ico 75" call used to sit
# here. DESKTOP_1 and WIN_RES are the same folder, so it overwrote the multi-size
# icon rendered above with a single 75px layer - exactly the blurriness the
# render_multi_ico comment warns about. Dropped.

cp /work/svg/logo-large-dark.svg $SERVER_1/logo.svg
cp /work/svg/logo-large-light.svg $SERVER_1/dark-logo_s.svg

cp /work/svg/logo-large-dark.svg $PACKAGE_1/logo.svg
cp /work/svg/logo-light.svg $PACKAGE_1/favicon_eo.svg

cp /work/svg/logo-dark.svg $INTEGRATION_1/mobile-logo_eo.svg
cp /work/svg/logo-light.svg $INTEGRATION_1/favicon_eo.svg
cp /work/svg/logo-large-dark.svg $INTEGRATION_1/logo.svg

cp /work/svg/splash.svg $DESKTOP_1/splash-eo.svg
cp /work/svg/logo-large-light.svg $DESKTOP_1/logo-light-eo.svg
cp /work/svg/logo-large-dark.svg $DESKTOP_1/logo-dark-eo.svg

cp /work/svg/logo-dark.svg $DESKTOP_3/idx-logo-dark-eo.svg
cp /work/svg/logo-light.svg $DESKTOP_3/idx-logo-light-eo.svg

cp /work/config/branding.iss /out/desktop-apps/package/inno/branding.iss

EOF

# Export-only stage: only the generated files end up in the output
FROM scratch AS export
    COPY --from=render /out/ /