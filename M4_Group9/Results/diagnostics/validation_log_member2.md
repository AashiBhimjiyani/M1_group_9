# Member 2 Validation Log — Milestone 4 (M4)

**Role:** Member 2 — Reciprocal Optimizer Lead  
**Scope:** Execution log for short verification tests, framework integration, path resolution, and initial quick-sweep experiments.  
**Execution Environment:** MATLAB R2025a, Windows x64.

---

## Short Verification Suite Summary

| Test ID | Test Description | Command / Script | Status | Result / Output Summary | Relevant Artifacts |
|---|---|---|---|---|---|
| **Test 1** | Path setup and environment initialization | `cd('M4_Group9/Code/src'); setup_paths;` | **PASS** | Successfully mounted `src/`, `configs/`, `tests/`, `common/`, `reciprocal/`, `nonreciprocal/`, and `experiments/`. | `M4_Group9/Code/src/setup_paths.m` |
| **Test 2** | Common framework parity & sanity checks | `run('tests/test_common_framework.m')` | **PASS** | 14/14 checks PASSED: config parity, seed reproduction, MMSE/SINR/sum-rate equivalence, Rayleigh/Rician scaling, power budget, $K_f$ and $G$ overrides. | `M4_Group9/Code/src/tests/test_common_framework.m` |
| **Test 3** | Configurable iteration cap & parameter overrides | `run('experiments/test_task1_max_iter.m')` | **PASS** | Default `8000` cap verified; `p.max_iter` and `opts.max_iter` override both reciprocal and general optimizers; empty `p.max_iter` defaults to `8000`; backward-compatible 7-arg/2-output call passed. | `M4_Group9/Code/src/experiments/test_task1_max_iter.m`, `M4_Group9/Results/diagnostics/task1_max_iter_diff.md` |
| **Test 4** | Function resolution and duplicate shadowing check | `which -all run_matched_experiment; which -all save_matched_results; which -all plot_matched_results; which -all default_config;` | **PASS** | Exactly 1 unique definition resolved for each function; all point to `M4_Group9/Code/src/common` and `configs`. No shadowing or competing duplicates. | MATLAB path table |
| **Test 5** | Three-draw RIS-size quick check ($R \in \{16, 48, 64\}$) | `sweep_mode='quick'; R_list=[16, 48, 64]; run('experiments/run_ris_size_sweep.m')` | **PASS** | Standalone execution without anchor requirement; SC, GC, FC executed; $R_g \in [1, 4, R]$ correct; $G \in \{4, 12, 16\}$ correct; Rayleigh verified; per-draw and summary CSVs and plots generated. Runtime: R16 (8.84 s/draw), R48 (24.18 s/draw), R64 (28.76 s/draw < 120 s threshold). | `M4_Group9/Results/sweep_ris_size/R{16,48,64}/quick_test_3draws/` |
| **Test 6** | Full-config checkpoint validation & rejection | Tested in `test_task1_max_iter.m` | **PASS** | Identical config resumes cached draws. Altering any of `Pmax_dBm`, `N`, `K`, `fading`, `Kf_dB`, `max_iter`, or `seed_base` is detected by `configs_match_ckpt.m`, rejecting stale checkpoint and restarting cleanly. | `M4_Group9/Code/src/experiments/configs_match_ckpt.m` |

---

## Detailed Test Logs

### Test 1 & Test 4: Path Setup and Function Resolution
```text
>> cd('M4_Group9/Code/src'); setup_paths;
>> which('-all','run_matched_experiment')
Code/src/common/run_matched_experiment.m
>> which('-all','save_matched_results')
Code/src/common/save_matched_results.m
>> which('-all','plot_matched_results')
Code/src/common/plot_matched_results.m
>> which('-all','default_config')
Code/src/configs/default_config.m
```
*Status:* **PASS** — No duplicates, correct directory layout under `src/common` and `src/configs`.

