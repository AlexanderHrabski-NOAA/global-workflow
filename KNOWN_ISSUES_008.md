# Known issues — 0.08° MOM6 / CICE6 configuration

Open gaps in the `008` configuration that are understood but not yet fixed. Each entry records what
breaks, where, why, and what a fix requires, so the work can be picked up cold.

Companion to `MOM6_008_fix_files.md` (fix-file reference) and `MOM_input_008_RTOFS_vs_GFS.md`
(parameter diff).

---

## 1. Ocean/ice products are not defined for `mx008`

**Status:** open. **Blocks:** `gfs` post-processing and the native-grid archive tarballs.
**Does not block:** the forecast itself, or any `gdas`-only cycling.

### Symptom

The `ocean_prod` and `ice_prod` jobs abort during task construction with:

```
KeyError: 'mx008'
```

raised from `OceanIceProducts.__init__`, before the job does any work.

### Scope — when this actually bites

`ocean_prod` / `ice_prod` are **`gfs`-only** in cycled mode
(`dev/workflow/applications/gfs_cycled.py:315-321`):

```python
# gfs-specific products
if run == 'gfs':
    if options['do_ocean']:
        task_names[run] += ['ocean_prod']
    if options['do_ice']:
        task_names[run] += ['ice_prod']
```

A `gdas`-only cycling experiment never creates these tasks, so it is unaffected. The issue surfaces
the first time a `gfs` forecast leg is run at `OCNRES=008`. Forecast-only and GEFS/SFS applications
add the same tasks unconditionally when the ocean/ice components are on.

### What the job does

MOM6 and CICE write history on the native **tripole** grid (4500 x 3297 at 0.08° — curvilinear, with
the two northern grid poles displaced over land). `ocnicepost.x` interpolates that onto regular
lat/lon product grids (`0p25` = 1440 x 721, `1p00` = 360 x 181, ...) and optionally writes GRIB2.
The resolution-to-grid bookkeeping lives in `ush/python/pygfs/task/oceanice_products.py`.

### Root cause

Three hardcoded maps in `OceanIceProducts` have no `mx008` key:

| Line | Object | Purpose |
| ---- | ------ | ------- |
| 28 | `VALID_PRODUCT_GRIDS` | which lat/lon grids each model grid may produce |
| 34 | `TRIPOLE_DIMS_MAP` | native source-grid dimensions handed to `ocnicepost.x` |
| 35 | `LATLON_DIMS_MAP` | target dimensions per product grid (only needs a new entry if a new product grid is introduced) |

The model grid key is built at line 56 by formatting `OCNRES` (ocean) or `ICERES` (ice) as three
digits behind `mx`:

```python
model_grid = f"mx{self.task_config[self.COMPONENT_RES_MAP[self.task_config.COMPONENT]]:03d}"
```

which yields `"mx008"`. Line 78 then does a bare dict lookup with no default:

```python
'product_grids': self.VALID_PRODUCT_GRIDS[model_grid]
```

so the missing key raises immediately. `TRIPOLE_DIMS_MAP` is consumed the same way at line 133.

### Downstream cascade

Two archive datasets require this job's output and will fail with `FileNotFoundError` if the products
job did not run:

- `parm/archive/ice_native.yaml.j2` — requires `${COMIN_ICE_NETCDF}/native/*.nc`
- `parm/archive/ocean_native.yaml.j2` — requires the ocean equivalent

Both are live `gfs` tarball types (`dev/workflow/rocoto/gfs_tasks.py:2376,2381`). `ice_6hravg` reads
CICE history straight from the forecast and is resolution-agnostic, so it is unaffected.

### What a fix requires

Four pieces, and they must agree with each other:

1. **`VALID_PRODUCT_GRIDS['mx008']`** — decide the product grids. Mirroring `mx025` with
   `['1p00', '0p25']` is the conservative default. A finer target such as `0p10` would better reflect
   the native resolution but also needs a new `LATLON_DIMS_MAP` entry and its own weights.
2. **`TRIPOLE_DIMS_MAP['mx008'] = [4500, 3297]`** — must match `NX_GLB`/`NY_GLB` in the `008` case of
   `dev/parm/config/gfs/config.ufs`.
3. **ESMF regridding weight files** under `${FIXglobal}/mom6/post/mx008/`, referenced by
   `parm/post/oceanice_products_gfs.yaml:15-22`:
   - `tripole.mx008.Bu.to.Ct.bilinear.nc`
   - `tripole.mx008.Cu.to.Ct.bilinear.nc`
   - `tripole.mx008.Cv.to.Ct.bilinear.nc`
   - `tripole.mx008.Ct.to.rect.<grid>.bilinear.nc` and `.conserve.nc`, one pair per product grid

   These do not exist in the fix set and must be generated. This is the long pole.
4. **An `ocean_levels` branch for `mx008`** in `parm/post/oceanice_products_gfs.yaml:32-36`, which
   currently covers only `mx025`/`mx050`/`mx100` (line 33) and `mx500` (line 35).

### Related: archive templates

`parm/archive/ice_grib2.yaml.j2` and `parm/archive/ocean_grib2.yaml.j2` have no `008` branch either.
They now fail loudly rather than silently rendering an empty `required` list and writing an empty tar
— an unhandled resolution emits a sentinel path that trips the archive task's `FileNotFoundError`
check. The real `008` branches were deliberately left unwritten: the grids listed there must match
`VALID_PRODUCT_GRIDS`, so both should be added in the same change.

Note that neither template is currently reachable — `ice_grib2` and `ocean_grib2` are never added to
`tarball_types` in `dev/workflow/rocoto/gfs_tasks.py`. They are dormant, not active.
