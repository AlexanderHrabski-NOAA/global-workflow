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

---

## 2. MOM6's coupling mesh is silently supplied by CICE's fix tree, not MOM6's own

**Status:** open (latent hazard, not currently blocking).
**Blocks:** nothing directly today, but it means the `008` MOM6 fix set is incomplete without anyone
having noticed. This was originally filed as a lead on #3; that turned out to be a system bug, so the
mesh-provenance gap stands on its own as a correctness hazard rather than a suspected cause.

### What's actually happening

MOM6's NUOPC cap builds its ESMF coupling geometry from a file named by the `mesh_ocn` attribute,
which global-workflow sets to `MESH_OCN="mesh.mx${OCNRES}.nc"` (`dev/parm/config/gfs/config.ocn.j2:5`).
Nothing stages a file under that name from MOM6's own fix tree — `MOM6_predet()`'s copy of
`${FIXmom}/${OCNRES}/*` (`ush/forecast_predet.sh:729`) has no mesh file in it for `008`, and `FIXcpl`
only supplies the unrelated legacy `grid_spec.nc` mosaic file (`ush/forecast_predet.sh:740`).

The file that actually lands at `DATA/mesh.mx008.nc` comes from **CICE's** predet step instead, purely
because `MESH_ICE` happens to be set to the identical filename:

```bash
# dev/parm/config/gfs/config.base.j2:209
export ICERES="${OCNRES}"
# sorc/ufs_model.fd/tests/default_vars.sh:1700
export MESH_ICE=mesh.mx${OCNRES}.nc
# ush/forecast_predet.sh:693 (CICE_predet)
cpreq "${FIXcice}/${ICERES}/${MESH_ICE}" "${DATA}/"
```

MOM6's cap (`mom_cap.F90:1227`, `ESMF_MeshCreate(filename=trim(cvalue), ...)`) just opens whatever
file happens to already be sitting at that bare relative name in `DATA/` — it has no idea, and no way
to check, whether that file actually came from a MOM6-owned pipeline. This is why nobody noticed the
`008` MOM6 fix set was missing a mesh file at all: the coupled run "just works" (in the sense of
finding an openable file) by accident, borrowing CICE's.

In this experiment that meant MOM6's mesh geometry was validated against
`/gpfs/f6/drsa-precip3/world-shared/role.glopara/fix/cice/20240416/008/mesh.mx008.nc` (dated April
2024), while MOM6's own grid/mask/topog came from a *different*, later fix release,
`role.glopara/fix/mom6/20250128/008/` (dated January 2025). Total element/node counts happened to
still agree exactly when checked (`14,836,500 = 4500×3297` on both sides), so this particular
vintage mismatch was not the cause of #3 — but that agreement was luck, not anything enforced by the
staging code, and there is nothing that would catch it if a future regeneration of either fix tree
drifted.

### What a fix requires

1. Generate a MOM6-owned `mesh.mx008.nc` (e.g. via `sorc/ufs_utils.fd/reg_tests/cpld_gridgen/cpld_gridgen.sh 008`,
   which already has a matching `NI=4500`/`NJ=3297` recipe) built from the *current* `mom6/20250128/008/`
   grid, and stage it explicitly from `FIXmom` in `MOM6_predet()` rather than relying on the wildcard
   copy plus CICE's coincidental filename match.
