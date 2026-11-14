# M4_Group9 Data Documentation

All experiments in this project use synthetically generated Rayleigh and Rician channel realizations created deterministically inside MATLAB via `common_generate_channels(p)` / `generate_channels(p)` with explicit Twister RNG seeds (`rng(seed, 'twister')`). No external datasets are required.

## Reused Preliminary Evidence
- **M2 Anchor ($R=32$, 50 Rayleigh draws):** Read-only copy inside M4 at `M4_Group9/Results/anchor_rayleigh_R32_50draws/{per_draw.csv, summary.csv, config_used.txt, matched_sumrate.png, matched_convergence.png}` (copied from `Results/matched_rayleigh_R32_50draws/`).
- **M3 Preliminary E6 ($\nu$-sweep on 4 capped GC draws at 25k cap):** Copied verbatim inside M4 at `M4_Group9/Results/diagnostics/M3_E6_reference/{E6_per_run.csv, E6_summary.csv, E6_m2_comparison.csv, E6_nu_sweep_final.csv}` (from `M3/results/E6_nu_sweep/`).
- **M3 Stretch E8 (Joint precoder design, 50 Rayleigh draws):** Copied verbatim inside M4 at `M4_Group9/Results/diagnostics/M3_E8_reference/{E8_per_draw_50draws.csv, E8_summary_50draws.csv, E8_outer_sensitivity.csv, E8_outer_sensitivity_final.csv, E8_joint_50draws_final.csv, E8_per_draw.csv, E8_summary.csv}` (from `M3/results/E8_joint_precoder/`).

## M4 Channel Parameters (`Code/src/configs/default_config.m` & `Code/src/reciprocal/config.m`)
- $N = 2$ BS antennas, $K = 2$ single-antenna users
- $P_{\max} = 20\text{ dBm} = 0.1\text{ W}$, $N_0 = -80\text{ dBm} = 10^{-11}\text{ W}$
- Path loss: $C_0 = -30\text{ dB}$ at $d_0 = 1\text{ m}$, $\rho = 2.2$, $d_{\mathrm{BS-RIS}} = 50\text{ m}$, $d_{\mathrm{RIS-user}} = 2.5\text{ m}$
- Fading: Rayleigh (`Kf_dB = -Inf`, $K_f = 0$)
