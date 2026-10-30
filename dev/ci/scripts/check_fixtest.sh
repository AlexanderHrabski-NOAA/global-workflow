#!/usr/bin/env bash
#
# Check, from the job logs, that the jobs in the fix-file override test cases read
# from the experiment's fix overlay instead of the installed fix tree.
#
# Usage: check_fixtest.sh <ufs|gcafs> <EXPDIR/pslot> <COMROOT/pslot> [HOMEglobal]
#
#   C96C48_ufs_hybatmsoilDA:  check_fixtest.sh ufs   <EXPDIR/pslot> <COMROOT/pslot>
#   C96_gcafs_cycled:         check_fixtest.sh gcafs <EXPDIR/pslot> <COMROOT/pslot>
#
# A job passes if its log shows each expected file copied from, or its orog_path
# set to, ${EXPDIR}/fix/...; it fails if the log shows a copy from the installed tree
# (${HOMEglobal}/fix) or an expected line is missing.

set -u

case_name="${1:?ufs or gcafs}"
fix="${2:?EXPDIR/pslot}/fix"
logdir="${3:?COMROOT/pslot}/logs"
HOMEglobal="${4:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

fmsmpp="gdas/fv3jedi/fv3files/fmsmpp.nml"
snowb="gdas/snow/snow_bump_nicas_250km_shadowlevels_nicas.nc"

nfail=0

# check <task> <fixed string>...
check() {
    local task="$1"
    shift
    local logs
    mapfile -t logs < <(find "${logdir}" -name "*_${task}.log" 2> /dev/null)
    if [[ ${#logs[@]} -eq 0 ]]; then
        echo "FAIL ${task}: no log found under ${logdir}"
        nfail=$((nfail + 1))
        return
    fi
    local log pat
    for log in "${logs[@]}"; do
        for pat in "$@"; do
            if grep -qF -- "${pat}" "${log}"; then
                echo "ok   ${task}: ${pat#"${fix}"/}"
            else
                echo "FAIL ${task}: missing '${pat}' in ${log}"
                nfail=$((nfail + 1))
            fi
        done
        if grep -F "Copied ${HOMEglobal}/fix/" "${log}"; then
            echo "FAIL ${task}: copies from the installed fix tree (above) in ${log}"
            nfail=$((nfail + 1))
        fi
    done
}

if [[ "${case_name}" == "ufs" ]]; then
    check snowanl \
        "Copied ${fix}/orog/C96/C96.mx500_oro_data.tile1.nc" \
        "orog_path = \"${fix}/orog/C96\"" \
        "Copied ${fix}/${snowb}" \
        "Copied ${fix}/${fmsmpp}"
    check esnowanl \
        "Copied ${fix}/orog/C48/C48.mx500_oro_data.tile1.nc" \
        "orog_path = \"${fix}/orog/C48\""
    check soilanlvar \
        "orog_path = \"${fix}/orog/C96\"" \
        "Copied ${fix}/gdas/soil/soill1_bump_nicas_1000km.nc" \
        "Copied ${fix}/${fmsmpp}"
    check soilanlens \
        "orog_path = \"${fix}/orog/" \
        "Copied ${fix}/gdas/soil/soill1_bump_nicas_1000km.nc" \
        "Copied ${fix}/${fmsmpp}"
elif [[ "${case_name}" == "gcafs" ]]; then
    check aeroanlgenb \
        "Copied ${fix}/orog/C96/C96.mx500_oro_data.tile1.nc" \
        "Copied ${fix}/gdas/aero/clim_b/stddev.fv_tracer.res.tile1.nc" \
        "Copied ${fix}/${fmsmpp}"
else
    echo "unknown case '${case_name}'" >&2
    exit 2
fi

if [[ ${nfail} -eq 0 ]]; then
    echo "PASS"
else
    echo "${nfail} check(s) failed"
    exit 1
fi
