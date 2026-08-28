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

**Status:** open (latent hazard, not currently blocking — see #3, which is what actually surfaces it).
**Blocks:** nothing directly today, but it means the `008` MOM6 fix set is incomplete without anyone
having noticed, and it undermines the workaround for #3.

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

## 3. MOM6/CICE crash (or hang) reading `mesh.mx008.nc` — ESMF's ESMFMESH reader doesn't scale to this mesh size

**Status:** workaround in place and confirmed for both components (commit `20af2173`, "work around ESMF
mesh read/gen bottleneck") — see below. The underlying ESMF bug itself is still open upstream; this is
a mitigation, not a fix, and the mesh-file read is still the eventual failure mode if the workaround's
levers are ever exhausted at a higher resolution or PE count.
**Blocks:** previously blocked the `gdas` (and presumably `gfs`) forecast job at startup for any coupled
run with `use_mommesh=true` (the default) at this resolution; no longer blocks it with the workaround
applied. This was upstream of everything else in this file — the forecast never got far enough to reach
post-processing.

### Symptom

MOM6's NUOPC cap aborts (or, at low enough PE counts for the mesh reader, hangs) shortly after
`======== COMPLETED MOM INITIALIZATION ========`, while building its coupling geometry:

```
816: libfabric:...::cxi:mr:cxip_do_map():129<warn> c6n1325: cxil_map lni: 130 base: 0x0x14774749a010
     len: 93533504 map_flags: 0xD failure: -14, Bad address
816: MPICH ERROR ... Abort(...) Fatal error in PMPI_Send: ...
     PMPI_Send(163): MPI_Send(buf=..., count=11691688, MPI_DOUBLE, dest=1, tag=13, ...) failed
     MPIDI_OFI_send_normal(372): OFI tagged senddata failed (ofi_send.h:372:...:Bad address)
```

`failure: -14` is `-EFAULT` from the Cray Slingshot/CXI driver's memory-registration call
(`cxil_map`) — the send buffer can't be pinned for the RDMA rendezvous transfer
(`FI_CXI_RDZV_THRESHOLD=65536` forces any message this size onto that path). Confirmed via a core dump
(`MPICH_ABORT_ON_ERROR=1` + `gdb`) that this is **not** a MOM6 restart-read issue — the crash is inside
`ESMF_MeshCreate`, reading `mesh.mx008.nc`:

```
#12 pio_read_darray_nc_serial () at .../parallelio-2.6.2/src/clib/pio_darray_int.c:1671
#13 PIOc_read_darray () at .../parallelio-2.6.2/src/clib/pio_darray.c:944
#14 get_nodeCoords_from_ESMFMesh_file(...)
#15 ESMCI_mesh_create_from_ESMFMesh_file(...)
```

### Root cause

`ESMCI_Mesh_FileIO.C` (ESMF's mesh-file reader, external to this repo — `esmf-org/esmf`) hardcodes
both the PIO rearranger and the IO-task count for any file opened via `ESMF_MeshCreate`:

```cpp
// ESMCI_Mesh_FileIO.C:167-179
int pet_count = vm->getPetCount();            // this component's own PET count
int pets_per_Ssi = vm->getSsiMaxPetCount();    // PETs per node (this run: 192)
int num_iotasks = pet_count/pets_per_Ssi;      // integer division
int stride = pets_per_Ssi;
piorc = PIOc_Init_Intracomm(mpi_comm, num_iotasks, stride, 0, PIO_REARR_SUBSET, &pioSystemDesc);
```

`PIO_REARR_SUBSET` funnels the whole file through exactly `num_iotasks` ranks, which then redistribute
to everyone else via raw point-to-point `MPI_Send`. At mx008's scale (`mesh.mx008.nc`: 14,836,500
elements / 14,836,501 nodes), the resulting per-message chunks are large enough to exceed what
`cxil_map` can register. Neither the rearranger choice nor the IO-task count is exposed as a runtime
option anywhere in this call chain — it is not a MOM6, CICE, or global-workflow config problem.

Because `PIOc_Init_Intracomm`'s IO tasks are selected at local ranks `0, stride, 2·stride, ...` within
each component's own communicator, **local rank 0 is always one of them** — which is why this
deterministically hits the same global rank (816 = ocean's local PE 0) every time at a fixed PE layout.

CICE's cap (`CICE-interface/CICE/cicecore/drivers/nuopc/cmeps/ice_comp_nuopc.F90:780`) calls the
identical `ESMF_MeshCreate(..., fileformat=ESMF_FILEFORMAT_ESMFMESH, ...)` on the same file, with no
alternative geometry path (see below) — it is equally exposed, and at typical `008` CICE PET counts is
worse off than MOM6 (fewer PETs → `num_iotasks` rounds down to 1 sooner).

### What's been tried

| Change | Result |
| --- | --- |
| `ulimit -l`/`-c` unlimited (memlock, core size) | Already unlimited on compute nodes by default — not the limiting resource. Ruled out. |
| `ntasks_mom6` 600 → 1920 (matching RTOFS's own `OCN_petlist_bounds` PE count) | `num_iotasks` for MOM6 went 3 → 10; crashing message dropped ~93.5 MB → ~37.6 MB (both `cxil_map`/`-EFAULT`, same rank). Real improvement, still not enough. |
| `USE_MOMMESH=false` (MOM6-only; routes MOM6's cap through `ESMF_GEOMTYPE_GRID` instead of `ESMF_GEOMTYPE_MESH`, building the coupling geometry from MOM6's own in-memory domain decomposition — no file read, no PIO, `mom_cap.F90:1373-1511`) at old PE counts (`ntasks_mom6=600`, `ntasks_cice6=250`) | MOM6 clears its own crash point as expected; job then hung shortly after MOM6 init. Log lost before capture — consistent with, but not confirmed as, CICE's mesh read. |
| `USE_MOMMESH=false` + `ntasks_mom6=1920` + `ntasks_cice6=375` | **MOM6 fully clears — zero `cxil_map` occurrences in the log.** Confirms the `USE_MOMMESH=false` workaround completely. Job still fails, but *before* CICE reaches its own `ESMF_MeshCreate` — CICE's own restart read aborts first, an unrelated bug (fixed as issue #4). CICE's exposure to *this* issue was still untested at this point. |
| `USE_MOMMESH=false` + `ntasks_mom6=1920` + `ntasks_cice6=1000` (valid value, issue #4 fixed) | **CICE now reaches, and fails at, the identical crash** — `ice_comp_nuopc.F90:780` → `ESMF_MeshCreate` → `PIOc_read_darray` → `PMPI_Send` → `cxil_map`/`-EFAULT`, at rank 2736 (CICE's local PE 0, exactly as the `local rank 0 is always an IO task` rule predicts). Confirms CICE is exposed to this issue exactly like MOM6, with no code-level bypass available. |
| Same as above + `tasks_per_node` halved (96 instead of 192 on Gaea C6, for the `"fcst"\|"efcs"` step only) | **CICE's mesh read now clears too — zero `cxil_map` occurrences anywhere in the log.** First run where CICE gets past `ESMF_MeshCreate`. Doubling node count (halving `pets_per_Ssi`) roughly doubles `num_iotasks` for every component for free, without needing sparser-and-sparser `ntasks_cice6` bumps. Job still fails, but one step later, in CICE's *own restart read* — a distinct, new bug (see below the fold; not this issue). |

### Committed workaround (commit `20af2173`, "work around ESMF mesh read/gen bottleneck")

This is what is actually deployed on this branch right now — three files, four lines:

```diff
--- a/dev/parm/config/gfs/config.ocn.j2
+++ b/dev/parm/config/gfs/config.ocn.j2
 export MESH_OCN="mesh.mx${OCNRES}.nc"
+export USE_MOMMESH="false"

--- a/dev/parm/config/gfs/config.resources
+++ b/dev/parm/config/gfs/config.resources
-    tasks_per_node=$(( max_tasks_per_node / threads_per_task ))
+    tasks_per_node=$(( max_tasks_per_node / threads_per_task / 2 ))

--- a/dev/parm/config/gfs/config.ufs
+++ b/dev/parm/config/gfs/config.ufs
       elif [[ "${RUN}" = gdas ]]; then
-        ntasks_mom6=600
+        ntasks_mom6=1920
       ...
       else
-        ntasks_cice6=250
+        ntasks_cice6=1000
       fi
```

- `USE_MOMMESH=false` — permanently removes MOM6 from the exposure entirely (no file read, see table
  above). No downside identified; keep regardless of what else changes.
- `tasks_per_node` halved in the `"fcst"|"efcs"` block of `config.resources:961` — doubles node count
  for the forecast step only (other steps/machines unaffected), which is what actually cleared CICE's
  crash. This is the load-bearing change for CICE; the PE-count bumps below help but did not by
  themselves clear it (see the four-crashes-before-this-one history in the table above).
- `ntasks_mom6=1920` (`gdas` branch only — `enkfgdas`/`gfs` unchanged) and `ntasks_cice6=1000` (the
  `else` branch, i.e. `gdas`/`gfs`; `enkfgdas` stays at its own `250`) — raise `num_iotasks` further and
  are required for issue #4 (valid `slenderX2` divisor) independent of this issue.
- Cost: roughly double the nodes for the `fcst`/`efcs` step, plus the extra MOM6/CICE PETs. Not free,
  but cheaper than waiting on an upstream ESMF fix.

`USE_MOMMESH` is a NUOPC component attribute, not a MOM6 namelist parameter — it must be set as a
shell env var (`ush/parsing_ufs_configure.sh:50`, `local use_mommesh=${USE_MOMMESH:-"true"}`), not via
`#override` in `MOM_input`/`MOM_override`. CICE has no equivalent switch; every path through its cap
reads the mesh file unconditionally.

`ntasks_cice6` is further constrained by CICE's own `slenderX2` block decomposition: `NX_GLB /
(ntasks_cice6/2)` must be an exact integer (`dev/parm/config/gfs/config.ufs:645-658`), which rules out
naively copying RTOFS's own CICE PE count (384 does not satisfy it against `NX_GLB=4500`). See issue
#4 for the full list of valid values.

### Four data points in — the fourth is the first pass

| Component | PETs | `pets_per_Ssi` | `num_iotasks` | Crashing message size | Result |
| --- | --- | --- | --- | --- | --- |
| MOM6 | 600 | 192 | 3 | ~93.5 MB | fail |
| MOM6 | 1920 | 192 | 10 | ~37.6 MB | fail |
| CICE | 1000 | 192 | 5 | ~52.8 MB | fail |
| CICE | 1000 | 96 | 10 | (none — passed) | **pass** |

Message size drops as `num_iotasks` rises, consistent with the mechanism (total transferred volume
appears roughly constant, ~250–380 MB, divided less unevenly as more ranks share the funnel). The
fourth row is the same `ntasks_cice6=1000` as the third — the only change is `pets_per_Ssi` 192 → 96
(from halving `tasks_per_node`), which brought `num_iotasks` from 5 to 10 and cleared the crash. That
roughly halves the expected per-message size again (~52.8 MB → ~mid-20s MB), putting the real safety
threshold for this mesh somewhere between MOM6's failing ~37.6 MB (`num_iotasks=10` at the old node
density) and CICE's passing point here — consistent with, not contradicting, the MOM6 data point, since
MOM6's crashing rank/message and CICE's are different PETs with different local chunk sizes even at the
same nominal `num_iotasks`. Not enough to state an exact byte threshold, but enough to confirm
`tasks_per_node` halving is a genuine, working lever and not a fluke.

### `FI_LOG_LEVEL=debug` and `FI_CXI_ATS=1` — both tried, neither is a fix

`FI_LOG_LEVEL=debug` did not make the `cxil_map`/`cxip_do_map()` failure message itself any more
specific — identical `failure: -14, Bad address` content at every verbosity level, so no numeric
ceiling was recovered this way. It did surface one new fact from the CXI domain's startup negotiation:

```
cxip_iomm_init():345<info> c6n1705: Domain ATS: 0 ODP: 0 HMEM: 0 Scalable: 0
```

Both ATS (Address Translation Services) and ODP (On-Demand Paging) — the two mechanisms that let the
NIC fault in memory dynamically instead of requiring a buffer pinned as one atomic operation — were
off. Retested with `FI_CXI_ATS=1` explicitly set to see whether that was just a default. It was not:

```
cxip_ats_check():279<info> c6n0121: PCIe ATS not supported.
```

Requesting it forces libfabric to actually probe for it, and the hardware/PCIe/IOMMU configuration on
these nodes doesn't support it at all — a confirmed, closed-out negative, not a tunable default.
(That run's failures were also more scattered across ranks, including some outside MOM6/CICE's PET
ranges — consistent with the usual one-real-failure-then-mass-SIGTERM-fallout pattern seen since the
very first crash, not new independent bugs; the underlying `cxil_map` signature is unchanged.)

### What a fix requires

Nothing here is fixable purely within this repo:

1. **Upstream ESMF fix** — the real fix. File against `esmf-org/esmf`: `ESMCI_Mesh_FileIO.C`'s
   `num_iotasks`/`PIO_REARR_SUBSET` choice doesn't scale past ~10M-element ESMFMESH files at typical
   HPC PETs-per-node densities. Concrete reproducer available (this file/line, this mesh size, this
   error).
2. **Interim workaround, MOM6 side**: `USE_MOMMESH=false` — confirmed, no downside identified, keep it
   on regardless of what else changes.
3. **Interim workaround, CICE side**: no code-level bypass exists (unlike MOM6, CICE's cap always reads
   the mesh file) — **but `tasks_per_node` halving is now confirmed to work** (see the fourth data
   point above and the committed-workaround section). This is deployed as of commit `20af2173`. If a
   future resolution/PE-count change reopens this crash, the same two levers apply, in order of
   cost/effectiveness: `tasks_per_node` halving first (doubles `num_iotasks` for every component at
   once, for the price of roughly doubling node count on the `fcst`/`efcs` step), then further
   `ntasks_cice6` increases from the valid list in issue #4 (next: 1500) if more headroom is needed.

---

## 4. `ntasks_cice6` must satisfy the `slenderX2` divisibility constraint exactly, or CICE's *own restart read* crashes — not just the block-decomposition problem the constraint was originally documented for

**Status:** open. **Blocks:** CICE initialization for any `ntasks_cice6` that isn't a valid value (see
below), independent of and *earlier than* issue #3 — CICE's `cice_init` reads its own restart before
it ever gets to building its coupling mesh.

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
read, before it ever reaches the `ESMF_MeshCreate` call issue #3 is about.

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

1. **Immediate**: rerun with a valid value — `1000` is the recommended next test (matches the value
   `config.ufs`'s own comment already names as the vetted fallback for the `gfs` case; gives
   `num_iotasks=1000/192=5` for issue #3's problem once this one clears).
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
