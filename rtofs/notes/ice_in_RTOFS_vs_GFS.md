# CICE6 `ice_in` — RTOFS (GLBb0.08 / mx008) vs. GFS config

Comparison of the sea-ice namelist between the **GFS global-workflow** config and the
**RTOFS** config, for the resolution/run this experiment uses.

- **GFS** = `ice_in` rendered by the workflow from
  [`sorc/ufs_model.fd/tests/parm/ice_in.IN`](sorc/ufs_model.fd/tests/parm/ice_in.IN)
  filled by [`ush/parsing_namelists_CICE.sh`](ush/parsing_namelists_CICE.sh), for
  `RUN=gdas`, `OCNRES=ICERES=008`, `CASE=C384`. `@[...]` values below are resolved to
  what those inputs produce.
- **RTOFS** = the static `ice_in` delivered by the RTOFS team (dropped in the repo root as
  [`ice_in`](ice_in)); `grid_file = grid_cice_NEMS_mx008.nc`.

Unlike the MOM6 comparison, **we did not modify the GFS CICE config** — the workflow config
is used as-is (the one `slenderX1` edit explored during debugging was reverted). So the
fourth column is *impact*, not "our change."

**Headline:** the two are the **same CICE model configuration** everywhere it affects the
restart or the physics — identical categories, layers, tracers, thermodynamics, and the
whole rheology/shortwave/pond/forcing parameter set. That structural identity is why the
RTOFS restart reads into the GFS run. The differences are confined to one dynamics
sub-cycle count, a few restart-handling/IO flags, the PE decomposition, and history output.

---

## 0. Nature of the file

| Aspect         | GFS config                                          | RTOFS config                                | Impact                                        |
| -------------- | --------------------------------------------------- | ------------------------------------------- | --------------------------------------------- |
| File kind      | Template (`ice_in.IN`) + `parsing_namelists_CICE.sh`| Static, hand-delivered `ice_in`             | GFS values are run/resolution-driven          |
| Run-specific   | dates, decomposition, IO tasks all computed         | fixed for the RTOFS test                    | most "differences" below are workflow plumbing|
| CICE version   | `CICE_6.0.2`                                         | `CICE_6.0.2`                                | same code base                                |

---

## 1. Grid & categories (`&grid_nml`) — all match

| Parameter     | GFS               | RTOFS                     | Impact                              |
| ------------- | ----------------- | ------------------------- | ----------------------------------- |
| `grid_type`   | `tripole`         | `tripole`                 | — (match)                           |
| `grid_file`   | `grid_cice_NEMS_mx008.nc` | `grid_cice_NEMS_mx008.nc` | — (identical filename)      |
| `kmt_file`    | `kmtu_cice_NEMS_mx008.nc` | `kmtu_cice_NEMS_mx008.nc` | — (identical filename)      |
| `kcatbound`   | `0`               | `0`                       | — (match; category boundary formula)|
| `ncat`        | `5`               | `5`                       | — **restart-critical, match**       |
| `nilyr`       | `7`               | `7`                       | — **restart-critical, match**       |
| `nslyr`       | `1`               | `1`                       | — **restart-critical, match**       |
| `nblyr`       | `1`               | `1`                       | — (match)                           |
| `nfsd`        | `1`               | `1`                       | — (match; FSD off anyway)           |
| `grid_atm/ocn/ice` | `A`/`A`/`B`  | `A`/`A`/`B`               | — (match)                           |

This section is the whole reason the restart is compatible: the 4-D field shapes
`(ni, nj, ncat, nlyr)` are identical.

---

## 2. Tracers (`&tracer_nml`) — all match

| Tracer          | GFS       | RTOFS     | Impact                    |
| --------------- | --------- | --------- | ------------------------- |
| `tr_iage`       | `.true.`  | `.true.`  | — (match)                 |
| `tr_lvl`        | `.true.`  | `.true.`  | — (match)                 |
| `tr_pond_lvl`   | `.true.`  | `.true.`  | — (match; level ponds)    |
| `tr_FY`         | `.false.` | `.false.` | — (match)                 |
| `tr_pond_topo`  | `.false.` | `.false.` | — (match)                 |
| `tr_pond_sealvl`| `.false.` | `.false.` | — (match)                 |
| `tr_aero`       | `.false.` | `.false.` | — (match)                 |
| `tr_fsd`        | `.false.` | `.false.` | — (match)                 |

Same active tracer set → same tracer fields in the restart. (All `restart_<tracer>=.false.`
in both, so tracers re-init rather than read — also identical.)

