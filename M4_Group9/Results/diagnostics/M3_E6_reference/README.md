# M3 Experiment E6 Reference Data (Prior Milestone Evidence)

> **Provenance Notice:** These files are **verbatim copies of Milestone 3 (M3) results** from `M3/results/E6_nu_sweep/` preserved inside `M4_Group9/Results/` for full report traceability. They are **prior M3 preliminary results**, not newly executed M4 experiments.

- **Original Experiment:** M3 Experiment E6 ($\nu$-sweep on the 4 M2-capped GC draws `{21, 26, 31, 34}` at `R = 32, Rg = 4, G = 8`, `max_iter = 25000`, reciprocal CGA only).
- **Files Copied Verbatim:**
  - `E6_per_run.csv` — Per-run metrics across draws `{21, 26, 31, 34}` and $\nu \in \{0.1, 1.0, 10.0\}$
  - `E6_summary.csv` — Aggregated E6 metrics by $\nu$
  - `E6_m2_comparison.csv` — E6 ($\nu=1$, cap `25000`) comparison against the M2 `8000`-cap anchor
  - `E6_nu_sweep_final.csv` — Final formatted M3 E6 summary table
- **M4 Replacement / Extension:** See `M4_Group9/Code/src/experiments/run_cap_diagnostic.m` (10 draws at `40000` cap, both reciprocal and general V-frozen) and `M4_Group9/Code/src/experiments/run_nu_sensitivity.m` (20 draws across GC and FC + `25000`-cap subset).

