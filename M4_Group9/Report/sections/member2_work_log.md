# Member 2 Work Log and Technical Record — Milestone 4 (M4)

**Role:** Member 2 — Reciprocal Optimizer Lead  
**Project:** Quantifying the Sum-Rate Cost of Reciprocity in Beyond-Diagonal RIS-Aided MU-MISO Systems  
**Group:** Group 9  
**Execution Environment:** MATLAB R2025a, Windows x64  

---

## 1. Member 2 Responsibilities and Scope

Member 2 is responsible for:
1. **Configurable Iteration Cap (Task 1):** Implementing backward-compatible, prioritized `max_iter` overrides in `run_cga_optimizer.m` and updating `general_fixedV_optimizer.m` interface.
2. **Iteration-Cap Diagnostic (Task 2):** Evaluating convergence and rate differences between 8,000 and 40,000 iteration caps on 10 GC draws ($R=32, R_g=4$).
3. **Penalty Parameter ($\nu$) Sensitivity (Task 3):** Evaluating $\nu \in \{0.1, 1.0, 10.0\}$ across GC and FC architectures over 20 draws plus a higher-cap subset.
4. **Multi-Size BD-RIS Sweep (Task 4):** Evaluating element counts $R \in \{16, 48, 64\}$ across Single-Connected (SC), Group-Connected (GC, $R_g=4$), and Fully-Connected (FC) architectures (50 draws each) and merging with the M2 $R=32$ anchor.
5. **Reciprocal Optimization Methodology Report (Task 5):** Authoring Section 3 of the final milestone report (`Report/sections/03_reciprocal_method.md`).
6. **Integration & Parity Verification:** Ensuring full compatibility with Member 4's common framework and preserving Member 3's nonreciprocal algorithms.

---

## 2. Repository Audit, Ownership, and Compatibility Findings

1. **Member 4's M2 Common Framework Integration:**
   - Provides `setup_paths.m`, `configs/default_config.m`, `tests/test_common_framework.m`, and `common/{common_generate_channels.m, common_init_theta.m, common_mmse_beamformer.m, common_pathloss.m, common_sinr.m, common_sumrate.m, run_matched_experiment.m, save_matched_results.m, plot_matched_results.m, README.md}`.
   - In M4, all Member 4 channel/metric/init/plot files are reused under `M4_Group9/Code/src/common/` with zero shadowing.
   - Interface hooks were added preserving Member 4's original logic: `p.max_iter` override, dynamic `G -> Rg_list` derivation, `armijo_max_hits` tracking, explicit error checking, and full-config per-draw checkpoint/resume validation (`configs_match_ckpt.m`).
2. **`run_cga_optimizer.m` and `general_fixedV_optimizer.m` Compatibility:**
   - **M2 Base:** 7-input, 2-output `[Theta, hist]` with hardcoded `max_iter = 8000`.
   - **M4 Enhancements:** Prioritized `opts.max_iter` > `p.max_iter` > default `8000`, empty guard `~isempty`, attribute validation, and telemetry fields `info.iters`, `info.max_iter`, and `info.armijo_max_hits`.
   - Full backward compatibility maintained for legacy 7-arg / 2-output calls.
   - See [Results/diagnostics/task1_max_iter_diff.md](../../Results/diagnostics/task1_max_iter_diff.md) for full unified diff.
3. **Anchor Reference Path Priority:**
   - Priority 1: `M4_Group9/Results/anchor_rayleigh_R32_50draws/`
   - Priority 2: Read-only `Results/matched_rayleigh_R32_50draws/`
   - Automated path resolution implemented in `Code/src/experiments/resolve_anchor_path.m`.

---

## 3. Short Verification Suite Execution (Tests 1–6)

Executed and verified in MATLAB R2025a:
- **Test 1 (Path Setup):** `setup_paths.m` mounted all 7 directories cleanly.
- **Test 2 (Parity Checks):** 14/14 checks passed in `test_common_framework.m`.
- **Test 3 (Task 1 Cap Override):** Verified default 8000 cap, dynamic overrides, empty fallback, and backward compatibility in `test_task1_max_iter.m`.
- **Test 4 (Function Resolution):** `which -all` confirmed unique resolution for `run_matched_experiment`, `save_matched_results`, `plot_matched_results`, and `default_config`.
- **Test 5 (3-Draw Quick Sweep):** Standalone execution for $R \in \{16, 48, 64\}$ completed without anchor dependency. Runtime: R16 (8.84 s/draw), R48 (24.18 s/draw), R64 (28.76 s/draw $< 120$ s threshold).
- **Test 6 (Checkpoint Rejection):** `configs_match_ckpt.m` successfully resumed valid cached draws and rejected altered configs (`Pmax_dBm`, `N`, `K`, `fading`, `Kf_dB`, `max_iter`, `seed_base`).