---

## 3. Thermodynamics (`&thermo_nml`) — all match

| Parameter  | GFS      | RTOFS    | Impact                          |
| ---------- | -------- | -------- | ------------------------------- |
| `kitd`     | `1`      | `1`      | — (match; linear remap ITD)     |
| `ktherm`   | `2`      | `2`      | — (match; **mushy-layer** thermo)|
| `conduct`  | `MU71`   | `MU71`   | — (match)                       |
| mushy params (`a_rapid_mode`, `phi_i_mushy`, …) | identical | identical | — (match) |

---

## 4. Dynamics (`&dynamics_nml`) — one difference

| Parameter        | GFS       | RTOFS     | Impact                                                        |
| ---------------- | --------- | --------- | ------------------------------------------------------------- |
| **`ndte`**       | **`120`** | **`300`** | **EVP elastic sub-cycles/step.** RTOFS uses 2.5× more (`dte=1s` vs `2.5s`): stiffer, more accurate rheology at higher cost. The *only* physics-tuning difference. |
| `kdyn`           | `1`       | `1`       | — (match; EVP)                                                |
| `evp_algorithm`  | `standard_2d` | `standard_2d` | — (match)                                             |
| `revised_evp`    | `.false.` | `.false.` | — (match)                                                     |
| `brlx` / `arlx`  | `300` / `300` | `300` / `300` | — (match)                                             |
| `ssh_stress`     | `coupled` | `coupled` | — (match)                                                     |
| `advection`      | `remap`   | `remap`   | — (match)                                                     |
| `kstrength`, `krdg_partic/redist`, `mu_rdg`, `Cf`, `e_yieldcurve`, `e_plasticpot`, `coriolis`, `kridge`, `ktransport`, `dyn_area_min`, `dyn_mass_min` | identical | identical | — (match) |

---

## 5. Shortwave / ponds / snow (`&shortwave_nml`, `&ponds_nml`, `&snow_nml`) — all match

| Parameter                 | GFS      | RTOFS    | Impact                    |
| ------------------------- | -------- | -------- | ------------------------- |
| `shortwave`               | `dEdd`   | `dEdd`   | — (match; Delta-Eddington)|
| albedos (`albicev/i`, `albsnowv/i`), `ahmax`, `R_snw`, `dT_mlt`, `rsnw_mlt`, `sw_redist` | identical | identical | — (match) |
| ponds (`frzpnd='hlid'`, `hp1`, `hs1`, `rfracmin/max`, `pndaspect`, …) | identical | identical | — (match) |
| `snwredist`               | `none`   | `none`   | — (match)                 |

---

## 6. Forcing / coupling (`&forcing_nml`) — all match

| Parameter        | GFS       | RTOFS     | Impact                              |
| ---------------- | --------- | --------- | ----------------------------------- |
| `atmbndy`        | `default` | `default` | — (match)                           |
| `fbot_xfer_type` | `constant`| `constant`| — (match)                           |
| `update_ocn_f`   | `.true.`  | `.true.`  | — (match; frazil FW/salt to ocean)  |
| `tfrz_option`    | `mushy`   | `mushy`   | — (match; consistent with `ktherm=2`)|
| `formdrag`, `calc_strair`, `calc_Tsfc`, `highfreq`, `natmiter`, `ustar_min`, `emissivity`, `l_mpond_fresh`, `restart_coszen` | identical | identical | — (match) |

---

## 7. Time stepping & restart handling (`&setup_nml`) — several differences

| Parameter          | GFS                       | RTOFS                 | Impact                                                                 |
| ------------------ | ------------------------- | --------------------- | --------------------------------------------------------------------- |
| `dt`               | `300` (`=ICETIM=DELTIM`)  | `300`                 | — (match for C384)                                                     |
| `runtype`          | `continue` (warm)         | `continue`            | — (match)                                                             |
| **`use_restart_time`** | **`.true.`**          | **`.false.`**         | GFS adopts CICE's clock **from the restart's internal date**; RTOFS ignores it. **Watch with a wrong-day restart** — the CICE analog of MOM6 `FATAL_INCONSISTENT_RESTART_TIME`. |
| **`restart_mod`**  | **`none`**                | **`&adjust_aice`**    | RTOFS re-adjusts ice concentration on restart read (init/DA consistency); GFS reads as-is. |
| **`write_ic`**     | **`.true.`**              | **`.false.`**         | GFS writes an f000 IC history snapshot. Output only.                   |
| `ice_ic`           | `cice_model.res.nc`       | `INPUT/iced.<date>.nc`| Filename convention (why the RTOFS restart is renamed on staging).     |
| `restart_format`   | `pnetcdf2`                | `pnetcdf2`            | — (match)                                                             |
| `diagfreq`         | `288` (`=86400/dt`, 1/day)| `48` (every 4 h)      | diagnostic-print cadence. Cosmetic.                                    |
| IO (`restart_iotasks/stride/rearranger`, `numin/numax`) | workflow-set | fixed | plumbing; not physical |

