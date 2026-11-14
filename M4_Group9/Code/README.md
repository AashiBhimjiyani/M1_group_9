# M4_Group9 Code Documentation

## Directory Layout
- `src/setup_paths.m` — Single entry-point MATLAB path setup (adapted from Member 4's M2 framework).
- `src/configs/default_config.m` — Single source of truth for simulation parameters (Member 4 M2 framework + `max_iter`, synchronized `fading`/`Kf_dB`, and dynamic `G -> Rg_list` mapping).
- `src/common/` — Member 4's shared channel generation, initialization, MMSE beamformer, path loss, SINR, sum-rate functions (`common_*`), and matched experiment runner/saver/plotter (`run_matched_experiment.m`, `save_matched_results.m`, `plot_matched_results.m`).
- `src/reciprocal/` — Member 2's reciprocal BD-RIS Riemannian CGA optimizer (`run_cga_optimizer.m`), FP surrogate (`fp_variables.m`, `objective.m`, `gradient_theta.m`), Stiefel geometry (`tangent_projection.m`, `retraction.m`, `armijo_search.m`, `enforce_symmetry_unitarity.m`), M3 stretch joint solver (`reciprocal_joint_optimizer.m`), and validation tests.
- `src/nonreciprocal/` — Member 3's general (non-reciprocal) fixed-V matched baseline (`general_fixedV_optimizer.m`) and Li et al. joint baseline (`li_joint_optimizer.m`).
- `src/experiments/` — Shared M4 experiment helpers (`resolve_anchor_path.m`, `configs_match_ckpt.m`) plus Member 2 M4 drivers (`test_task1_max_iter.m`, `run_cap_diagnostic.m`, `run_nu_sensitivity.m`, `run_ris_size_sweep.m`).
- `src/tests/` — Member 4's `test_common_framework.m` parity and audit check suite.

## Dependencies
- MATLAB (tested target: R2025a); no third-party toolboxes required.
- Call `setup_paths()` from `M4_Group9/Code/src` (all M4 experiment and test scripts do this automatically via `mfilename('fullpath')`).
- Benchmark M2 anchor files (`per_draw.csv`, `summary.csv`) are resolved via `resolve_anchor_path.m` (Priority 1: `M4_Group9/Results/anchor_rayleigh_R32_50draws/`; Priority 2: read-only `Results/matched_rayleigh_R32_50draws/`) and validated explicitly before use. Quick 3-draw tests run standalone without requiring anchor files.

## Exact MATLAB Commands

### Short Verification Tests (Run First)
```matlab
cd('M4_Group9/Code/src');
setup_paths;
run('tests/test_common_framework.m');
run('experiments/test_task1_max_iter.m');
run('reciprocal/test_blocks.m');
run('reciprocal/test_gradient_fd.m');
```

### Full Validation Suite & Quick Check
```matlab
cd('M4_Group9/Code/src');
setup_paths;
run('reciprocal/run_all_validation_tests.m');
sweep_mode = 'quick'; R_list = [16, 48, 64];
run('experiments/run_ris_size_sweep.m');
```

### Long M4 Experiments
1. **Task 2 — Cap Diagnostic (GC, $R_g=4$, 10 draws, `8000` vs `40000`):**
   ```matlab
   cd('M4_Group9/Code/src'); setup_paths;
   run('experiments/run_cap_diagnostic.m');
   ```
   Outputs: `M4_Group9/Results/diagnostics/cap_check/{cap_check_per_draw.csv, cap_check_summary.csv, cap_check_results.mat}` (with incremental per-draw CSV/checkpoint saves).

2. **Task 3 — Penalty Sensitivity ($\nu \in \{0.1, 1, 10\}$, GC & FC, 20 draws + higher-cap subset):**
   ```matlab
   cd('M4_Group9/Code/src'); setup_paths;
   run('experiments/run_nu_sensitivity.m');
   ```
   Outputs: `M4_Group9/Results/diagnostics/nu_sensitivity/{nu_sensitivity_per_run.csv, nu_sensitivity_summary.csv, nu_sensitivity_results.mat, nu_sensitivity_plots.png, nu_sensitivity_high_cap_per_run.csv, nu_sensitivity_high_cap_summary.csv, nu_sensitivity_high_cap_results.mat}`.

3. **Task 4 — Full RIS-Size Sweep ($R \in \{16, 48, 64\}$, $R_g=4$, $G \in \{4, 12, 16\}$, SC/GC/FC):**
   ```matlab
   Outputs: `M4_Group9/Results/sweep_ris_size/R{16,48,64}/`.
   sweep_mode = 'full'; R_list = [16, 48, 64]; % set nd_R64 = 30 if R=64 is too slow
   run('experiments/run_ris_size_sweep.m');
   ```
   Outputs: `M4_Group9/Results/sweep_ris_size/R{16,48,64}/` and merged `M4_Group9/Results/sweep_ris_size/sweep_summary.csv` (with M2 $R=32$ anchor).