See [Results/validation_log_member2.md](../../Results/validation_log_member2.md) for full execution logs.

---

## 4. Summary of Completed Experiments

### Task 2: Iteration-Cap Diagnostic (`cap_check`)
- **Scope:** 10 GC draws ($R=32, R_g=4$) comparing `max_iter = 8000` vs `max_iter = 40000`.
- **Outputs:** `cap_check_per_draw.csv`, `cap_check_summary.csv`, `cap_check_results.mat`.
- **Findings:**
  - Ordinary draws (1–6) produced identical rates between 8k and 40k caps (mean reciprocal rate 7.6822 bps/Hz).
  - Capped draws (21, 26, 31) converged at 19303, 14053, and 14704 iterations with minimal rate gains ($+0.0012$ to $+0.0039$ bps/Hz).
  - Draw 34 reached the 40,000 cap ($+0.0125$ bps/Hz gain).
  - Mean rate gain across the 4 capped draws was $+0.0048$ bps/Hz; mean gap shifted from $0.2039$ to $0.1991$ bps/Hz ($1.64\% \to 1.60\%$).
  - Armijo limit hits: 0 across all 10 draws.

### Task 3: Penalty Parameter Sensitivity (`nu_sensitivity`)
- **Scope:** $\nu \in \{0.1, 1.0, 10.0\}$ over 20 draws (seeds 1–20) for GC and FC, plus 25k subset on seeds `[1, 6, 11, 16]`.
- **Outputs:** `nu_sensitivity_per_run.csv`, `nu_sensitivity_summary.csv`, `nu_sensitivity_results.mat`, `nu_sensitivity_plots.png`, `nu_sensitivity_high_cap_per_run.csv`, `nu_sensitivity_high_cap_summary.csv`, `nu_sensitivity_high_cap_results.mat`.
- **Key Findings & Correction:**
  - GC reciprocal rates: $\nu=0.1 \to 9.240$, $\nu=1.0 \to 9.207$, $\nu=10.0 \to 9.241$ bps/Hz. Paired difference between $\nu=1.0$ and $\nu=0.1$ is $-0.032 \pm 0.050$ bps/Hz (statistically indistinguishable).
  - FC reciprocal rates: $\nu=1.0$ beats $\nu=0.1$ by $+0.019 \pm 0.008$ bps/Hz; $\nu=1.0$ and $\nu=10.0$ yield identical rates ($9.6226$ bps/Hz).
  - GC seed 11 at $\nu=1.0$ experienced a premature tolerance stop at iteration 27 with a gap of $0.932$ bps/Hz (compared to $0.037$ at $\nu=0.1$ and $0.013$ at $\nu=10.0$). This single draw contributes $\sim 0.02$ bps/Hz to the GC mean gap of $0.103$ bps/Hz.
  - Conclusion: $\nu=1.0$ is an adequate practical engineering default, not a proven mathematical optimum. It avoids the FC projection loss of $\nu=0.1$ and the severe cap-hit stalling of $\nu=10.0$ (7/20 cap hits at 8k, 2/4 cap hits at 25k).

### Task 4: Multi-Size BD-RIS Sweep (`sweep_ris_size`)
- **Scope:** 50 draws each for $R \in \{16, 48, 64\}$ across SC, GC ($R_g=4$), and FC, merged with M2 anchor ($R=32$) into `sweep_summary.csv`.
- **Outputs:** `R16/`, `R48/`, `R64/`, and `sweep_summary.csv`.
- **Key Findings:**
  - GC reciprocity gap remains bounded in $[0.10, 0.16]$ bps/Hz ($1.0\%$ to $2.1\%$).
  - FC reciprocity gap remains $\le 0.11$ bps/Hz ($< 0.83\%$).
  - SC control gain: GC adds $+1.21$ to $+1.41$ bps/Hz, FC adds $+1.60$ to $+1.86$ bps/Hz over SC.
  - Armijo limit hits: 0 across all 9 M4-run rows (R32 anchor rows contain NaN as Armijo hits were not recorded in M2).
  - Iteration-cap hits: GC rec cap hits were 4 ($R=16$), 12 ($R=48$), 5 ($R=64$). Excluding capped draws shifts $R=48$ GC gap from $0.1555$ to $0.1388$ bps/Hz (38 draws retained), and $R=64$ GC gap from $0.1548$ to $0.1398$ bps/Hz (43 draws retained).
  - Negative gaps ($< -10^{-4}$ bps/Hz): R16 FC (1 draw), R48 FC (6 draws), R64 GC (3 draws), R64 FC (6 draws), representing local stationary-point solver variations where reciprocal marginally exceeded general.

