# Auxillary fix files for high resolution MOM6 CICE6 support

This file catalogs the source of the auxilary fix files included in this directory. All files are sourced
from locations on Ursa. If a directory includes a subdirectory also listed, the source of the subdirectory
supercedes the source of the parent. Some files are linked instead of copied when the source is a global resource.

| file | source | source creation date | (C)opied or (L)inked |
| ---- | ----- | ---- | ---- |
| `C384/` | `/scratch4/NCEPDEV/stmp/Brian.Curtis/my_grids/C384.mx008/` | `20260715` | `C` |
| `C384/ocean_mask` | `/scratch4/NCEPDEV/stmp/Santha.Akella/ufs_utils/reg-tests/cpld_gridgen/rt_896276/008` | `20260630` | `C` |
| `MOM/interpolate_zgrid_30L.nc` | `/scratch3/NCEPDEV/global/role.glopara/fix/mom6/20250128/025/interpolate_zgrid_30L.nc` | `20250128` | `L` |
| `MOM/oceanda_zgrid_75L.nc` | `/scratch3/NCEPDEV/global/role.glopara/fix/mom6/20250128/025/oceanda_zgrid_75L.nc`  | `20250128` | `L` |
| `MOM/regional.mom6.nc` | `/scratch3/NCEPDEV/global/role.glopara/fix/mom6/20250128/008/ocean_hgrid.nc`  | `?` | `L` |