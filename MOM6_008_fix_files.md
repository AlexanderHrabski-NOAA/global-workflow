# MOM6 `008` (RTOFS GLBb0.08) — fix-file reference: equivalences, contents, and staging notes

Companion to `MOM_input_008_RTOFS_vs_GFS.md` (which tabulates the parameter diff). This file focuses
on the **fix files** the RTOFS 8 km MOM6 config needs: how each maps to the GFS-lineage set, what each
file physically contains, the internal-variable "contracts" they must satisfy, and how the global
workflow stages them.

Scope: present config = RTOFS 008, warm-start cycling. Under warm start (`input_filename='r'`) MOM6
reads its native `MOM.res*.nc` restart and skips the state-init block, so init files matter only for
the cold seed / fallback.


## 1. How staging works (read this first)

There is **no per-file logic** in the workflow for MOM6 fix files. `ush/forecast_predet.sh` does a
single blanket glob-copy:

    cpreq "${FIXglobal}/mom6/${OCNRES}/"* "${DATA}/INPUT/"   # TODO: These need to be explicit

Consequences:
  - Every file in `fix/mom6/008/` is copied into `INPUT/`; nothing is validated or named.
  - The **contract is filename-matching**: the name in `fix/mom6/008/` must exactly equal the name
    referenced in `MOM_input_008.IN`. MOM6 opens files by those names from `INPUTDIR="./INPUT"`.
  - A missing *required* file passes staging silently, then **MOM6 fatals at init**. Extra/stale
    files are copied harmlessly and ignored.
  - `cpreq` = "copy, required" — aborts the job if the copy fails, so an empty/missing fix dir fails
    loudly at staging.

Files that do NOT come through this glob (separate, explicit code paths):
  - `grid_spec.nc`     — coupled mosaic, from `${FIXcpl}/a${CASE}o008/`; has a fatal size-check.
  - `MOM.res*.nc`      — restarts, from the ocean-restart COM (warm-start data), not fix.
  - `mom6_increment.nc`— DA increment, from the ocean-analysis COM, not fix.
  - CICE grid/mask/mesh— from `fix/cice/${ICERES}/`, a separate component.


## 2. Fix-file equivalence map (GFS-lineage <-> RTOFS)

Equivalence column: EXACT = same role AND a canonical shared name → we renamed to it.
ROLE = same job, genuinely different data → keep RTOFS file/name. NONE = no counterpart.

| Role                   | GFS-lineage file                                    | RTOFS file                        | Equivalence | Our action                          |
| ---------------------- | --------------------------------------------------- | --------------------------------- | ----------- | ----------------------------------- |
| Horizontal grid        | `ocean_hgrid.nc`                                    | `regional.mom6.nc`                | EXACT       | renamed -> `ocean_hgrid.nc`         |
| Bathymetry             | `ocean_topog.nc`                                    | `depth_GLBb0.08_09m11ob2_mom6.nc` | EXACT       | renamed -> `ocean_topog.nc`         |
| DA increment (runtime) | `mom6_increment.nc`                                 | `MOM.inc.TSzh.nc` (+`MOM.inc.UV`) | EXACT       | renamed -> `mom6_increment.nc`      |
| Vertical coord (ALE)   | `hycom1_75_800m.nc` + `layer_coord.nc`              | `mom6_vgrid.nc`                   | ROLE        | keep `mom6_vgrid.nc` (see note A)   |
| Chlorophyll            | `seawifs-clim-*.nc`                                 | `chl_mom6.nc`                     | ROLE        | keep `chl_mom6.nc`                  |
| T/S initialization     | `MOM6_IC_TS.nc` (prepared IC)                       | `woa13_decav_ptemp/s_*_01.nc`     | ROLE/NONE   | keep WOA13 (cold-start data source) |
| SSS restoring          | (none)                                              | `sss_mom6.nc`                     | NONE        | keep (new capability)               |
| Basin mask             | (none)                                              | `basin.nc`                        | NONE        | keep (already MOM6 default name)    |
| Diag z-remap grid      | `interpolate_zgrid_30L.nc` / `oceanda_zgrid_75L.nc` | `WOA09` (was built-in)            | ROLE        | templatized to config file (note B) |
| Topo edits             | `All_edits.nc`                                      | (none)                            | NONE        | not used (`TOPO_EDITS_FILE=""`)     |
| Channel widths         | `MOM_channels_global_025`                           | (none)                            | NONE        | not used (`CHANNEL_CONFIG="none"`)  |
| Tidal amplitude        | `tidal_amplitude.v20140616.nc`                      | (none)                            | NONE        | not used (tides off)                |
| Geothermal flux        | `geothermal_davies2013_v1.nc`                       | (none)                            | NONE        | not used (`DO_GEOTHERMAL=False`)    |
| River runoff           | `runoff.daitren.clim.*.nc`                          | (none)                            | NONE        | not used                            |


