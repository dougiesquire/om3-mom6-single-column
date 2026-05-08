# om3-mom6-single-column

This repository contains easily-relocatable single-column ACCESS-OM3-MOM6 configurations based on the single-column MOM6 configurations in the
[`ocean_only/single_column` directory of the MOM6-examples repository](https://github.com/NOAA-GFDL/MOM6-examples/tree/dev/gfdl/ocean_only/single_column).

The configurations here have been modified to:
- use [ACCESS-OM3 MOM6](https://github.com/ACCESS-NRI/ACCESS-OM3) (with stub ice and wave components)
- include [WOMBAT biogeochemistry](https://github.com/ACCESS-NRI/GFDL-generic-tracers)
- run with [Payu](https://github.com/payu-org/payu)
- use ocean parameters based on those used in [ACCESS-OM3 25km configurations](https://github.com/ACCESS-NRI/access-om3-configs/tree/dev-MC_25km_jra_ryf%2Bwombatlite)

This default branch uses JRA55-do repeat-year forcing and WOMBATlite biogeochemistry. Other configurations are available in other branches in this repo.

## To run

Clone this repo and run:

```bash
$ module use /g/data/vk83/modules
$ module load payu
$ payu run
```

## Performance

The approximate cost of running this configuration without modification is:
- Compute usage: 0.2 SU/year
- Model throughput: 500 years/day
- Total CPUs: 2

## Changing the domain

The domain comprises 2x2 h-cells spanning 1x1 degree and can be easily relocated. Changing the location of the domain changes the:
- Ocean and BGC initial conditions
- Atmospheric forcing
- Chlorophyll climatology used for SW penetration
- WOMBAT sFe forcing
- Coriolis parameter
- [Optional] Ocean depth

Existing domains can be found in the `./domains` directory. To use an existing domain, simply create a symlink in the base directory to the domain of choice as follows

```bash
$ unlink ./INPUT
$ ln -s ./domains/BATS ./INPUT
```

## Creating a new domain

New domains can be easily created using `./domains/create_domain.sh`

```
$ ./domains/create_domain.sh
Usage: ./domains/create_domain.sh --name=<name> --lon=<lon> --lat=<lat> [--depth=<depth>]
```

E.g. the existing BATS domain was created as follows

```bash
$ ./domains/create_domain.sh --name=BATS --lon=-64.2 --lat=31.7
Created directory: ./domains/BATS
Creating supergrid... Done
Creating ocean mosaic... Done
Creating ESMF mesh... Done
Creating WOMBAT sFe forcing... Done
Creating CHL climatology for SW pen... Done
Creating MOM_override... Done
```

This creates a basic functioning domain that can be further modified as required. For instructions on how to use your new domain, see the previous section.
