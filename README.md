# om3-mom6-single-column

This repository contains a modified copy of the single-column MOM6 configurations in the
[`ocean_only/single_column` directory of the MOM6-examples repository](https://github.com/NOAA-GFDL/MOM6-examples/tree/dev/gfdl/ocean_only/single_column).
The configurations here have been modified to:
- use [ACCESS-OM3 MOM6](https://github.com/ACCESS-NRI/ACCESS-OM3) (with stub ice and wave components)
- include [WOMBATlite biogeochemistry](https://github.com/ACCESS-NRI/GFDL-generic-tracers)
- run with [Payu](https://github.com/payu-org/payu)

Note that currently:
- only the EPBL configuration on the BATS domain has been modified
- JRA55do repeat year forcing (RYF) is used

## To run

```bash
$ cd ./EPBL
$ module use /g/data/vk83/modules
$ module load payu
$ payu run
```

## Changing the domain

To set up a new domain, or allow an existing one (example shown for existing BATS domain):

1. Navigate to the input directory for the domain:
  ```bash
  $ cd ./INPUT/BATS/
  ```

2. Generate the cartesian supergrid (the domain size is 2x2 h-cells, with a total extent of 1x1 degree):
  ```bash
  $ module use /g/data/vk83/modules
  $ module load fre-nctools/2024.05-1

  $ make_hgrid --grid_type simple_cartesian_grid --xbnds -64.7,-63.7 --ybnds 31.2,32.2 --simple_dx 23680 --simple_dy 27640 --nlon 4 --nlat 4
  ```

3. Generate the `ocean_mosaic.nc` file:
  ```bash
  $ make_solo_mosaic --num_tiles 1 --dir ./ --mosaic_name ocean_mosaic --tile_file horizontal_grid.nc
  ```

4. Add the domain corner location to `MOM_override`, e.g.:
  ```bash
  $ tail -2 MOM_override
  #override SOUTHLAT = 31.2
  #override WESTLON = -64.7
  ```

5. Generate the mesh from the supergrid:
  ```bash
  $ module purge
  $ module use /g/data/xp65/public/modules
  $ module load conda/analysis3

  $ python3 /g/data/vk83/apps/om3-scripts/mesh_generation/generate_mesh.py --grid-type=mom --grid-filename=./horizontal_grid.nc --mesh-filename=./single-column-ESMFmesh.nc --wrap-lons=True
  ```

6. Symlink to the region-specific files in the INPUT dir:
  ```bash
  $ cd ../
  $ ln -s ./BATS/horizontal_grid.nc
  $ ln -s ./BATS/ocean_mosaic.nc
  $ ln -s ./BATS/single-column-ESMFmesh.nc
  ```

Unfortunately, we cannot use `MOM_input::GRID_CONFIG = "mosiac"` without changing the size
of the domain because in this case MOM6 adds an extra halo point resulting in the error
`"FATAL: MPP_DEFINE_DOMAINS2D: whalo is greather global domain size"` (see 
[here](https://github.com/ACCESS-NRI/MOM6/blob/c664721ebd58c033964b502e7fcdcccd05f02947/src/initialization/MOM_grid_initialize.F90#L207-L208)).
Setting the halo size to 1 gives `"FATAL: MOM_tracer_advect: stencil is wider than the halo"`.
