# Code

All runnable MATLAB code is under `src/`. The folders are siblings so that `setup_paths.m` puts every module on the path.

| Folder | Contents |
| --- | --- |
| `src/` | `setup_paths.m` (run first), `run_m2_matched_comparison.m` |
| `src/configs/` | `default_config.m`: every setting, accepts a struct of overrides |
| `src/common/` | Shared channel generation, SINR and sum-rate, the matched experiment runner, save and plot helpers |
| `src/reciprocal/` | Reciprocal BD-RIS pipeline (penalty, Riemannian CGA, final symmetric-unitary projection) and its tests |
| `src/nonreciprocal/` | General BD-RIS baseline (V-frozen and Li joint), its tests, and `add_reciprocal_path.m` |
| `src/tests/` | `test_common_framework.m` |
| `src/experiments/` | Sweep and analysis drivers (added as the sweeps are written) |

## Setup

1. Open MATLAB R2024b.
2. `cd` to `M4_Group9/Code/src`.
3. Run `setup_paths`.

## Run the framework test

```matlab
setup_paths
run('tests/test_common_framework.m')
```

Every line should print PASS. Any FAIL must be recorded in `Results/validation_log.md`.

Expected runtime for a 50-draw point without the joint design is about 12 minutes.

## Notes

- Results folders in `../Results/` are produced by these scripts. Do not edit result files by hand.
- The M2 folders are the original source. They are not modified.
