# Brand Asset Generation

This directory contains the brand-specific assets and build configuration used to re-brand the document server and desktop editors. The pipeline takes a small set of SVG source files and produces all the rasterized PNGs, ICOs, and copied SVGs the downstream build process expects.

The actual conversion runs inside a small Alpine container via `docker buildx bake`, so no host-side tooling (ImageMagick, Inkscape, etc.) is required.

## File layout

A brand lives in `brands/<brand-name>/` and is expected to contain:

```
brands/nextcloud-office-brand/
├── brand-desktop.hcl              # variables + target for the desktop build
├── brand-server.hcl               # variables + target for the server build
├── build-icons.bake.Dockerfile    # rendering & placement logic (shared)
└── svg/                           # SOURCE SVGs you maintain by hand
    ├── logo-large-dark.svg        # wide logo (best 250x50), dark theme
    ├── logo-large-light.svg       # wide logo (best 250x50), light theme
    ├── logo-dark.svg              # square glyph, dark theme
    ├── logo-light.svg             # square glyph, light theme (tab icon, favicons, installer)
    ├── app-icon.svg               # the application icon: rounded square, Nextcloud-blue gradient + white document glyph
    └── splash.svg                 # splash-screen graphic (best 500x250)
```

The SVGs in `svg/` are the only files you maintain by hand. Everything in `generated/` after a build is reproducible from them.

## Usage

From the repository root:

```bash
# Re-brand the desktop editors
docker buildx bake \
    -f build/docker-bake.hcl \
    -f build/linux/docker-bake.hcl \
    -f build/brands/nextcloud-office-brand/brand-desktop.hcl \
    --set "desktop-linux.contexts.desktop-common=target:desktop-common" \
    --set "*.context=." \
    brand-icons $MAINTARGET

# Re-brand the document server
docker buildx bake \
    -f build/docker-bake.hcl \
    -f build/brands/nextcloud-office-brand/brand-server.hcl \
    --set "*.context=." \
    brand-icons $MAINTARGET
```

where MAINTARGET is the target of the project you want to build.
Each invocation produces a `generated/` directory next to the working directory containing a tree of files ready to be consumed by the next stage of the build. The output is configured by `output = ["type=local,dest=generated"]` in the bake target — change the `dest` if you'd like it written elsewhere.

## What gets generated

From the five source SVGs the pipeline produces:

**Desktop HiDPI logos** (`generated/desktop-apps/win-linux/res/icons/`)
Four-step HiDPI ladder of each wide logo, rendered from the SVG's intrinsic dimensions:
- `logo-dark-eo.png`, `logo-dark-eo@1.25x.png`, `@1.5x`, `@1.75x`
- `logo-light-eo.png`, `logo-light-eo@1.25x.png`, `@1.5x`, `@1.75x`
- Plus copies of the source SVGs as `logo-dark-eo.svg`, `logo-light-eo.svg`, `splash-eo.svg`
- Plus a 75×75 Windows ICO: `desktopeditors-eo.ico`

**Linux app icons** (`generated/desktop-apps/package/common/linux/icons-eo/`)
Square PNGs at sizes 16, 24, 32, 48, 64, 128, 256 — rendered from `app-icon.svg`. These follow the hicolor icon theme naming (`16x16.png`, `24x24.png`, …).

**Login page assets** (`generated/desktop-apps/common/loginpage/res/img/`)
SVG copies for the login page UI.

**Admin panel assets** (`generated/server/AdminPanel/client/src/assets/`)
SVG copies used by the server admin panel.

**Welcome page assets** (`generated/document-server-package/common/documentserver-example/welcome/css/`)
SVG copies for the welcome page.

**Integration example assets** (`generated/document-server-integration/web/documentserver-example/nodejs/public/images/`)
SVG copies for the Node.js integration example.

## Adding or changing a brand

### Replace existing brand assets

Edit the SVGs in `brands/<brand-name>/svg/` and re-run the bake command. Nothing else needs to change. The five SVG files are the entire input surface.

If you're replacing the wide logo (`logo-large-*.svg`), keep the same `viewBox` dimensions or the HiDPI variants will rasterize at a different size. The intrinsic SVG width/height is read at build time and multiplied by 1.00 / 1.25 / 1.5 / 1.75 to produce the four output sizes.

If your new logo contains text rendered via a system font stack (`-apple-system, Roboto, Arial, sans-serif`), the rendering uses **Roboto** (installed in the build container). Test that your text fits the viewBox in Roboto, since Roboto has different metrics than San Francisco or Segoe UI. The most robust option is to convert text to outlined paths in your SVG editor (in Inkscape: Path → Object to Path) so the renderer doesn't need a font at all.

### Add a brand alongside Nextcloud Office

1. Copy the whole `brands/nextcloud-office-brand/` directory to `brands/<new-brand>/`.
2. Replace the SVGs in `svg/`.
3. Update the variables at the top of `brand-desktop.hcl` and `brand-server.hcl`:
   - `COMPANY_NAME` — display name used by the downstream build
   - `PRODUCT_NAME` — product name used by the downstream build
   - `BRANDING_DIR` — path to this brand's directory
4. Run the bake commands above, pointing `-f` at the new brand's HCL files.

The `Do not change below this line` section of each HCL file defines the `brand-icons` target. You shouldn't need to edit it per-brand unless you're changing the set of files produced.

## Modifying what gets generated

All generation logic lives in `build-icons.bake.Dockerfile` inside the heredoc'd `RUN` block. Three independent groups:

**HiDPI logos** — `process_svg <source> <output-base-name>`
Renders a wide SVG at 1×, 1.25×, 1.5×, 1.75× of its intrinsic size into `$DESKTOP_1`. Add scales by adding `render <scale> "<suffix>"` calls inside `process_svg`.

**Linux app icons** — `render_linux_icons <source>`
Generates a square PNG ladder. Edit the `for size in 16 24 32 48 64 128 256` loop to change the sizes.

**Single-size ICO** — `render_square_ico <source> <output-path> <size>`
Renders one square PNG at the given size and wraps it as a single-resolution ICO.

**Static SVG placement** — the `cp` block at the bottom.
Each line copies one source SVG to one destination path. The output directories are defined as variables (`DESKTOP_1`, `SERVER_1`, etc.) at the top of the script.

To add a new placement: add the destination directory to the `mkdir -p` line and add a `cp` line. To add a new generated raster: define a new helper function or extend an existing one.

## How it fits together

```
brand-desktop.hcl  ──┐
                     ├─►  bake target "brand-icons"
brand-server.hcl   ──┘                │
                                      ▼
                     build-icons.bake.Dockerfile
                                      │
                            ┌─────────┴──────────┐
                            ▼                    ▼
                    rsvg-convert/icotool      cp (SVGs)
                            │                    │
                            └─────────┬──────────┘
                                      ▼
                          generated/  (local output)
                                      │
                                      ▼
                       consumed by main project build
```

The `brand-icons` target runs in its own Alpine container with `rsvg-convert`, `icoutils`, `fontconfig`, and `font-roboto` installed. The `FROM scratch AS export` final stage means only the `/out/` tree (mounted to `generated/` on the host) leaves the container — no Alpine base, no tooling.

## License

AGPL-3.0-only, see [LICENSE](LICENSE), unless a file says otherwise ([REUSE.toml](REUSE.toml)).

- The document glyph in `svg/` comes from [Google Material Symbols](https://github.com/google/material-design-icons) (Apache-2.0, see [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt)).
- `.github/workflows/conventional-commits.yml` is MIT, see its header.
- The Nextcloud name and logo are trademarks of Nextcloud GmbH. The licence grants no rights to use them.
