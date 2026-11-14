# M2 Anchor Baseline Reference (Rayleigh, $R = 32$, $R_g = 4$, $G = 8$, 50 Draws)

Read-only reference copy of the completed M2 matched experiment (`Results/matched_rayleigh_R32_50draws/`), preserved for offline comparison in Task 2 (`run_cap_diagnostic.m`), Task 4 (`run_ris_size_sweep.m`), and `test_restarts.m`.

## Contents
- `per_draw.csv` — 150 rows (`50` draws × `{SC, GC, FC}`)
- `summary.csv` — mean, SE, and `n = 50` across `{rec_fv, rec_v2, gen_fv, gen_v2, gen_jt, gap_fv, gap_v2, gap_fv_pct, gap_v2_pct}`
- `config_used.txt` — M2 configuration (`N=2, K=2, R=32, G=8, Pmax_dBm=20, N0_dBm=-80, Kf_dB=-Inf, nu=1, eps_tol=1e-8`)
- `matched_sumrate.png`, `matched_convergence.png` — M2 reference figures

