# Task 4 — RIS-Size Sweep: $R = 64$ ($R_g = 4, G = 16$)

## Execution Status
**Executed — Complete.**  
- **Quick Test (3 draws):** Complete (`quick_test_3draws/`). Runtime: 86.29s (28.76s/draw < 120s threshold).
- **Full Run (50 draws):** Complete all 50 draws (seeds 1–50).
  - `per_draw.csv` (50 draws for SC, GC, FC)
  - `summary.csv` (aggregated metrics)
  - `matched_sumrate.png` & `matched_convergence.png`

## 50-Draw Results Summary ($R=64, G=16$)

| Architecture | $R_g$ | Rec Rate (bps/Hz) | Gen Rate (bps/Hz) | Gap (bps/Hz) | Gap (%) [Ratio-of-Means] | Gap (%) [Per-Draw Mean] | SC Control Gain | Rec Cap Hits | Gen Cap Hits | Armijo Hits |
|---|---|---|---|---|---|---|---|---|---|---|
| **SC** | 1 | $11.8942 \pm 0.3506$ | $11.8942 \pm 0.3506$ | 0.0000 | 0.00% | 0.00% | 0.0000 | 1 | 1 | 0 |
| **GC** | 4 | $13.2184 \pm 0.3807$ | $13.3732 \pm 0.3929$ | $0.1548 \pm 0.0429$ | 1.16% | 1.04% | +1.3242 | 5 | 2 | 0 |
| **FC** | 64 | $13.6150 \pm 0.4103$ | $13.7282 \pm 0.3994$ | $0.1133 \pm 0.0420$ | 0.82% | 1.03% | +1.7208 | 1 | 4 | 0 |

### Cap Hits and Capped-Draw Sensitivity
- **Capped Draws:** GC reciprocal hit the 8k cap in 5 draws (general hit in 2); FC reciprocal hit in 1 draw, while FC general hit in 4 draws.
- **Uncapped Subset (43 draws retained for GC):** Excluding draws where either solver reached the cap shifts the GC mean gap from **$0.1548$ to $0.1398$ bps/Hz**.
- **FC Solver Cap Impact:** Because the general solver hit the 8k cap in 4 draws, the reported FC gap ($0.1133$ bps/Hz) may be slightly understated.
- **Negative Gaps ($\text{Gap} < -10^{-4}$ bps/Hz):** 3 draws for GC (Draws 10, 11, 27; min was Draw 10 at $-0.6196$ bps/Hz); 6 draws for FC (Draws 2, 6, 30, 31, 42, 43; min was Draw 30 at $-0.1868$ bps/Hz).
- **Armijo Limit Hits:** Exactly 0 across all 50 draws.

## Configuration
- **Anchor Reference:** M2 $R = 32, R_g = 4, G = 8$ (`M4_Group9/Results/anchor_rayleigh_R32_50draws/`, fallback: `Results/matched_rayleigh_R32_50draws/`)
- **R:** `64`
- **Architectures:** `SC` ($R_g = 1$), `GC` ($R_g = 4, G = 16$), `FC` ($R_g = 64$)
- **N / K:** `2` / `2`
- **Pmax / N0:** `20 dBm` (`0.1 W`) / `-80 dBm` (`1e-11 W`)
- **Channel:** Rayleigh (`Kf_dB = -Inf`)
- **Draws:** `50` (or `30` if per-draw runtime exceeds a few minutes; `run_ris_size_sweep.m` automatically drops to `30` when `sweep_mode = 'both'` and quick test exceeds `120 s/draw`, or set `nd_R64 = 30`)
- **run_joint:** `false`
- **Algorithm:** `nu = 1.0`, `eps_tol = 1e-8`, `max_iter = 8000`

## MATLAB Execution Commands
```matlab
cd('M4_Group9/Code/src'); setup_paths;
% 1. Quick 3-draw check (SC, GC, FC — runs standalone without anchor)
sweep_mode = 'quick'; R_list = [64]; run('experiments/run_ris_size_sweep.m');

% 2. Full run (set nd_R64 = 30 if one draw takes > 2-3 minutes)
sweep_mode = 'full'; R_list = [64]; % nd_R64 = 30;
run('experiments/run_ris_size_sweep.m');
```