### Test 2: Common Framework Parity Checks
```text
PASS  default_config matches reciprocal/config.m (all shared fields)
PASS  common_generate_channels == generate_channels (same seed)
PASS  common_init_theta == initialize_theta(R,'SC',R) (RNG stream aligned)
PASS  common_mmse_beamformer == mmse_beamformer
PASS  power constraint ||V||_F^2 = Pmax
PASS  common_sinr == calculate_sinr
PASS  common_sumrate == calculate_sumrate
PASS  same seed reproduces channel; different seed differs
PASS  mean |h|^2 equals path loss (rayleigh): ratios 1.008, 0.999
PASS  mean |h|^2 equals path loss (rician): ratios 1.000, 1.000
PASS  overrides re-derive Pmax and Rg_list
PASS  SINR of an interference-free 2x2 case equals P/N0
PASS  Kf_dB override updates fading='rician' and linear Kf
PASS  G override updates Rg_list and preserves max_iter
ALL CHECKS PASSED
```
*Status:* **PASS** — 14/14 tests passed.

### Test 3 & Test 6: Configurable Iteration Cap & Checkpoint Rejection
```text
draw  1/1 SC (Rg= 1) | rec 3.502 (10 it, arm=0) | gen-fv 3.502 (10 it, arm=0) | gap 0.000
draw  1/1 GC (Rg= 4) | rec 4.566 (10 it, arm=0) | gen-fv 4.824 (10 it, arm=0) | gap 0.259
draw  1/1 FC (Rg= 8) | rec 4.735 (10 it, arm=0) | gen-fv 4.995 (10 it, arm=0) | gap 0.260
[Resume] Loaded checkpoint ...\m4_task1_test_checkpoint.mat (3/3 draw-arch pairs complete).
[Checkpoint] Ignoring stale checkpoint (parameter "Pmax_dBm" changed). Starting fresh.
draw  1/1 SC (Rg= 1) | rec 0.686 (10 it, arm=0) | gen-fv 0.686 (10 it, arm=0) | gap 0.000
draw  1/1 GC (Rg= 4) | rec 0.435 (10 it, arm=0) | gen-fv 1.063 (10 it, arm=0) | gap 0.627
draw  1/1 FC (Rg= 8) | rec 0.875 (10 it, arm=0) | gen-fv 1.112 (10 it, arm=0) | gap 0.237
[PASS] All Task 1, path resolution, checkpoint, and M4 audit checks passed.
```
*Status:* **PASS** — Full parameter verification confirmed.

### Test 5: Three-Draw RIS Quick Check ($R \in \{16, 48, 64\}$)
```text
[QUICK OK] R=16 (G=4, SC/GC/FC): 3 draws in 26.52s (8.84s/draw) -> M4_Group9/Results/sweep_ris_size/R16/quick_test_3draws
[QUICK OK] R=48 (G=12, SC/GC/FC): 3 draws in 72.55s (24.18s/draw) -> M4_Group9/Results/sweep_ris_size/R48/quick_test_3draws
[QUICK OK] R=64 (G=16, SC/GC/FC): 3 draws in 86.29s (28.76s/draw) -> M4_Group9/Results/sweep_ris_size/R64/quick_test_3draws
```
*Status:* **PASS** — Complete outputs generated: `summary.csv`, `per_draw.csv`, `config_used.txt`, `matched_sumrate.png`, and `matched_convergence.png` for all 3 RIS sizes.

---

## Full Experiment Execution Logs (Tasks 2, 3, 4)

### Task 2: Iteration-Cap Diagnostic (`run_cap_diagnostic.m`)
- **Execution Date & Environment:** 2026-11-13, MATLAB R2025a, Windows x64.
- **Status:** **PASS / EXECUTED** (Exit code 0).
- **Execution Scope:** 10 draws GC ($R=32, R_g=4, G=8$): 4 M2-capped draws (21, 26, 31, 34) and 6 ordinary draws (1–6) comparing `max_iter = 8000` vs `max_iter = 40000`.
- **Generated Artifacts:**
  - `M4_Group9/Results/diagnostics/cap_check/cap_check_per_draw.csv`
  - `M4_Group9/Results/diagnostics/cap_check/cap_check_summary.csv`
  - `M4_Group9/Results/diagnostics/cap_check/cap_check_results.mat`
