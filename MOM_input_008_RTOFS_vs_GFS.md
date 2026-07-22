# MOM6 `MOM_input_008` — RTOFS (GLBb0.08) vs. GFS config, and our changes

Purpose: document how the RTOFS 8 km MOM6 configuration (`sorc/ufs_model.fd/tests/parm/MOM_input_008.IN`,
current `HEAD`) differs from the GFS-lineage config it replaced (the "loose copy of the 25 km GFS
config for an 8 km grid", `HEAD~1`), and record every change we have made to the file so far while
adapting it to be driven by the global workflow with GDAS/SOCA data assimilation.

Column key:
  - **GFS config (HEAD~1)** — the GFS-lineage template it replaced (mx025 physics on the 8 km grid).
  - **RTOFS config (HEAD, as delivered)** — the RTOFS team's MOM6 parameter dump.
  - **Our change** — what we did to `MOM_input_008.IN` this session ("— (kept)" = intentionally left as RTOFS delivered it).

Legend: `@[X]` = atparse template placeholder filled at runtime by the workflow.


## 0. Nature of the file

| Aspect                | GFS config (HEAD~1)           | RTOFS config (HEAD, as delivered)                    | Our change                                  |
| --------------------- | ----------------------------- | ---------------------------------------------------- | ------------------------------------------- |
| File kind             | Hand-maintained template      | Model-generated `MOM_parameter_doc` dump             | Re-introduced templating (see below)        |
| Length                | ~990 lines, non-defaults only | ~2119 lines, every parameter incl. defaults          | left long form (kept)                       |
| `@[...]` placeholders | 28                            | 0 (all values hardcoded)                             | restored 17 workflow-owned placeholders     |
| Consequence           | Workflow-drivable             | atparse passes through verbatim → config.ufs ignored | Workflow control restored for runtime knobs |


## 1. Grid & domain

| Parameter       | GFS (HEAD~1)     | RTOFS (HEAD)       | Our change                                        |
| --------------- | ---------------- | ------------------ | ------------------------------------------------- |
| `NIGLOBAL`      | `@[NX_GLB]`      | `4500`             | → `@[NX_GLB]` (templatized; config.ufs sets 4500) |
| `NJGLOBAL`      | `@[NY_GLB]`      | `3297`             | → `@[NY_GLB]` (templatized; config.ufs sets 3297) |
| `REENTRANT_X`   | (default)        | `True`             | — (kept; global tripolar grid)                    |
| `TRIPOLAR_N`    | `True`           | `True`             | — (kept)                                          |
| `GRID_FILE`     | `ocean_hgrid.nc` | `regional.mom6.nc` | → `ocean_hgrid.nc` (rename; RTOFS team request)   |
| `MAXIMUM_DEPTH` | `6500.0`         | `8200.0`           | — (kept)                                          |
| `MINIMUM_DEPTH` | `9.5`            | `3.0`              | — (kept)                                          |
| `MASKING_DEPTH` | `0.0`            | `-9999.0`          | — (kept)                                          |


## 2. Bathymetry & channels

| Parameter           | GFS (HEAD~1)              | RTOFS (HEAD)                      | Our change                                               |
| ------------------- | ------------------------- | --------------------------------- | -------------------------------------------------------- |
| `TOPO_FILE`         | `ocean_topog.nc`          | `depth_GLBb0.08_09m11ob2_mom6.nc` | → `ocean_topog.nc` (rename; provenance kept in comments) |
| `TOPO_VARNAME`      | (default `depth`)         | `depth`                           | — (kept; matches standard name)                          |
| `TOPO_EDITS_FILE`   | `All_edits.nc`            | `""` (none)                       | — (kept; RTOFS uses no topo edits)                       |
| `CHANNEL_CONFIG`    | `list`                    | `none`                            | — (kept)                                                 |
| `CHANNEL_LIST_FILE` | `MOM_channels_global_025` | (n/a)                             | — (not needed at `none`)                                 |


## 3. Time stepping

| Parameter               | GFS (HEAD~1)          | RTOFS (HEAD)                              | Our change                                                                                         |
| ----------------------- | --------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `DT`                    | `@[DT_DYNAM_MOM6]`    | `300.0`                                   | → `@[DT_DYNAM_MOM6]` (templatized)                                                                 |
| `DT_THERM`              | `@[DT_THERM_MOM6]`    | `300.0` (with `#DT_THERM=1200` commented) | collapsed to single `@[DT_THERM_MOM6]`; config.ufs 008 set to `300` to preserve as-tested behavior |
| `THERMO_SPANS_COUPLING` | `@[MOM6_THERMO_SPAN]` | `False`                                   | — (kept hardcoded False)                                                                           |


## 4. Vertical coordinate

| Parameter                    | GFS (HEAD~1)                               | RTOFS (HEAD)                     | Our change                                     |
| ---------------------------- | ------------------------------------------ | -------------------------------- | ---------------------------------------------- |
| `NK` (layers)                | `75`                                       | `41`                             | — (kept; RTOFS is 41-layer)                    |
| `REGRIDDING_COORDINATE_MODE` | `HYCOM1`                                   | `HYCOM1`                         | — (kept)                                       |
| `COORD_FILE`                 | `layer_coord.nc`                           | `mom6_vgrid.nc`                  | — (kept: RTOFS merges coord+ALE into one file) |
| `ALE_COORDINATE_CONFIG`      | `HYBRID:hycom1_75_800m.nc,sigma2,FNC1:...` | `HYBRID:mom6_vgrid.nc,sigma2,dz` | — (kept; same `mom6_vgrid.nc` as COORD_FILE)   |
| `REMAPPING_SCHEME`           | `PPM_H4`                                   | `PPM_CW`                         | — (kept)                                       |
| `MAX_LAYER_THICKNESS_CONFIG` | `FNC1:400,31000,0.1,.01`                   | `PARAM` (`41*750.0`)             | — (kept)                                       |
| `EQN_OF_STATE`               | `WRIGHT_FULL`                              | `WRIGHT`                         | — (kept)                                       |
| `DEFAULT_ANSWER_DATE`        | `20250818`                                 | `20230509`                       | — (kept; RTOFS answer vintage)                 |

Note: `mom6_vgrid.nc` is NOT renamed — in GFS the vertical setup is two files
(`layer_coord.nc` for densities + `hycom1_75_800m.nc` for the ALE HYBRID target); RTOFS
consolidates both roles into one 41-layer file, so there is no exact equivalent.


## 5. Initialization

| Parameter                    | GFS (HEAD~1)               | RTOFS (HEAD)                                | Our change                     |
| ---------------------------- | -------------------------- | ------------------------------------------- | ------------------------------ |
| Strategy                     | Warm start from restart/IC | Cold start from WOA13 climatology           | — (kept; RTOFS science choice) |
| `INIT_LAYERS_FROM_Z_FILE`    | `@[MOM6_INIT_FROM_Z]`      | `True`                                      | — (kept)                       |
| `TEMP_Z_INIT_FILE`           | (via `MOM6_IC_TS.nc`)      | `woa13_decav_ptemp_monthly_fulldepth_01.nc` | — (kept)                       |
| `SALT_Z_INIT_FILE`           | (via `MOM6_IC_TS.nc`)      | `woa13_decav_s_monthly_fulldepth_01.nc`     | — (kept)                       |
| `THICKNESS_FILE` / warmstart | `@[MOM6_WARMSTART_FILE]`   | (absent — cold start)                       | — (kept)                       |


## 6. Physics / parameterizations

| Parameter                           | GFS (HEAD~1)                            | RTOFS (HEAD)                                  | Our change                 |
| ----------------------------------- | --------------------------------------- | --------------------------------------------- | -------------------------- |
| `USE_MEKE`                          | `True`                                  | `False`                                       | — (kept)                   |
| `THICKNESSDIFFUSE`                  | `True`                                  | `False` (`APPLY_INTERFACE_FILTER=True`)       | — (kept)                   |
| `RESOLN_SCALED_KH` / `_KHTH`        | `True`                                  | `False`                                       | — (kept)                   |
| `CHANNEL_DRAG`                      | `True`                                  | `False` (`BOTTOMDRAGLAW=True`, `CDRAG=0.003`) | — (kept)                   |
| `INT_TIDE_DISSIPATION`              | `True`                                  | `False`                                       | — (kept; tidal mixing off) |
| `READ_TIDEAMP` / `TIDEAMP_FILE`     | `True` / `tidal_amplitude.v20140616.nc` | `False` / (none)                              | — (kept)                   |
| `DO_GEOTHERMAL` / `GEOTHERMAL_FILE` | `True` / `geothermal_davies2013_v1.nc`  | `False` / (none)                              | — (kept)                   |
| `EPBL_MSTAR_SCHEME`                 | `OM4`                                   | `REICHL_H18`                                  | — (kept)                   |


## 7. Surface forcing & restoring

| Parameter               | GFS (HEAD~1)                                        | RTOFS (HEAD)                        | Our change                                                               |
| ----------------------- | --------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------ |
| `OCEAN_SURFACE_STAGGER` | `A`                                                 | `C`                                 | — (kept)                                                                 |
| `WIND_STAGGER`          | `A`                                                 | `C`                                 | — (kept)                                                                 |
| `CHL_FILE`              | `@[MOM6_CHLCLIM]` (seawifs)                         | `chl_mom6.nc` (`CHL_VARNAME=chl_a`) | — (kept; different dataset/grid/varname)                                 |
| `RESTORE_SALINITY`      | (absent)                                            | `True`                              | — (kept; new capability)                                                 |
| `SALT_RESTORE_FILE`     | (n/a)                                               | `sss_mom6.nc`                       | — (kept; no GFS equivalent)                                              |
| `BASIN_FILE`            | (n/a)                                               | `basin.nc`                          | — (kept; already MOM6 default name)                                      |
| River runoff            | `LIQUID_RUNOFF_FROM_DATA=@[MOM6_RIVER_RUNOFF]`      | (absent)                            | — (kept)                                                                 |
| Waves                   | `USE_WAVES=@[MOM6_USE_WAVES]` + SURFACE_BANDS block | `USE_WAVES=False`, no wave block    | — (kept False; NOTE: coupling WW3 later requires porting the wave block) |


## 8. Ocean DA — ODA incremental update  (the critical fix)

| Parameter                       | GFS (HEAD~1)                          | RTOFS (HEAD, as delivered)               | Our change                                                                  |
| ------------------------------- | ------------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------- |
| `ODA_INCUPD`                    | `@[ODA_INCUPD]`                       | `&Value`  ← broken token, fatal at parse | → `@[ODA_INCUPD]` (fixes fatal + restores control)                          |
| `ODA_INCUPD_FILE`               | `mom6_increment.nc`                   | `MOM.inc.TSzh.nc`                        | → `mom6_increment.nc` (workflow/SOCA convention)                            |
| `ODA_TEMPINC_VAR`               | `@[ODA_TEMPINC_VAR]`                  | `pt_inc`                                 | → `@[ODA_TEMPINC_VAR]` (workflow default `Temp`)                            |
| `ODA_SALTINC_VAR`               | `@[ODA_SALTINC_VAR]`                  | `s_inc`                                  | → `@[ODA_SALTINC_VAR]` (workflow default `Salt`)                            |
| `ODA_THK_VAR`                   | `@[ODA_THK_VAR]`                      | `zh`                                     | → `@[ODA_THK_VAR]` (workflow default `h`)                                   |
| `ODA_INCUPD_UV`                 | `@[ODA_INCUPD_UV]`                    | `True`                                   | → `@[ODA_INCUPD_UV]`                                                        |
| `ODA_UINC_VAR` / `ODA_VINC_VAR` | `@[ODA_UINC_VAR]` / `@[ODA_VINC_VAR]` | `u_inc` / `v_inc`                        | → `@[ODA_UINC_VAR]` / `@[ODA_VINC_VAR]` (u/v read from same increment file) |
| `ODA_INCUPD_UV_FILE`            | (absent — u/v in main file)           | `MOM.inc.UV.nc`                          | dropped (u/v now in `mom6_increment.nc`)                                    |
| `ODA_INCUPD_NHOURS`             | `@[ODA_INCUPD_NHOURS]`                | `6.0`                                    | → `@[ODA_INCUPD_NHOURS]` (from `config.ocn.j2`: 6 w/ IAU else 3)            |
| `ODA_INCUPD_INC`                | (default True)                        | `True`                                   | — (kept; increments not full fields)                                        |


## 9. Diagnostics

| Parameter          | GFS (HEAD~1)                         | RTOFS (HEAD)       | Our change                                                                                                                                                            |
| ------------------ | ------------------------------------ | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NUM_DIAG_COORDS`  | `1`                                  | `1`                | — (kept)                                                                                                                                                              |
| `DIAG_COORD_DEF_Z` | `FILE:@[MOM6_DIAG_COORD_DEF_Z_FILE]` | `WOA09` (built-in) | → `FILE:@[MOM6_DIAG_COORD_DEF_Z_FILE],interfaces=zw` (templatized; 3D z-diagnostics on config-driven grid: 30L forecast / 75L gdas — now REQUIRES the zgrid fix file) |
| `DIAG_MISVAL`      | `@[MOM6_DIAG_MISVAL]`                | `1.0E+20`          | → `@[MOM6_DIAG_MISVAL]` (SOCA keys on this; 0.0 for gdas)                                                                                                             |


## 10. Stochastic physics

| Parameter    | GFS (HEAD~1)         | RTOFS (HEAD) | Our change                                    |
| ------------ | -------------------- | ------------ | --------------------------------------------- |
| `DO_SPPT`    | `@[DO_OCN_SPPT]`     | `False`      | → `@[DO_OCN_SPPT]` (enables ensemble control) |
| `PERT_EPBL`  | `@[PERT_EPBL]`       | `False`      | → `@[PERT_EPBL]`                              |
| `WRITE_GEOM` | `@[MOM6_WRITE_GEOM]` | `0`          | → `@[MOM6_WRITE_GEOM]`                        |


## 11. Fix-file rename summary

Files renamed to canonical MOM6/GFS names (role exactly equivalent):
  - `regional.mom6.nc`                    → `ocean_hgrid.nc`   (horizontal grid)
  - `depth_GLBb0.08_09m11ob2_mom6.nc`     → `ocean_topog.nc`   (bathymetry; provenance kept in comments)
  - `MOM.inc.TSzh.nc` (+ `MOM.inc.UV.nc`) → `mom6_increment.nc` (DA increments; u/v folded in)

Files kept as RTOFS delivered (no exact GFS equivalent):
  - `mom6_vgrid.nc`  — merges GFS `layer_coord.nc` + `hycom1_75_800m.nc`
  - `chl_mom6.nc`    — different dataset/grid/varname than GFS seawifs chlorophyll
  - `woa13_decav_ptemp_monthly_fulldepth_01.nc` / `woa13_decav_s_monthly_fulldepth_01.nc` — WOA13 cold-start climatology
  - `sss_mom6.nc`    — SSS restoring (no GFS counterpart)
  - `basin.nc`       — already the MOM6 default name

Newly required by the DIAG_COORD_DEF_Z templatization (stage under the config.ufs name):
  - `interpolate_zgrid_30L.nc` (forecast RUNs) and/or `oceanda_zgrid_75L.nc` (gdas) — the depth
    levels onto which MOM6 remaps the 3D ocean history (uo/vo/so/temp on `ocean_model_z`).
    MOM6 fatals if the referenced file is absent. Name per config.ufs — NOT `zgrid_30L.nc`.

Staging: `ush/forecast_predet.sh` glob-copies all of `${FIXglobal}/mom6/008/` into `INPUT/`,
so the files placed there must be named to match the references above.
