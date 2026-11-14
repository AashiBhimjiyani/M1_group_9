# Task 3 — Penalty Weight ($\nu$) Sensitivity (`nu_sensitivity`)

## Execution Status
**Executed — Complete.**  
Generated outputs:
- `nu_sensitivity_per_run.csv` (20-draw per-run rates, iterations, projection costs, residuals)
- `nu_sensitivity_summary.csv` (aggregated statistics across $\nu \in \{0.1, 1.0, 10.0\}$ for GC and FC)
- `nu_sensitivity_results.mat` (complete MATLAB workspace)
- `nu_sensitivity_plots.png` (diagnostic rate and iteration boxplots)
- `nu_sensitivity_high_cap_per_run.csv` (high-cap 25k per-run data on seeds 1, 6, 11, 16)
- `nu_sensitivity_high_cap_summary.csv` (high-cap 25k aggregated statistics)
- `nu_sensitivity_high_cap_results.mat` (high-cap workspace)

## Summary of Results (20 Draws, Seeds 1–20, Cap = 8,000)

| Arch | $R_g$ | $\nu$ | Rec Rate Post (bps/Hz) | Gen Rate FV (bps/Hz) | Mean Gap (bps/Hz) | Ratio-of-Means Gap (%) | Projection Cost (bps/Hz) | Symmetry Residual | Rec Conv / Cap Hits | Mean Rec Iters |
|---|---|---|---|---|---|---|---|---|---|---|
| **GC** | 4 | 0.1 | $9.2396 \pm 0.4617$ | $9.3169 \pm 0.4791$ | $0.0773 \pm 0.0252$ | 0.83% | $0.03250 \pm 0.01069$ | $0.1989 \pm 0.0524$ | 19 / 1 | 883.4 |
| **GC** | 4 | 1.0 | $9.2074 \pm 0.4634$ | $9.3169 \pm 0.4791$ | $0.1095 \pm 0.0557$ | 1.18% | $0.00438 \pm 0.00185$ | $0.0288 \pm 0.0083$ | 20 / 0 | 845.8 |
| **GC** | 4 | 10.0 | $9.2413 \pm 0.4684$ | $9.3169 \pm 0.4791$ | $0.0756 \pm 0.0220$ | 0.81% | $0.00031 \pm 0.00009$ | $0.0036 \pm 0.0005$ | 13 / 7 | 4971.8 |
| **FC** | 32 | 0.1 | $9.6033 \pm 0.4984$ | $9.6169 \pm 0.5016$ | $0.0136 \pm 0.0070$ | 0.14% | $0.01766 \pm 0.00710$ | $0.0994 \pm 0.0346$ | 20 / 0 | 344.9 |
| **FC** | 32 | 1.0 | $9.6226 \pm 0.5028$ | $9.6169 \pm 0.5016$ | $-0.0057 \pm 0.0066$ | -0.06% | $0.00018 \pm 0.00014$ | $0.0043 \pm 0.0020$ | 20 / 0 | 571.8 |
| **FC** | 32 | 10.0 | $9.6226 \pm 0.5028$ | $9.6169 \pm 0.5016$ | $-0.0057 \pm 0.0066$ | -0.06% | $0.000005 \pm 0.000003$ | $0.0006 \pm 0.0002$ | 20 / 0 | 575.2 |

## High-Cap Subset Results (Seeds 1, 6, 11, 16, Cap = 25,000)