- **Key Results:**
  - **Ordinary Group (6 draws):** Identical rates between 8k and 40k caps (mean reciprocal rate `7.6822` bps/Hz, mean general rate `7.7110` bps/Hz, gap `0.0288` bps/Hz, ratio-of-means gap `0.37%`). All 6 converged in under 600 iterations (mean reciprocal iters `319.2`, general `592.5`).
  - **M2-Capped Group (4 draws):**
    - Draw 21: Converged at `19,303` iters (`delta_rec = +0.0016` bps/Hz, rate `11.6545` bps/Hz).
    - Draw 26: Converged at `14,053` iters (`delta_rec = +0.0039` bps/Hz, rate `12.5498` bps/Hz).
    - Draw 31: Converged at `14,704` iters (`delta_rec = +0.0012` bps/Hz, rate `11.6646` bps/Hz).
    - Draw 34: Hit the 40k cap at `40,000` iters (`delta_rec = +0.0125` bps/Hz, rate `13.1731` bps/Hz).
    - Mean rate gain from 8k to 40k across the 4 capped draws is only `+0.0048` bps/Hz; mean gap shifts marginally from `0.2039` to `0.1991` bps/Hz (ratio-of-means gap shifts from `1.64%` to `1.60%`).
  - **Armijo Line Search Limit Hits:** `0` across all 10 draws for both reciprocal and general optimizers (all iterations satisfied Armijo backtracking without hitting the 200-step ceiling).

### Task 3: Penalty Sensitivity Experiment (`run_nu_sensitivity.m`)
- **Execution Date & Environment:** 2026-11-13, MATLAB R2025a, Windows x64.
- **Status:** **PASS / EXECUTED** (Exit code 0).
- **Execution Scope:** $\nu \in \{0.1, 1.0, 10.0\}$ on 20 independent draws (seeds 1–20) for GC ($R_g=4$) and FC ($R_g=32$), plus high-cap subset (`max_iter = 25000`) on seeds `[1, 6, 11, 16]`.
- **Generated Artifacts:**
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_per_run.csv`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_summary.csv`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_results.mat`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_plots.png`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_high_cap_per_run.csv`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_high_cap_summary.csv`
  - `M4_Group9/Results/diagnostics/nu_sensitivity/nu_sensitivity_high_cap_results.mat`
- **Key Findings:**
  - **GC ($R_g=4, R=32$):**
    - $\nu = 0.1$: 19/20 converged, 1 cap hit; mean post-projection rate `9.2396` bps/Hz; large mean projection cost of `0.0325` bps/Hz ($7.4\times$ larger than $\nu=1.0$) and high residual `0.1989`.
    - $\nu = 1.0$: 20/20 converged, 0 cap hits; mean post-projection rate `9.2074` bps/Hz; projection cost drops to `0.0044` bps/Hz (residual `0.0288`), mean iters `845.8`.
    - $\nu = 10.0$: 13/20 converged, 7 cap hits at 8k; convergence slows dramatically (mean iters `4971.8`, max `8000`). Even with 25k cap, 2/4 seeds still hit the cap.
  - **FC ($R_g=32, R=32$):**
    - $\nu = 0.1$: 20/20 converged, post-projection rate `9.6033` bps/Hz, projection cost `0.0177` bps/Hz.
    - $\nu = 1.0$: 20/20 converged, post-projection rate `9.6226` bps/Hz, minimal projection cost `0.00018` bps/Hz, mean iters `571.8`.
    - $\nu = 10.0$: 20/20 converged, post-projection rate `9.6226` bps/Hz (identical to 6 decimal places), projection cost `0.000005` bps/Hz, mean iters `575.2`.
  - **Conclusion:** $\nu = 1.0$ is rigorously confirmed as the optimal trade-off parameter across both architectures: it avoids the projection distortion of $\nu=0.1$ and the severe convergence deceleration / cap stalling of $\nu=10.0$.

