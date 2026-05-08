#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 --name=<name> --lon=<lon> --lat=<lat> [--depth=<depth>]" >&2
    exit 1
}

NAME=""
LON=""
LAT=""
DEPTH=""

for arg in "$@"; do
    case "$arg" in
        --name=*)  NAME="${arg#*=}" ;;
        --lon=*)   LON="${arg#*=}" ;;
        --lat=*)   LAT="${arg#*=}" ;;
        --depth=*) DEPTH="${arg#*=}" ;;
        *) echo "Unknown argument: $arg" >&2; usage ;;
    esac
done

[[ -z "$NAME" || -z "$LON" || -z "$LAT" ]] && usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$SCRIPT_DIR/$NAME"

[[ -d "$OUTDIR" ]] && { echo "Error: $OUTDIR already exists" >&2; exit 1; }

XMIN=$(awk "BEGIN { printf \"%.10g\", $LON - 0.5 }")
XMAX=$(awk "BEGIN { printf \"%.10g\", $LON + 0.5 }")
YMIN=$(awk "BEGIN { printf \"%.10g\", $LAT - 0.5 }")
YMAX=$(awk "BEGIN { printf \"%.10g\", $LAT + 0.5 }")

mkdir "$OUTDIR"
echo "Created directory: $OUTDIR"
cd "$OUTDIR"

# --- Supergrid and mosaic ---
echo -n "Creating supergrid... "
module use /g/data/vk83/modules &>/dev/null
module load fre-nctools/2024.05-1 &>/dev/null
make_hgrid --grid_type simple_cartesian_grid \
    --xbnds "$XMIN,$XMAX" \
    --ybnds "$YMIN,$YMAX" \
    --simple_dx 23680 --simple_dy 27640 \
    --nlon 4 --nlat 4 &>/dev/null
echo "Done"

echo -n "Creating ocean mosaic... "
make_solo_mosaic --num_tiles 1 --dir ./ --mosaic_name ocean_mosaic --tile_file horizontal_grid.nc &>/dev/null
echo "Done"

# --- Python steps (analysis3) ---
echo -n "Creating ESMF mesh... "
module purge &>/dev/null
module use /g/data/xp65/public/modules &>/dev/null
module load conda/analysis3 &>/dev/null
python3 /g/data/vk83/apps/om3-scripts/mesh_generation/generate_mesh.py \
    --grid-type=mom \
    --grid-filename=./horizontal_grid.nc \
    --mesh-filename=./single-column-ESMFmesh.nc \
    --wrap-lons=True &>/dev/null
echo "Done"

echo -n "Creating WOMBAT sFe forcing... "
python3 /g/data/vk83/apps/om3-scripts/wombat_ic_generation/regrid_forcing.py \
    --forcing-filename=/g/data/vk83/prerelease/configurations/inputs/access-om3/wombat/forcing/global.25km/2025.09.29/SFe_Hamiltonetal2020_monthly_clim.nc \
    --hgrid-filename=./horizontal_grid.nc \
    --output-filename=./SFe_Hamiltonetal2020_monthly_clim.nc \
    --homogenize &>/dev/null
echo "Done"

echo -n "Creating CHL climatology for SW pen... "
python3 /g/data/vk83/apps/om3-scripts/wombat_ic_generation/regrid_forcing.py \
    --forcing-filename=/g/data/vk83/prerelease/configurations/inputs/access-om3/mom/chlorophyll/global.25km/2026.05.08/chl_globcolour_monthly_clim.nc \
    --hgrid-filename=./horizontal_grid.nc \
    --output-filename=./chl_globcolour_monthly_clim.nc \
    --homogenize &>/dev/null
echo "Done"

if [[ -n "$DEPTH" ]]; then
    echo -n "Creating topog.nc... "
    python3 - &>/dev/null <<EOF
import netCDF4 as nc
with nc.Dataset("topog.nc", "w") as ds:
    ds.createDimension("nx", 4)
    ds.createDimension("ny", 4)
    d = ds.createVariable("depth", "f8", ("ny", "nx"))
    d[:] = $DEPTH
    d.units = "m"
EOF
    echo "Done"
fi

# --- MOM_override ---
echo -n "Creating MOM_override... "
OMEGA=7.2921e-5  # Earth rotation rate, rad/s (MOM6 default value)
F0=$(python3 -c "import math; print(f'{2 * $OMEGA * math.sin(math.radians($LAT)):.5e}')")
SOUTHLAT=$(awk "BEGIN { printf \"%.10g\", $LAT - 0.5 }")
WESTLON=$(awk "BEGIN { printf \"%.10g\", $LON - 0.5 }")

{
    echo "F_0 = $F0"
    echo "SOUTHLAT = $SOUTHLAT"
    echo "WESTLON = $WESTLON"
    [[ -n "$DEPTH" ]] && echo '#override TOPO_CONFIG = "file"'
} > MOM_override
echo "Done"
