# Task 4 — RIS-Size Sweep: $R = 16$ ($R_g = 4, G = 4$)

## Execution Status
**Executed — Complete.**  
- **Full Run (50 draws):** Complete.
  - `per_draw.csv` (50 draws for SC, GC, FC)
  - `summary.csv` (aggregated metrics)
  - `matched_sumrate.png` & `matched_convergence.png`

## 50-Draw Results Summary ($R=16, G=4$)

| Architecture | $R_g$ | Rec Rate (bps/Hz) | Gen Rate (bps/Hz) | Gap (bps/Hz) | Gap (%) [Ratio-of-Means] | Gap (%) [Per-Draw Mean] | SC Control Gain | Rec Cap Hits | Gen Cap Hits | Armijo Hits |
|---|---|---|---|---|---|---|---|---|---|---|
| **SC** | 1 | $5.4341 \pm 0.1738$ | $5.4341 \pm 0.1738$ | 0.0000 | 0.00% | 0.00% | 0.0000 | 0 | 0 | 0 |
| **GC** | 4 | $6.6438 \pm 0.2039$ | $6.7834 \pm 0.2167$ | $0.1397 \pm 0.0229$ | 2.06% | 1.85% | +1.2096 | 4 | 0 | 0 |
| **FC** | 16 | $7.0328 \pm 0.2312$ | $7.0474 \pm 0.2331$ | $0.0145 \pm 0.0085$ | 0.21% | 0.17% | +1.5987 | 0 | 0 | 0 |

## Configuration
- **Anchor Reference:** M2 $R = 32, R_g = 4, G = 8$ (`M4_Group9/Results/anchor_rayleigh_R32_50draws/`, fallback: `Results/matched_rayleigh_R32_50draws/`)
- **R:** `16`
- **Architectures:** `SC` ($R_g = 1$), `GC` ($R_g = 4, G = 4$), `FC` ($R_g = 16$)
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
sweep_mode = 'quick'; R_list = [16]; run('experiments/run_ris_size_sweep.m');

% 2. Full 50-draw run (after confirming quick test outputs)
sweep_mode = 'full'; R_list = [16]; run('experiments/run_ris_size_sweep.m');
```

