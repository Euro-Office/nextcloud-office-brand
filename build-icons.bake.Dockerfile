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
ARG SVG_DIR=svg

# Bring in the SVGs from the build context
COPY ${SVG_DIR}/ /work/svg/

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
WIN_PKG=/out/desktop-apps/win-linux/package/windows/data

# Inno Setup wizard artwork (WizImage-* / WizSmallImage-*)
INNO_RES=/out/desktop-apps/package/inno/res
### /Directories that need changed icons ###


mkdir -p "$DESKTOP_1" "$DESKTOP_2" "$DESKTOP_3" "$SERVER_1" "$PACKAGE_1" \
         "$INTEGRATION_1" "$WIN_RES" "$WIN_PKG" "$INNO_RES"

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
render_multi_ico /work/svg/logo-light.svg "$WIN_RES/desktopeditors-eo.ico" \
    16 24 32 48 64 128 256

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

# Older single-file wizard artwork under package/windows/data. Inno Setup
# 6.5.2+ accepts PNG including transparency for WizardImageFile and
# WizardSmallImageFile - no BMP, no ImageMagick needed. Drop this block if
# the .iss only consumes the INNO_RES set above.
rsvg-convert --width=328 --height=628 \
    --background-color=none /work/svg/wizard-light.svg \
    -o "$WIN_PKG/wizard-image.png"
rsvg-convert --width=220 --height=220 --keep-aspect-ratio \
    --background-color=none /work/svg/logo-light.svg \
    -o "$WIN_PKG/wizard-image-small.png"

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

render_square_ico() {
    local src="$1" out_path="$2" size="$3"
    local tmp_png=/tmp/render.png
    rsvg-convert \
        --width="$size" --height="$size" \
        --keep-aspect-ratio \
        --background-color=none \
        "$src" \
        -o "$tmp_png"
    mkdir -p "$(dirname "$out_path")"
    icotool -c -o "$out_path" "$tmp_png"
    rm -f "$tmp_png"
}

render_square_ico /work/svg/logo-light.svg $DESKTOP_1/desktopeditors-eo.ico 75

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

EOF

# Export-only stage: only the generated files end up in the output
FROM scratch AS export
    COPY --from=render /out/ /