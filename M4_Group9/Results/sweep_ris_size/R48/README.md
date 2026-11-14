# Task 4 — RIS-Size Sweep: $R = 48$ ($R_g = 4, G = 12$)

## Execution Status
**Executed — Complete.**  
- **Quick Test (3 draws):** Complete (`quick_test_3draws/`). Runtime: 72.55s (24.18s/draw).
- **Full Run (50 draws):** Complete.
  - `per_draw.csv` (50 draws for SC, GC, FC)
  - `summary.csv` (aggregated metrics)
  - `matched_sumrate.png` & `matched_convergence.png`

## 50-Draw Results Summary ($R=48, G=12$)

| Architecture | $R_g$ | Rec Rate (bps/Hz) | Gen Rate (bps/Hz) | Gap (bps/Hz) | Gap (%) [Ratio-of-Means] | Gap (%) [Per-Draw Mean] | SC Control Gain | Rec Cap Hits | Gen Cap Hits | Armijo Hits |
|---|---|---|---|---|---|---|---|---|---|---|
| **SC** | 1 | $10.9144 \pm 0.2499$ | $10.9144 \pm 0.2499$ | 0.0000 | 0.00% | 0.00% | 0.0000 | 1 | 1 | 0 |
| **GC** | 4 | $12.3227 \pm 0.2785$ | $12.4782 \pm 0.2928$ | $0.1555 \pm 0.0263$ | 1.25% | 1.13% | +1.4083 | 12 | 3 | 0 |
| **FC** | 48 | $12.7789 \pm 0.2996$ | $12.8222 \pm 0.3018$ | $0.0433 \pm 0.0238$ | 0.34% | 0.31% | +1.8645 | 3 | 0 | 0 |

### Cap Hits and Capped-Draw Sensitivity
- **Capped Draws:** GC reciprocal hit the 8k cap in 12 draws (general hit in 3); FC reciprocal hit in 3 draws.
- **Uncapped Subset (38 draws retained):** Excluding draws where either solver reached the cap shifts the GC mean gap from **$0.1555$ to $0.1388$ bps/Hz**.
- **Negative Gaps ($\text{Gap} < -10^{-4}$ bps/Hz):** 6 draws for FC (Draws 12, 16, 26, 31, 37, 42; max reciprocal advantage was Draw 37 at $-0.2750$ bps/Hz). All GC gaps were positive or within tie tolerance ($+0.000003$ bps/Hz min).
- **Armijo Limit Hits:** Exactly 0 across all 50 draws.

## Configuration
- **Anchor Reference:** M2 $R = 32, R_g = 4, G = 8$ (`M4_Group9/Results/anchor_rayleigh_R32_50draws/`, fallback: `Results/matched_rayleigh_R32_50draws/`)
- **R:** `48`
- **Architectures:** `SC` ($R_g = 1$), `GC` ($R_g = 4, G = 12$), `FC` ($R_g = 48$)
- **N / K:** `2` / `2`
- **Pmax / N0:** `20 dBm` (`0.1 W`) / `-80 dBm` (`1e-11 W`)
- **Channel:** Rayleigh (`Kf_dB = -Inf`)
- **Draws:** `50` (seeds `1..50`)
- **run_joint:** `false`
- **Algorithm:** `nu = 1.0`, `eps_tol = 1e-8`, `max_iter = 8000`

## MATLAB Execution Commands
```matlab
cd('M4_Group9/Code/src'); setup_paths;
% 1. Quick 3-draw check (SC, GC, FC — runs standalone without anchor)
sweep_mode = 'quick'; R_list = [48]; run('experiments/run_ris_size_sweep.m');

% 2. Full 50-draw run (after confirming quick test outputs)
sweep_mode = 'full'; R_list = [48]; run('experiments/run_ris_size_sweep.m');
```

