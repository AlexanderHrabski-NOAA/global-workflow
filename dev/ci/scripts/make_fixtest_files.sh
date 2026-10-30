#!/usr/bin/env bash
#
# Make marked copies of the fix files that the fix_files: sections of
# ufs_hybatmsoilDA_defaults_ci.yaml and gcafs_cycled_defaults_ci.yaml replace,
# in ${HOMEglobal}/fixtest.  Run once, after link_workflow.sh, before setting up
# either case.  Netcdf files get a global attribute fix_test="CUSTOM", the
# namelist gets a trailing comment; neither changes what a job does with the file.
#
# Usage: make_fixtest_files.sh [HOMEglobal]

set -eu

HOMEglobal="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
FIXTEST="${HOMEglobal}/fixtest"

files=(
    orog/C96/C96.mx500_oro_data.tile1.nc
    orog/C48/C48.mx500_oro_data.tile1.nc
    gdas/fv3jedi/fv3files/fmsmpp.nml
    gdas/snow/snow_bump_nicas_250km_shadowlevels_nicas.nc
    gdas/soil/soill1_bump_nicas_1000km.nc
    gdas/aero/clim_b/stddev.fv_tracer.res.tile1.nc
)

mark_nc() {
    if command -v ncatted > /dev/null 2>&1; then
        ncatted -O -h -a fix_test,global,c,c,CUSTOM "$1"
    else
        python3 -c "import sys, netCDF4; d = netCDF4.Dataset(sys.argv[1], 'a'); d.setncattr('fix_test', 'CUSTOM'); d.close()" "$1"
    fi
}

for f in "${files[@]}"; do
    src="${HOMEglobal}/fix/${f}"
    dst="${FIXTEST}/${f}"
    if [[ ! -f "${src}" ]]; then
        echo "ERROR: ${src} is not in the installed fix tree" >&2
        exit 1
    fi
    mkdir -p "$(dirname "${dst}")"
    rm -f "${dst}"
    cp -L "${src}" "${dst}"
    case "${f}" in
        *.nc) mark_nc "${dst}" ;;
        *) echo "! FIXTEST" >> "${dst}" ;;
    esac
    echo "made ${dst}"
done