2. Alternatively/additionally, add a startup check comparing the two components' `mesh.mx${OCNRES}.nc`
   provenance (or at minimum their element counts against each grid's own `NX_GLB×NY_GLB`) so a future
   drift fails loudly instead of silently reading a mismatched file.

---

## 3. `cxil_map`/`-EFAULT` abort in MPI sends at startup — a Gaea C6 system bug, not ours

**Status:** root-caused and worked around. Not a MOM6, CICE, ESMF, or global-workflow defect — the
bug is in the Cray PE / glibc interaction on Gaea C6, diagnosed by ORNL via a GFDL ticket. An HPE fix
is pending with no timeline, so the workaround stays in for the foreseeable future.
**Blocks:** nothing now. Previously blocked the `gdas` (and presumably `gfs`) forecast job at startup,
upstream of everything else in this file.

### Symptom

The job aborts during startup — for us, while a component was building its ESMF coupling geometry
from `mesh.mx008.nc`, but the mesh read is incidental (see root cause):

```
816: libfabric:...::cxi:mr:cxip_do_map():129<warn> c6n1325: cxil_map lni: 130 base: 0x0x14774749a010
     len: 93533504 map_flags: 0xD failure: -14, Bad address
816: MPICH ERROR ... Abort(...) Fatal error in PMPI_Send: ...
     PMPI_Send(163): MPI_Send(buf=..., count=11691688, MPI_DOUBLE, dest=1, tag=13, ...) failed
     MPIDI_OFI_send_normal(372): OFI tagged senddata failed (ofi_send.h:372:...:Bad address)
```

`failure: -14` is `-EFAULT` from the Slingshot/CXI driver's memory-registration call `cxil_map`: the
send buffer could not be pinned for the RDMA transfer.

### Root cause — glibc's mmap threshold, not message size

Per ORNL's analysis ([issue #5104][c]):

- **Not a message-size limit.** MPI/libfabric message-size limits scale close to a node's total
  pinnable memory, and this system's effective limits are in the gigabyte range — far above the
  ~130 MB message that failed.
- Messages larger than ~16 KB use libfabric's **rendezvous** protocol, which must pin the sender's
  buffer so the NIC can RDMA-read from it directly. (Below that, the eager protocol sends inline and
  never registers memory, which is why small messages are unaffected.)
- glibc's allocator backs allocations past a size threshold (~128 KB by default) with a dedicated
  **`mmap` region** rather than the process heap. This buffer landed in an mmap-backed region, and
  `cxil_map` fails to pin that region. Suspected driver-level bug; HPE ticket being filed.

So the trigger is *how the buffer was allocated*, not what it contained or which library sent it. Any
sufficiently large internode send from an mmap-backed allocation can hit this.

### Confirmation that it is system-specific

The MRE was built and run on **Ursa**, including across two nodes, and **does not reproduce** there.
That isolated the failure to Gaea C6's software stack rather than to any model or workflow code.

### Workaround (in place)

```bash
export MALLOC_MMAP_THRESHOLD_=134217728  # 128 MB
```

Raising glibc's threshold keeps these allocations on the heap, where pinning works. Set in
[`env/GAEAC6.env:26`](../../env/GAEAC6.env) alongside the other Gaea C6 fabric settings so it applies
to every step, not just `fcst`. Confirmed to fix both the MRE and the full workflow.

### Superseded workarounds — do not reintroduce

Before the root cause was known, this was misread as an ESMF `ESMCI_Mesh_FileIO.C` scaling limit, on
the theory that its hardcoded `PIO_REARR_SUBSET` rearranger and `num_iotasks = pet_count/pets_per_Ssi`
funnelled the mesh file through too few ranks to keep per-message chunks small. Three mitigations were
committed on that theory (`20af2173`, "work around ESMF mesh read/gen bottleneck") and all three were
reverted in `03f1e53c` once the real cause was found:

| Change | Status |
| --- | --- |
| `USE_MOMMESH=false` in `config.ocn.j2` (routes MOM6's cap through `ESMF_GEOMTYPE_GRID`, skipping the mesh-file read) | reverted — now commented out. Nothing to work around. |
| `tasks_per_node` halved in the `"fcst"\|"efcs"` block of `config.resources` (doubles node count to halve `pets_per_Ssi`) | reverted. Was costing roughly double the nodes for the forecast step. |
| `ntasks_mom6=1920` (gdas) / `ntasks_cice6=1000` | **kept** — but for issue #4's divisibility constraint and for load balance, not for this issue. |

The observation that motivated them — raising `num_iotasks` shrank the failing message and, at the
last data point, made the crash go away — was reproducible, but it is not evidence for the ESMF
theory. Nothing about these buffer sizes is near any libfabric limit, and glibc's mmap threshold is
dynamic (it adapts upward as mmapped blocks are freed), so which allocations end up mmap-backed
depends on allocation history rather than on size alone. That is enough to make a size sweep look
like a trend without any of it bearing on why pinning failed. Reintroducing these buys nothing over
the environment variable and costs nodes.

[c]: https://github.com/NOAA-EMC/global-workflow/issues/5104#issuecomment-5443806264

---

## 4. `ntasks_cice6` must satisfy the `slenderX2` divisibility constraint exactly, or CICE's *own restart read* crashes — not just the block-decomposition problem the constraint was originally documented for

**Status:** understood; a valid value is deployed (`ntasks_cice6=1000` for `gdas`/`gfs`, `c8d6371b`),
but nothing validates the constraint, so the same trap is one config edit away.
**Blocks:** CICE initialization for any `ntasks_cice6` that isn't a valid value (see below). This bites
early — `cice_init` reads CICE's own restart before it builds any coupling geometry.

### Symptom

```
2741: Abort with message NetCDF: Index exceeds dimension bound in file
      .../parallelio-2.6.2/src/clib/pio_darray_int.c at line 1361
...
ufs_model_gfs.x   ice_restart_mp_re...        761  ice_restart.F90
ufs_model_gfs.x   ice_restart_drive...        353  ice_restart_driver.F90
ufs_model_gfs.x   cice_initmod_mp_i...         280  CICE_InitMod.F90
ufs_model_gfs.x   cice_initmod_mp_c...         155  CICE_InitMod.F90
ufs_model_gfs.x   ice_comp_nuopc_mp_...        852  ice_comp_nuopc.F90
```

No `cxil_map`/network involvement at all — this is PIO's own NetCDF bounds-checking
(`check_netcdf2`/`pio_read_darray_nc`) catching a computed index that falls outside a restart
variable's actual dimension. Observed with `ntasks_cice6=375`.

### Root cause

`375` is not a valid CICE `008` PE count: `dev/parm/config/gfs/config.ufs:645-658`'s own comment
documents the constraint (`NX_GLB / (ntasks_cice6/2)` must be an exact integer for the `slenderX2`
decomposition), and `375/2 = 187.5` isn't even an integer, let alone a divisor of `4500` — a more
broken input than the previously-ruled-out `384` (RTOFS's own CICE count), which at least halved
cleanly but still wasn't a divisor. The comment's own text describes the consequence as "the surplus
ranks [getting] zero blocks (`max_blocks=0`)" — an out-of-bounds NetCDF index while reading restart
data into a malformed block layout is a very plausible concrete symptom of exactly that.

This means the constraint isn't just a decomposition nicety for avoiding empty PETs (as originally
documented in issue context) — an invalid value makes CICE **fail outright** at the very first restart
read, before it ever reaches the `ESMF_MeshCreate` call that issue #3 was originally filed against.

### The valid `ntasks_cice6` values are genuinely sparse

`NX_GLB = 4500 = 2² × 3² × 5³` has only 18 divisors, so only 18 values of `ntasks_cice6` satisfy the
constraint at all. Computed directly (`ntasks_cice6 = 2·d` for every divisor `d` of 4500):

```
2, 4, 6, 8, 10, 12, 18, 20, 24, 30, 36, 40, 50, 60, 72, 90, 100, 120,
150, 180, 200, 250, 300, 360, 450, 500, 600, 750, 900, 1000, 1500, 1800, 2250, 3000, 4500, 9000
```

In the range actually useful for this configuration (200–2000): **200, 250, 300, 360, 450, 500, 600,
750, 900, 1000, 1500, 1800.** Note the gaps widen fast — nothing between 1000 and 1500, or between
1500 and 1800 — so picking a value "close to" a target (as happened with both `384` and `375`) is much
more likely to miss than hit. Any future PE-count change for CICE should be chosen from this list
directly rather than by approximation.

### What a fix requires

1. **Done**: `c8d6371b` moved `gdas`/`gfs` to `ntasks_cice6=1000` under `slenderX2`, which satisfies
   the constraint (`4500 / (1000/2) = 9`). `enkfgdas` stays at `250` (`4500 / 125 = 36`), also valid.
2. **Real fix**: either have `config.ufs` validate `ntasks_cice6` against this constraint at
   config-generation time and fail loudly with a clear message (rather than letting an invalid value
   silently reach CICE and surface as an opaque NetCDF error three layers of restart-reading code
   later), or have it snap any requested value to the nearest valid one automatically.

---

## 5. The mediator cold-start mechanism works, but its comment and its implementation live in different files

**Status:** open (discoverability, not a functional defect). **Blocks:** nothing. Recorded because the
split cost real debugging time once, and because the obvious "fix" for it — pinning `read_restart` in
`ufs.configure.s2s.IN` — is a trap that silently disables mediator restarts for the rest of the
experiment.

### The mechanism, end to end

CMEPS decides whether to read its restart from the NUOPC `read_restart` attribute, checked once in
`sorc/ufs_model.fd/CMEPS-interface/CMEPS/mediator/med.F90:2231-2241`, which gates the only call to
`med_phases_restart_read`. That attribute is derived, not configured:

1. `ush/forecast_postdet.sh:1064-1079` (`CMEPS_postdet`) copies the mediator restart to
   `${DATA}/ufs.cpld.cpl.r.nc` and writes `rpointer.cpl` — or, if the file is missing, prints a
   `WARNING` and stages nothing.
2. `ush/parsing_ufs_configure.sh:19-26` then tests for that same staged file and sets
   `cmeps_run_type='continue'` if present, `'startup'` if not.
3. Line 55 renders it as `RUNTYPE`, which the template emits as
   `ALLCOMP_attributes:: start_type`.
4. `sorc/ufs_model.fd/driver/UFSDriver.F90`'s `IsRestart` maps `start_type` to a driver-level
   `read_restart`, and `AddAttributes` (lines 848-875) copies that onto every component, MED included.

So the comment at `forecast_postdet.sh:1073` — `cmeps_run_type is determined based on the availability
of the CMEPS restart file` — is **accurate**. It just describes a step that happens in
`parsing_ufs_configure.sh`, one file away, with no cross-reference in either direction. Grepping for
`cmeps_run_type` from inside `forecast_postdet.sh` finds only the comment, which reads as a description
of code that does not exist.

### Confirmed in the 2026012700 gdas forecast

The chain was verified end to end against `gdas_fcst_seg0.log`:

```
2706: WARNING: CMEPS restart file '.../20260126.210000.ufs.cpld.cpl.r.nc' not found for warm_start='.true.', will initialize!
6262: + parsing_ufs_configure.sh[23][[ -f .../fcst.76361/ufs.cpld.cpl.r.nc ]]
6263: + parsing_ufs_configure.sh[26]local cmeps_run_type=startup
6280: + parsing_ufs_configure.sh[55]local RUNTYPE=startup
```

and, in `mediator.log:559`:

```
(med.F90:DataInitialize) read_restart = .false.
```

Removing or not staging the mediator restart is therefore sufficient on its own to cold-start the
mediator. No override is required, and none should be added.

### The trap: do not pin `read_restart` in `MED_attributes::`

Upstream `sorc/ufs_model.fd/tests/parm/ufs.configure.s2s.IN` deliberately omits `read_restart` from
`MED_attributes::` so that MED inherits the driver's `start_type`-derived value. Adding a literal there:

```
MED_attributes::
      read_restart = .false.
      ...
```

is **sticky**. `AddAttributes` ingests `<compname>_attributes::` *after* copying the driver value
(UFSDriver.F90:877-891), so the literal wins — and because `ALLCOMP_attributes::` carries no
`read_restart` key of its own, nothing later overwrites it. The mediator then cold-starts on every
cycle regardless of `RUNTYPE`, discarding each mediator restart the workflow produces and paying a
cycle of coupling-field spin-up every time. The failure is silent: the only symptom is
`read_restart = .false.` in `mediator.log` on a cycle that should have read a restart.

The same applies to a second `ICE_attributes::` block added to that file. One already exists at line 53;
ESMF resolves a config label to its first occurrence, so the later block is dead config. Even if it were
read, `start_type` could not control CICE's run type — the cap sets `runtype` from it at
`ice_comp_nuopc.F90:471-486`, and `cice_init1` -> `input_data` then re-reads `runtype` from `ice_in`,
which wins (the `#ifndef CESMCOUPLED` guard at `ice_init.F90:584-588` is active because the UFS build
defines only `FORTRANUNDERSCORE` and `coupled`, per `CICE-interface/CMakeLists.txt:86-87`).

### What a fix requires

Documentation only; no behavior needs to change.

1. **Minimal**: extend the comment at `forecast_postdet.sh:1073` to name where the decision is actually
   made, e.g. `cmeps_run_type is set from this file's presence in parsing_ufs_configure.sh:19-26`, and
   add the reciprocal pointer back to `CMEPS_postdet` at `parsing_ufs_configure.sh:19`.
2. **Optional**: note next to the `ufs.configure` templates that `read_restart` is intentionally absent
   from `MED_attributes::` and must stay that way.