## 3. Internal-variable "contracts"

A fix filename is only half the contract; each `MOM_input` reference also names the *variable(s)* it
expects to find inside the file. Wrong variable name => MOM6 fatals on read, even if the file exists.
Confirm these with `ncdump -h` on the staged files.

| File                | MOM_input reference                                      | Required internal variable(s)              |
| ------------------- | -------------------------------------------------------- | ------------------------------------------ |
| `ocean_hgrid.nc`    | `GRID_FILE`                                              | mosaic supergrid vars (x,y,dx,dy,angle_dx) |
| `ocean_topog.nc`    | `TOPO_FILE`, `TOPO_VARNAME="depth"`                      | `depth`                                    |
| `mom6_vgrid.nc`     | `COORD_FILE`+`COORD_VAR="Layer"`; `HYBRID:...,sigma2,dz` | `Layer`, `sigma2`, `dz`                    |
| `chl_mom6.nc`       | `CHL_FILE`, `CHL_VARNAME="chl_a"`                        | `chl_a`                                    |
| `sss_mom6.nc`       | `SALT_RESTORE_FILE`, `SALT_RESTORE_VARIABLE="SSS"`       | `SSS`                                      |
| `woa13_*_ptemp_*`   | `TEMP_Z_INIT_FILE`, `Z_INIT_FILE_PTEMP_VAR="ptemp_an"`   | `ptemp_an`                                 |
| `woa13_*_s_*`       | `SALT_Z_INIT_FILE`, `Z_INIT_FILE_SALT_VAR="s_an"`        | `s_an`                                     |
| `*zgrid_*L.nc`      | `DIAG_COORD_DEF_Z="FILE:...,interfaces=zw"`              | `zw` (interface depths)                    |
| `mom6_increment.nc` | `ODA_*` (via `@[ODA_*]`)                                 | `Temp`,`Salt`,`h`,`u`,`v`                  |


## 4. Needed for the present (warm-start) config

| File                       | When MOM6 reads it               | Verdict for present config        |
| -------------------------- | -------------------------------- | --------------------------------- |
| `ocean_hgrid.nc`           | every run                        | REQUIRED                          |
| `ocean_topog.nc`           | every run                        | REQUIRED                          |
| `mom6_vgrid.nc`            | every run                        | REQUIRED                          |
| `chl_mom6.nc`              | every run (`CHL_FROM_FILE=True`) | REQUIRED                          |
| `sss_mom6.nc`              | every run (`RESTORE_SALINITY`)   | REQUIRED                          |
| `interpolate_zgrid_30L.nc` | forecast RUNs (diag remap)       | REQUIRED (added by note B)        |
| `oceanda_zgrid_75L.nc`     | gdas RUN (diag remap)            | REQUIRED for DA cycle (note B)    |
| `grid_spec.nc` (FIXcpl)    | every coupled run                | REQUIRED (fatal size-check)       |
| CICE grid/mask/mesh        | every coupled run                | REQUIRED                          |
| `woa13_decav_ptemp/s_*`    | cold start only (`='n'`)         | Seed/fallback only; not read warm |
| `basin.nc`                 | only if `MASK_SRESTORE*` = True  | Staged but INERT (mask flags off) |
| GFS-only (tidal/geo/etc.)  | never (features off)             | Not needed                        |


## Note A — `mom6_vgrid.nc` vs `hycom1_75_800m.nc` (vertical coordinate)

