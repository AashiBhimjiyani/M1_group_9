# Task 2 — Iteration-Cap Diagnostic (`cap_check`)

## Execution Status
**Executed — Complete.**  
Generated outputs:
- `cap_check_per_draw.csv` (per-draw rates, iterations, delta changes, and Armijo stats)
- `cap_check_summary.csv` (aggregated metrics by group: ordinary, m2_capped, and all)
- `cap_check_results.mat` (complete MATLAB workspace)

## Summary of Results (8,000 vs 40,000 Cap)

| Group | Draws | Rec Rate 8k (bps/Hz) | Gen Rate 8k (bps/Hz) | Gap 8k (bps/Hz) | Gap 8k (%) | Rec Rate 40k (bps/Hz) | Gen Rate 40k (bps/Hz) | Gap 40k (bps/Hz) | Gap 40k (%) | Mean $\Delta R_{\mathrm{rec}}$ | Rec Conv (8k / 40k) | Gen Conv (40k) | Armijo Hits |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Ordinary** | 6 | 7.6822 | 7.7110 | 0.0288 | 0.37% | 7.6822 | 7.7110 | 0.0288 | 0.37% | +0.0000 | 6/6 / 6/6 | 6/6 | 0 |
| **M2-Capped** | 4 | 12.2557 | 12.4595 | 0.2039 | 1.64% | 12.2605 | 12.4595 | 0.1991 | 1.60% | +0.0048 | 0/4 / 3/4 | 4/4 | 0 |
| **All Draws** | 10 | 9.5116 | 9.6104 | 0.0988 | 1.03% | 9.5135 | 9.6104 | 0.0969 | 1.01% | +0.0019 | 6/10 / 9/10 | 10/10 | 0 |

### Key Findings
1. **Convergence at Higher Cap:** 3 of the 4 capped draws successfully reached tolerance $|\Delta F| < 10^{-8}$ before 40k (Draw 21 at 19,303 iters, Draw 26 at 14,053 iters, Draw 31 at 14,704 iters). Draw 34 hit the 40k cap.
2. **Negligible Rate Difference:** Relaxing the cap from 8k to 40k produces a mean rate gain of only $+0.0048$ bps/Hz on the 4 capped draws (and only $+0.0019$ bps/Hz across all 10 draws). The sum-rate gap shifts by less than $0.005$ bps/Hz ($1.64\% \to 1.60\%$).
3. **Armijo Line Search:** Exactly 0 Armijo limit hits across all 10 draws. Armijo backtracking succeeds smoothly without stalling.
4. **Conclusion:** An 8,000-iteration cap introduces negligible rate distortion ($< 0.005$ bps/Hz) while saving tens of thousands of solver iterations.

## Experiment Design
- **Script:** `M4_Group9/Code/src/experiments/run_cap_diagnostic.m`
- **Scenario:** Group-Connected (GC), $R = 32$, $R_g = 4$ ($G = 8$ groups), Rayleigh fading, $N = 2$, $K = 2$, $P_{\max} = 20\text{ dBm}$, $N_0 = -80\text{ dBm}$, $\nu = 1.0$, $\epsilon_{\mathrm{tol}} = 10^{-8}$.
- **Draws (10 total):**
  - **4 M2-capped draws:** `21, 26, 31, 34` (the exact 4 GC draws that hit `8000` iterations in `M4_Group9/Results/anchor_rayleigh_R32_50draws/per_draw.csv`).
  - **6 ordinary draws:** `1, 2, 3, 4, 5, 6` (converged in `191–736` iterations in M2).
- **Comparison:** Reciprocal CGA (`run_cga_optimizer` + `enforce_symmetry_unitarity`) vs. General V-frozen (`general_fixedV_optimizer`) at `p.max_iter = 40000` compared head-to-head against `p.max_iter = 8000`.
- **Recorded Metrics:** Fixed-V sum rate (`rec_rate_8k`, `gen_rate_8k`, `rec_rate_40k`, `gen_rate_40k`), pre-projection & recomputed-V rates, iteration counts, sum-rate gap (`gen - rec`), cap/convergence flags (`converged` vs `hit_cap`), termination reason, and feasibility errors.

## Preliminary Supporting Evidence (Reused from M3 E6 — Not a Replacement)
In M3 Experiment E6 (`M3/results/E6_nu_sweep/E6_per_run.csv`, cap `25,000`, reciprocal-only, 4 draws at $\nu = 1.0$):
- Draw 21 converged at `19,303` iters ($11.6545$ vs M2 $11.6528$ bps/Hz, $\Delta = +0.0016$ bps/Hz).
- Draw 26 converged at `14,053` iters ($12.5498$ vs M2 $12.5459$ bps/Hz, $\Delta = +0.0039$ bps/Hz).
- Draw 31 converged at `14,704` iters ($11.6646$ vs M2 $11.6634$ bps/Hz, $\Delta = +0.0012$ bps/Hz).
- Draw 34 **hit the `25,000` cap** ($13.1724$ vs M2 $13.1606$ bps/Hz, $\Delta = +0.0118$ bps/Hz).

Because Draw 34 still hit `25,000` in M3 E6, the M4 diagnostic tests `p.max_iter = 40000` across both reciprocal and general V-frozen solvers without assuming all runs will converge below `40,000`.

## MATLAB Execution Command
```matlab
cd('M4_Group9/Code/src');
setup_paths;
run('experiments/run_cap_diagnostic.m');
```
Expected outputs in this folder: `cap_check_per_draw.csv`, `cap_check_summary.csv`, `cap_check_results.mat`.