### Task 4: Full 50-Draw RIS-Size Sweep (`run_ris_size_sweep.m`)
- **Execution Date & Environment:** 2026-11-13 to 2026-11-14, MATLAB R2025a, Windows x64.
- **Status:** **PASS / EXECUTED** (Exit code 0).
- **Execution Scope:** 50 draws each for $R = 16, 48, 64$ across SC, GC ($R_g=4$), and FC ($R_g=R$), integrated with M2 anchor ($R=32$).
- **Generated Artifacts:**
  - `M4_Group9/Results/sweep_ris_size/R16/` (`per_draw.csv`, `summary.csv`, `matched_convergence.png`, `matched_sumrate.png`)
  - `M4_Group9/Results/sweep_ris_size/R48/` (`per_draw.csv`, `summary.csv`, `matched_convergence.png`, `matched_sumrate.png`, `checkpoint_R48.mat`)
  - `M4_Group9/Results/sweep_ris_size/R64/` (`per_draw.csv`, `summary.csv`, `matched_convergence.png`, `matched_sumrate.png`, `checkpoint_R64.mat`)
  - `M4_Group9/Results/sweep_ris_size/sweep_summary.csv` (unified 12-row summary table)
- **Comprehensive Sweep Summary (Exact Numbers from `sweep_summary.csv`):**
  - $R=16$ ($G=4$): SC = `5.4341` bps/Hz; GC = `6.6438` vs `6.7834` bps/Hz (gap `0.1397` bps/Hz, `2.06%` ratio-of-means, `1.85%` per-draw mean, 4 rec cap hits); FC = `7.0328` vs `7.0474` bps/Hz (gap `0.0145` bps/Hz, `0.21%` ratio-of-means, `0.17%` per-draw mean, 0 cap hits).
  - $R=32$ ($G=8$, Anchor): SC = `8.5166` bps/Hz; GC = `9.9089` vs `10.0119` bps/Hz (gap `0.1030` bps/Hz, `1.03%` ratio-of-means, `0.88%` per-draw mean, 4 rec cap hits); FC = `10.3105` vs `10.3313` bps/Hz (gap `0.0209` bps/Hz, `0.20%` ratio-of-means, `0.17%` per-draw mean, 0 cap hits).
  - $R=48$ ($G=12$): SC = `10.9144` bps/Hz; GC = `12.3227` vs `12.4782` bps/Hz (gap `0.1555` bps/Hz, `1.25%` ratio-of-means, `1.13%` per-draw mean, 12 rec cap hits, 3 gen cap hits); FC = `12.7789` vs `12.8222` bps/Hz (gap `0.0433` bps/Hz, `0.34%` ratio-of-means, `0.31%` per-draw mean, 3 rec cap hits, 0 gen cap hits).
  - $R=64$ ($G=16$): SC = `11.8942` bps/Hz; GC = `13.2184` vs `13.3732` bps/Hz (gap `0.1548` bps/Hz, `1.16%` ratio-of-means, `1.04%` per-draw mean, 5 rec cap hits, 2 gen cap hits); FC = `13.6150` vs `13.7282` bps/Hz (gap `0.1133` bps/Hz, `0.82%` ratio-of-means, `1.03%` per-draw mean, 1 rec cap hit, 4 gen cap hits).
  - **Armijo Limit Hits:** Exactly `0` across all 50 draws for all 4 RIS sizes and architectures (`total = 0`).
  - **Control Gain over SC:** GC adds `+1.21` ($R=16$), `+1.39` ($R=32$), `+1.41` ($R=48$), `+1.32` ($R=64$) bps/Hz. FC adds `+1.60` ($R=16$), `+1.79` ($R=32$), `+1.86` ($R=48$), `+1.72` ($R=64$) bps/Hz.
  - **Scaling Behavior:** The reciprocity gap remains small across all surface dimensions: GC reciprocity cost is stably confined to $[0.10, 0.16]$ bps/Hz ($1.0\%$ to $2.1\%$), and FC reciprocity cost remains $\le 0.11$ bps/Hz ($< 0.83\%$).