---

## 8. Domain decomposition (`&domain_nml`) — layout difference

| Parameter          | GFS (008)              | RTOFS                 | Impact                                                              |
| ------------------ | --------------------- | --------------------- | ------------------------------------------------------------------ |
| `nprocs`           | `250` (gdas)          | `384`                 | rank count (from `ntasks_cice6`)                                    |
| **`processor_shape`** | **`slenderX2`**    | **`slenderX1`**       | GFS: `NPY=2` (pads odd `NY=3297` by one row — tolerated on read); RTOFS: `NPY=1`, no pad. Both valid; layout only. |
| `block_size_x`     | `36` (`4500/125`)     | `12` (`4500/375`)     | derived from shape/rank count                                       |
| `block_size_y`     | `1649` (`ceil(3297/2)`)| `3297` (whole)       | derived                                                             |
| `nx_global` / `ny_global` | `4500` / `3297` | `4500` / `3297`       | — (match)                                                          |
| `distribution_type/wght`, `ew/ns_boundary_type`, `maskhalo_*` | `cartesian`/`latitude`, `cyclic`/`tripole`, `.false.` | same | — (match) |

---

## 9. History & diagnostic output (`&icefields_*`) — output-only differences

| Aspect                | GFS                                   | RTOFS                              | Impact                          |
| --------------------- | ------------------------------------- | --------------------------------- | ------------------------------- |
| output field set      | **rich** — many fields `'mdh1x'`, grid metrics (`f_tmask`, `f_tarea`, `f_NCAT`, `f_ANGLE`, `f_VGRDa`) on | **minimal** — most `'x'` (off), a handful `'mdh1x'` | history content only; no effect on the run |
| `histfreq_n`          | workflow-computed (gdas: instantaneous) | `0,0,1,0,0` (hourly)             | output cadence                  |
| `hist_avg`            | `.false.`×5 (gdas/DA) · `.true.`×5 (gfs) | `.false.`×5                     | gdas matches; averaging choice  |
| `history_precision`   | `CICE_HISTORY_PREC`                    | `4`                               | output precision                |

None of this changes the simulation — it only sets what/when CICE writes to history.

---

## 10. Prescribed-ice mode (`&ice_prescribed_nml`)

| Parameter             | GFS                                   | RTOFS   | Impact                                   |
| --------------------- | ------------------------------------- | ------- | ---------------------------------------- |
| `&ice_prescribed_nml` | present, `prescribed_ice_mode=@[CICE_PRESCRIBED]` (default `.false.`) | empty | GFS *supports* data-ice mode; off by default → no effect |

---

## Summary — what actually differs

| Category                | Same? | Notes                                                                 |
| ----------------------- | ----- | --------------------------------------------------------------------- |
| Grid, categories, layers| ✅    | identical — restart-compatible                                        |
| Tracers                 | ✅    | identical active set                                                  |
| Thermodynamics          | ✅    | `ktherm=2` mushy, `MU71`, identical                                   |
| Rheology / advection    | ⚠️    | scheme + all params identical **except `ndte` (120 vs 300)**          |
| Shortwave / ponds / snow| ✅    | identical                                                             |
| Forcing / coupling      | ✅    | identical                                                             |
| Restart handling        | ⚠️    | `use_restart_time` (**watch, wrong-day**), `restart_mod`, `write_ic`  |
| Decomposition           | ⚠️    | `slenderX2` vs `slenderX1` — layout only                              |
| History output          | ⚪    | different field set/cadence — cosmetic                                |

**Bottom line:** physically the same ice model. The one substantive knob is `ndte`
(hardcoded at [`ice_in.IN:113`](sorc/ufs_model.fd/tests/parm/ice_in.IN#L113) — set it to
`300` if you want to reproduce RTOFS ice dynamics exactly). The one to keep an eye on for
this warm-start-from-a-wrong-day-restart is `use_restart_time=.true.`.