`hycom1_75_800m.nc` and `mom6_vgrid.nc` are the same *kind* of file — both define the HYCOM1 hybrid
vertical coordinate (the `sigma2` target isopycnal densities the ALE coordinate relaxes toward).
`hycom1_75_800m.nc` is the 75-layer version; `mom6_vgrid.nc` is the 41-layer RTOFS version. That is a
ROLE equivalence, not a swap:

  - GFS splits the job across two files: `hycom1_75_800m.nc` (sigma2 for the ALE HYBRID) and
    `layer_coord.nc` (`Layer` densities for `COORD_FILE`), with `dz` supplied functionally
    (`FNC1:2,4000,4.5,.01`).
  - RTOFS consolidates all three into `mom6_vgrid.nc`: it is the `COORD_FILE` (`Layer`), the ALE
    HYBRID source (`sigma2`), AND supplies `dz` read from inside the file (`...,sigma2,dz`).

    mom6_vgrid.nc  ~  hycom1_75_800m.nc (sigma2)  +  layer_coord.nc (Layer)  +  in-file dz

How to use this:
  1. Validate: `mom6_vgrid.nc` MUST contain `Layer`, `sigma2`, and `dz` (section 3). Use
     `hycom1_75_800m.nc` as the known-good reference for what `sigma2` should look like (41 vs 75
     entries), and confirm `mom6_vgrid.nc` additionally carries `dz` and `Layer`.
  2. Regenerate if needed: build `mom6_vgrid.nc` with the same HYCOM-1 hybrid-coordinate tooling that
     produced `hycom1_75_800m.nc`, targeted at 41 layers with the RTOFS profile and written to include
     `dz`/`Layer`.
  3. Do NOT rename to `hycom1_75_800m.nc`: that name hardcodes 75 layers and an 800 m deep-layer
     target; RTOFS is 41 layers with `MAX_LAYER_THICKNESS = 41*750.0` (750 m). Same role, different
     data — keep the RTOFS name.


## Note B — Diagnostic z-remap grid (`DIAG_COORD_DEF_Z`)

The MOM6 diag_table requests 3D ocean output on a remapped depth coordinate
(`"ocean_model_z"` for `uo/vo/so/temp`). `DIAG_COORDS = "z Z ZSTAR"` ties that `z` module to the
parameter `DIAG_COORD_DEF_Z`, which sets the depth levels.

As delivered, RTOFS used the built-in `"WOA09"` levels (no file). We templatized it to:

    DIAG_COORD_DEF_Z = "FILE:@[MOM6_DIAG_COORD_DEF_Z_FILE],interfaces=zw"

which `config.ufs` fills with `interpolate_zgrid_30L.nc` (forecast RUNs) or `oceanda_zgrid_75L.nc`
(gdas). This aligns the 3D ocean history with what the products/verification and the marine DA expect
(the `oceanda_` grid is the DA's 75-level target).

Syntax of the string:
  - `FILE:`            MOM6 directive: read the levels from a netCDF file.
  - `@[...]`           atparse placeholder; replaced with the filename before MOM6 sees it.
  - `,interfaces=zw`   read interface depths from the variable `zw` (N+1 interfaces for N layers).
                       (Alternative form `,dz` would read a thickness variable instead.)

Implications:
  - This change makes the zgrid file REQUIRED — MOM6 fatals if it is absent (WOA09 needed nothing).
  - Stage under the config.ufs names: `interpolate_zgrid_30L.nc` and `oceanda_zgrid_75L.nc` —
    NOT the shorthand `zgrid_30L.nc`. No copy/rename step is needed.
  - The `zw` variable-name contract applies (section 3): the staged files must contain `zw`.


## Note C — General principle: role vs exact equivalence

When a GFS file and an RTOFS file play the same role, adopt the canonical GFS name ONLY when the data
is truly interchangeable (grid, bathymetry, DA increment — EXACT). When the role matches but the data
is RTOFS-specific (vertical coordinate, chlorophyll, init climatology, restoring), keep the RTOFS
file and name — renaming would either hide a real difference or force a wrong-grid/wrong-vintage file
into place. The filename is a label the glob-staging matches on; it must agree with `MOM_input`, but
it should not imply an equivalence the contents don't have.


## Note D — Cold start vs warm start (init files)

Warm-start cycling (`input_filename='r'`) reads `MOM.res*.nc` and bypasses the whole state-init
block, so `woa13_*` are NOT read during continuation. They matter only to seed cycle 1 (or as a
fallback) when `INIT_LAYERS_FROM_Z_FILE=True` and `input_filename='n'`. Stage them, but don't expect
them to participate in a warm run. There is no GFS operational reference for cold-starting directly
from WOA climatology; the GFS parallel is `INIT_FROM_Z` pointed at a prepared (chgres'd) IC.