| Arch | $R_g$ | $\nu$ | Rec Rate Post (bps/Hz) | Gen Rate FV (bps/Hz) | Mean Gap (bps/Hz) | Projection Cost (bps/Hz) | Symmetry Residual | Rec Conv / Cap Hits | Mean Rec Iters |
|---|---|---|---|---|---|---|---|---|---|
| **GC** | 4 | 0.1 | $9.1408 \pm 0.5469$ | $9.1852 \pm 0.5534$ | $0.0444 \pm 0.0331$ | $0.00572 \pm 0.00399$ | $0.1039 \pm 0.0548$ | 4 / 0 | 220.8 |
| **GC** | 4 | 1.0 | $8.9127 \pm 0.4556$ | $9.1852 \pm 0.5534$ | $0.2725 \pm 0.2230$ | $0.00884 \pm 0.00862$ | $0.0394 \pm 0.0322$ | 4 / 0 | 178.5 |
| **GC** | 4 | 10.0 | $9.1492 \pm 0.5544$ | $9.1852 \pm 0.5534$ | $0.0360 \pm 0.0277$ | $0.00002 \pm 0.00001$ | $0.0012 \pm 0.0003$ | 2 / 2 | 13855.0 |
| **FC** | 32 | 0.1 | $9.3597 \pm 0.5412$ | $9.3733 \pm 0.5425$ | $0.0136 \pm 0.0125$ | $0.00882 \pm 0.00777$ | $0.0641 \pm 0.0388$ | 4 / 0 | 224.5 |
| **FC** | 32 | 1.0 | $9.3709 \pm 0.5411$ | $9.3733 \pm 0.5425$ | $0.0024 \pm 0.0023$ | $0.00069 \pm 0.00067$ | $0.0108 \pm 0.0090$ | 4 / 0 | 572.8 |
| **FC** | 32 | 10.0 | $9.3712 \pm 0.5423$ | $9.3733 \pm 0.5425$ | $0.0021 \pm 0.0019$ | $0.000001 \pm 0.000001$ | $0.0007 \pm 0.0003$ | 4 / 0 | 395.3 |

### Engineering Assessment of $\nu = 1.0$ Default

Rather than a proven mathematical optimum, the experimental results demonstrate that **$\nu = 1.0$ serves as an adequate practical engineering default**:

1. **GC Performance and Statistical Indistinguishability:**
   - Mean reciprocal sum rates across 20 draws:
     - $\nu = 0.1$: $9.240 \pm 0.462$ bps/Hz
     - $\nu = 1.0$: $9.207 \pm 0.463$ bps/Hz
     - $\nu = 10.0$: $9.241 \pm 0.468$ bps/Hz
   - The paired difference between $\nu = 1.0$ and $\nu = 0.1$ is **$-0.032 \pm 0.050$ bps/Hz**. Given this paired variation, the performance across all three $\nu$ values for GC is **statistically indistinguishable**.
2. **Important GC Seed 11 Anomaly (Premature Tolerance Stop):**
   - At $\nu = 1.0$, GC Seed 11 stops after only 27 iterations due to an early objective-change tolerance condition ($|\Delta F| < 10^{-8}$).
   - This premature termination leaves a large reciprocity gap of **$0.932$ bps/Hz** (reciprocal rate $9.191$ vs. general rate $10.123$ bps/Hz).
   - In contrast, under the other penalty values on the exact same channel:
     - $\nu = 0.1$: gap is $0.037$ bps/Hz (158 iterations, rate $10.086$ bps/Hz)
     - $\nu = 10.0$: gap is $0.013$ bps/Hz (8000 iterations, rate $10.111$ bps/Hz)
   - The identical anomaly is present in the M2 anchor dataset (Draw 11 gap is $0.932$ bps/Hz after 27 iterations). Across the 50-draw anchor ensemble, this single premature stop inflates the overall GC mean gap ($0.103$ bps/Hz) by approximately **$0.02$ bps/Hz** ($0.932 / 50 \approx 0.0186$ bps/Hz).
3. **FC Performance:**
   - For FC, $\nu = 1.0$ beats $\nu = 0.1$ by **$+0.019 \pm 0.008$ bps/Hz**, avoiding the substantial post-projection distortion ($0.0177$ bps/Hz projection loss) seen at $\nu = 0.1$.
   - $\nu = 1.0$ and $\nu = 10.0$ yield identical post-projection rates to six decimal places ($9.6226$ bps/Hz).
4. **Computational Burden and Stalling at $\nu = 10.0$:**
   - While $\nu = 10.0$ minimizes projection cost ($< 0.0003$ bps/Hz), it severely stiffens the penalty gradient.
   - For GC, $\nu = 10.0$ results in **7 out of 20 draws hitting the 8,000-iteration cap** (mean iterations spike from $845.8$ to $4971.8$).
   - In the higher-cap representative subset (`max_iter = 25000`), **2 of 4 seeds still hit the 25,000 cap** under $\nu = 10.0$ (mean iterations $13,855.0$).
5. **Practical Recommendation:**
   - $\nu = 1.0$ is retained as the default because it strikes an effective balance: it avoids the projection distortion of $\nu = 0.1$ on FC while avoiding the severe convergence stalling and cap-hit inflation of $\nu = 10.0$ on GC. However, it should be recognized as an engineering heuristic rather than a theoretically certified global optimum.

## Experiment Design
- **Script:** `M4_Group9/Code/src/experiments/run_nu_sensitivity.m`
- **Penalty Weights:** $\nu \in \{0.1, 1.0, 10.0\}$
- **Scenarios:** GC ($R=32, R_g=4, G=8$) and FC ($R=32, R_g=32, G=1$)
- **Draws:** 20 independent Rayleigh draws (seeds `1..20`), plus a configurable higher-cap representative subset (`run_high_cap_subset = true`, `high_cap_nu = 25000`, `high_cap_seeds = [1, 6, 11, 16]`) to test convergence sensitivity beyond `8000` iterations.
- **System / Solver Settings:** $N=2, K=2, P_{\max}=20\text{ dBm}, N_0=-80\text{ dBm}, \epsilon_{\mathrm{tol}}=10^{-8}, \texttt{max\_iter}=8000$ (configurable via `max_iter_nu` workspace override)
- **Recorded Metrics:** `cap`, pre/post-projection reciprocal sum rates, recomputed-V rate, general V-frozen rate, sum-rate gap (`gen_fv - rec_post`), iteration counts, explicit cap-hit flags (`rec_hit_cap`, `gen_hit_cap`) separated from converged-only summary rates (`mean_rec_rate_post_conv_only`), projection cost (`rate_pre - rate_post`), and penalty residual $\|\boldsymbol{\Theta}_{\mathrm{opt}} - \boldsymbol{\Theta}_{\mathrm{opt}}^T\|_F$.

## Prior M3 Reference Evidence (M3 E6 — 4 GC draws only, cap 25,000)
In `M4_Group9/Results/diagnostics/M3_E6_reference/E6_summary.csv` (copied verbatim from prior M3 E6, which tested only the 4 capped GC draws `{21, 26, 31, 34}` at cap `25,000` without FC or general V-frozen gap tracking):
- At $\nu = 0.1$: 4/4 converged (mean `14,709` iters), but mean projection cost was $0.0994\text{ bps/Hz}$ (residual $0.513$) — nearly equal to the entire M2 GC reciprocity gap ($0.1030\text{ bps/Hz}$).
- At $\nu = 1.0$: 3/4 converged (mean `18,265` iters; Draw 34 hit `25,000`), mean projection cost dropped $\sim 11\times$ to $0.00876\text{ bps/Hz}$ (residual $0.0624$), and mean post-projection rate was $12.2603\text{ bps/Hz}$.
- At $\nu = 10.0$: 0/4 converged (4/4 hit `25,000`), mean projection cost was $0.000864\text{ bps/Hz}$ (residual $0.00641$), and mean post-projection rate was $12.2600\text{ bps/Hz}$ ($0.0003\text{ bps/Hz}$ difference vs $\nu = 1$).

## MATLAB Execution Command
```matlab
cd('M4_Group9/Code/src');
setup_paths;
run('experiments/run_nu_sensitivity.m');
```
Expected outputs in this folder: `nu_sensitivity_per_run.csv`, `nu_sensitivity_summary.csv`, `nu_sensitivity_results.mat`, `nu_sensitivity_plots.png`, plus `nu_sensitivity_high_cap_per_run.csv`, `nu_sensitivity_high_cap_summary.csv`, `nu_sensitivity_high_cap_results.mat`.

