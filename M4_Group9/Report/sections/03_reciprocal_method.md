# Section 3: Reciprocal BD-RIS Optimization Method

**Role:** Member 2 — Reciprocal Optimizer Lead  
**Scope:** Reciprocal Beyond-Diagonal RIS (BD-RIS) Riemannian Conjugate-Gradient Ascent (CGA) pipeline, mathematical formulation, verified implementation parameters, convergence behavior, and known limitations.

---

## 3.1 System Model and Verified Configuration

We consider a downlink multi-user MISO (MU-MISO) system assisted by an $R$-element reflective BD-RIS, where a base station (BS) with $N$ transmit antennas serves $K$ single-antenna users via cascaded BS–RIS–user channels without a direct BS–user link:
$$\mathbf{r} = \mathbf{H}_{\mathrm{RX}} \boldsymbol{\Theta} \mathbf{H}_{\mathrm{TX}} \mathbf{V} \mathbf{s} + \mathbf{n},$$
where $\mathbf{H}_{\mathrm{TX}} \in \mathbb{C}^{R \times N}$ is the BS-to-RIS channel, $\mathbf{H}_{\mathrm{RX}} \in \mathbb{C}^{K \times R}$ is the RIS-to-user channel, $\mathbf{V} = [\mathbf{v}_1, \dots, \mathbf{v}_K] \in \mathbb{C}^{N \times K}$ is the transmit precoder satisfying $\|\mathbf{V}\|_F^2 \le P_{\max}$, and $\mathbf{n} \sim \mathcal{CN}(\mathbf{0}, N_0 \mathbf{I}_K)$ is additive white Gaussian noise.

For a passive, lossless, **reciprocal** BD-RIS partitioned into $G$ groups of block size $R_g = R / G$, the scattering matrix $\boldsymbol{\Theta} \in \mathbb{C}^{R \times R}$ is block-diagonal with $G$ blocks $\boldsymbol{\Theta}_g \in \mathbb{C}^{R_g \times R_g}$ satisfying both unitarity and complex symmetry:
$$\mathcal{U}_S(R, R_g) = \left\{ \boldsymbol{\Theta} = \mathrm{blkdiag}(\boldsymbol{\Theta}_1, \dots, \boldsymbol{\Theta}_G) \in \mathbb{C}^{R \times R} : \boldsymbol{\Theta}_g^H \boldsymbol{\Theta}_g = \mathbf{I}_{R_g}, \ \boldsymbol{\Theta}_g = \boldsymbol{\Theta}_g^T \ \forall g = 1,\dots,G \right\}.$$
- **Single-Connected (SC):** $R_g = 1, G = R$ (diagonal phase shifts, automatically symmetric).
- **Group-Connected (GC):** $1 < R_g < R, G = R / R_g$ (e.g., $R_g = 4$ with $G = 8$ at $R = 32$, and $G \in \{4, 12, 16\}$ for $R \in \{16, 48, 64\}$).
- **Fully-Connected (FC):** $R_g = R, G = 1$.

### Verified System Parameters (`Code/src/configs/default_config.m`)
The simulation configuration is standardized and verified in `M4_Group9/Code/src/configs/default_config.m` and confirmed by `M4_Group9/Results/anchor_rayleigh_R32_50draws/config_used.txt`:
- **Antennas & Users:** $N = 2$ base station transmit antennas, $K = 2$ single-antenna users
- **Transmit Power Budget:** $P_{\max} = 20\text{ dBm} = 0.1\text{ W}$
- **Noise Power:** $N_0 = -80\text{ dBm} = 10^{-11}\text{ W}$
- **Path Loss:** $C_0 = -30\text{ dB}$ ($10^{-3}$) at reference distance $d_0 = 1.0\text{ m}$, path loss exponent $\rho = 2.2$, distance $d_{\mathrm{BS-RIS}} = 50\text{ m}$ ($PL_{\mathrm{BS-RIS}} \approx 1.829 \times 10^{-7}$), $d_{\mathrm{RIS-user}} = 2.5\text{ m}$ ($PL_{\mathrm{RIS-user}} \approx 1.332 \times 10^{-4}$)
- **Fading:** Rayleigh (`Kf_dB = -Inf`, $K_f = 0$)

---

## 3.2 Optimization Pipeline Overview

To isolate the sum-rate cost of electromagnetic reciprocity ($\boldsymbol{\Theta} = \boldsymbol{\Theta}^T$) under identical starting conditions, the primary fixed-$\mathbf{V}$ reciprocal pipeline (`run_cga_optimizer.m` + `enforce_symmetry_unitarity.m`) proceeds as follows:

1. **Matched Initialization (`common_init_theta.m` / `initialize_theta.m`, `common_mmse_beamformer.m` / `mmse_beamformer.m`):**  
   In the matched comparison runner (`run_matched_experiment.m` from Member 4's M2 framework), for each channel realization $(\mathbf{H}_{\mathrm{TX}}, \mathbf{H}_{\mathrm{RX}})$ generated via `common_generate_channels.m` (RNG stream aligned with `generate_channels.m`), a canonical diagonal SC unitary matrix $\boldsymbol{\Theta}_{\mathrm{init}}$ (unit-modulus random phases) is drawn, and a regularized MMSE precoder is computed and power-normalized:
   $$\mathbf{V}_{\mathrm{unscaled}} = (\mathbf{E}^H \mathbf{E} + N_0 \mathbf{I}_N)^{-1} \mathbf{E}^H, \quad \mathbf{V} = \sqrt{P_{\max}} \frac{\mathbf{V}_{\mathrm{unscaled}}}{\|\mathbf{V}_{\mathrm{unscaled}}\|_F}, \quad \mathbf{E} = \mathbf{H}_{\mathrm{RX}} \boldsymbol{\Theta}_{\mathrm{init}} \mathbf{H}_{\mathrm{TX}}.$$
   Using the same $\boldsymbol{\Theta}_{\mathrm{init}}$ and frozen $\mathbf{V}$ across SC, GC, FC and across reciprocal vs. general V-frozen (`general_fixedV_optimizer.m`) ensures a controlled, like-for-like comparison. All reported matched sum rates are evaluated with Member 4's shared `common_sinr.m` and `common_sumrate.m` (parity-verified against `calculate_sinr.m` and `calculate_sumrate.m`). The like-for-like fixed-$\mathbf{V}$ reciprocity gap per draw is $\Delta R_{\mathrm{fv}} = R_{\mathrm{gen,fv}} - R_{\mathrm{rec,fv}}$, and the primary project-guide **Percentage Gap** metric over any ensemble is defined from the ratio of mean rates:
   $$\text{Percentage Gap} = \frac{\overline{R}_{\mathrm{gen}} - \overline{R}_{\mathrm{rec}}}{\overline{R}_{\mathrm{gen}}} \times 100.$$
   *(Methodological note: Member 4's `src/common/run_matched_experiment.m` separately records the average of per-draw percentage gaps, `mean(100 * (gen_fv - rec_fv) ./ gen_fv)`. To maintain consistency with the project guide without altering Member 4's shared script, this report uses the ratio-of-means definition above as the primary percentage-gap metric and labels Member 4's per-draw average separately wherever cited.)*
2. **Fractional Programming (FP) Auxiliary Update (`fp_variables.m`):**  
   Update $(\boldsymbol{\tau}, \mathbf{y})$ in closed form for current $\boldsymbol{\Theta}$.
3. **Riemannian CGA Loop on the Block-Unitary Manifold (`run_cga_optimizer.m`):**  
   Maximize the penalized FP surrogate objective $F(\boldsymbol{\Theta})$ over $\mathcal{U}(R, R_g)$ using Polak–Ribière conjugate gradients, tangent-space projection, Armijo backtracking line search, and normalized QR retraction until $|\Delta F| < \epsilon_{\mathrm{tol}}$ or `iter == max_iter`.
4. **Exact Final Symmetrisation & Polar Projection (`enforce_symmetry_unitarity.m`):**  
   Enforce strict physical reciprocity and unitarity on every block $\boldsymbol{\Theta}_g$ via symmetrisation followed by SVD polar factor projection.
5. **Sum-Rate Evaluation (`calculate_sinr.m`, `calculate_sumrate.m`):**  
   Evaluate post-projection fixed-$\mathbf{V}$ sum rate $R(\boldsymbol{\Theta}_{\mathrm{final}}, \mathbf{V})$ (and, as a diagnostic, $R(\boldsymbol{\Theta}_{\mathrm{final}}, \mathbf{V}_2)$ with recomputed MMSE precoder $\mathbf{V}_2$).

---

## 3.3 Mathematical Formulation of Each Component

### 1. Fractional Programming (FP) Surrogate (`fp_variables.m`, `objective.m`)
With $\mathbf{E} = \mathbf{H}_{\mathrm{RX}} \boldsymbol{\Theta} \mathbf{H}_{\mathrm{TX}}$ and row $\mathbf{e}_k = \mathbf{E}_{k,:}$, user $k$'s SINR is
$$\gamma_k(\boldsymbol{\Theta}) = \frac{|\mathbf{e}_k \mathbf{v}_k|^2}{\sum_{i \ne k} |\mathbf{e}_k \mathbf{v}_i|^2 + N_0}, \qquad R_{\mathrm{sum}}(\boldsymbol{\Theta}) = \sum_{k=1}^K \log_2(1 + \gamma_k(\boldsymbol{\Theta})).$$
Applying the Lagrangian Dual Transform (LDT) and Quadratic Transform (QT) yields the surrogate objective (implemented in `objective.m` in bits/s/Hz, i.e. divided by $\ln 2$):
$$F_{\mathrm{FP}}(\boldsymbol{\Theta}, \boldsymbol{\tau}, \mathbf{y}) = \sum_{k=1}^K \left[ \log_2(1 + \tau_k) - \frac{\tau_k}{\ln 2} + \frac{1 + \tau_k}{\ln 2} \left( 2\Re\left\{ y_k^* \mathbf{e}_k \mathbf{v}_k \right\} - |y_k|^2 \left( \sum_{i=1}^K |\mathbf{e}_k \mathbf{v}_i|^2 + N_0 \right) \right) \right].$$
For fixed $(\boldsymbol{\Theta}, \mathbf{V})$, the closed-form optimal auxiliary variables (`fp_variables.m`) are:
$$\tau_k^\star = \gamma_k(\boldsymbol{\Theta}), \qquad y_k^\star = \frac{\mathbf{e}_k \mathbf{v}_k}{\sum_{i=1}^K |\mathbf{e}_k \mathbf{v}_i|^2 + N_0}.$$

### 2. Penalty Formulation (`objective.m`)
Rather than optimizing directly over the curved intersection $\mathcal{U}(R, R_g) \cap \mathbb{S}_R$, the method optimizes over the smooth block-unitary manifold $\mathcal{U}(R, R_g)$ while subtracting a quadratic Frobenius symmetry penalty:
$$F_{\mathrm{obj}}(\boldsymbol{\Theta}) = F_{\mathrm{FP}}(\boldsymbol{\Theta}, \boldsymbol{\tau}, \mathbf{y}) - \nu \|\boldsymbol{\Theta} - \boldsymbol{\Theta}^T\|_F^2,$$
with default penalty weight $\nu = 1.0$ (and $\nu = 0$ in `general_fixedV_optimizer.m` for the unconstrained unitary baseline).

### 3. Analytical Euclidean Gradient (`gradient_theta.m`)
For each diagonal block $\boldsymbol{\Theta}_g \in \mathbb{C}^{R_g \times R_g}$ ($g = 1, \dots, G$), let $\mathbf{H}_{\mathrm{TX},g} \in \mathbb{C}^{R_g \times N}$ and $\mathbf{H}_{\mathrm{RX},g} \in \mathbb{C}^{K \times R_g}$ denote the corresponding row and column slices, and $\mathbf{h}_{k,g} = (\mathbf{H}_{\mathrm{RX},g})_{k,:}^T \in \mathbb{C}^{R_g \times 1}$. Using the Wirtinger gradient convention $\nabla_{\boldsymbol{\Theta}_g} f = 2 \frac{\partial f}{\partial \boldsymbol{\Theta}_g^*}$, the FP sum-rate gradient block is:
$$\nabla_{\boldsymbol{\Theta}_g} F_{\mathrm{FP}} = \sum_{k=1}^K \frac{1 + \tau_k}{\ln 2} \left[ 2 y_k^* \mathbf{h}_{k,g} (\mathbf{H}_{\mathrm{TX},g} \mathbf{v}_k)^T - 2 |y_k|^2 \sum_{i=1}^K (\mathbf{e}_k \mathbf{v}_i)^* \mathbf{h}_{k,g} (\mathbf{H}_{\mathrm{TX},g} \mathbf{v}_i)^T \right]^*,$$
and the Wirtinger gradient of the symmetry penalty $-\nu \|\boldsymbol{\Theta}_g - \boldsymbol{\Theta}_g^T\|_F^2$ is:
$$\nabla_{\boldsymbol{\Theta}_g} \left( -\nu \|\boldsymbol{\Theta}_g - \boldsymbol{\Theta}_g^T\|_F^2 \right) = -4\nu (\boldsymbol{\Theta}_g - \boldsymbol{\Theta}_g^T).$$
Only the $G$ diagonal $R_g \times R_g$ blocks are populated (`grad(idx, idx)`), preserving block-diagonal sparsity identically.

### 4. Finite-Difference Gradient Verification (`test_gradient_fd.m`, `gradient_fd_check.txt`)
The analytical Wirtinger gradient is verified against central finite differences with perturbation step size $\delta = 10^{-6}$ across real and imaginary matrix entries:
$$\left[\nabla_{\mathrm{FD}} F_{\mathrm{obj}}\right]_{r,c} = \frac{F_{\mathrm{obj}}(\boldsymbol{\Theta} + \delta \mathbf{E}_{rc}) - F_{\mathrm{obj}}(\boldsymbol{\Theta} - \delta \mathbf{E}_{rc})}{2\delta} + j \frac{F_{\mathrm{obj}}(\boldsymbol{\Theta} + j\delta \mathbf{E}_{rc}) - F_{\mathrm{obj}}(\boldsymbol{\Theta} - j\delta \mathbf{E}_{rc})}{2\delta}.$$
Direct execution of `M4_Group9/Code/src/reciprocal/test_gradient_fd.m` in MATLAB R2025a (reproducible output preserved in [Results/diagnostics/gradient_fd_check.txt](../../Results/diagnostics/gradient_fd_check.txt)) yields relative Frobenius errors well below the $10^{-6}$ tolerance:
- **Single-Connected ($R_g = 1$):** Relative error = **$2.32 \times 10^{-9}$**
- **Group-Connected ($R_g = 4$):** Relative error = **$1.83 \times 10^{-9}$**
- **Fully-Connected ($R_g = 32$):** Relative error = **$4.55 \times 10^{-9}$**

These machine-precision-level checks confirm the exact correctness of the complex Wirtinger derivatives for both the FP surrogate objective and the quadratic symmetry penalty.

### 5. Tangent-Space Projection (`tangent_projection.m`)
At iterate $\boldsymbol{\Theta}_g \in \mathcal{U}(R_g)$, the Euclidean gradient block $\mathbf{G}_g$ is orthogonally projected onto the tangent space $T_{\boldsymbol{\Theta}_g}\mathcal{U}(R_g) = \{\mathbf{T}_g : \boldsymbol{\Theta}_g^H \mathbf{T}_g + \mathbf{T}_g^H \boldsymbol{\Theta}_g = \mathbf{0}\}$ via:
$$\mathcal{P}_{T_{\boldsymbol{\Theta}_g}}(\mathbf{G}_g) = \mathbf{G}_g - \boldsymbol{\Theta}_g \frac{\boldsymbol{\Theta}_g^H \mathbf{G}_g + \mathbf{G}_g^H \boldsymbol{\Theta}_g}{2}.$$
This yields the Riemannian gradient $\mathbf{r} = \mathcal{P}_{T_{\boldsymbol{\Theta}}}(\mathbf{G})$, and is also reused as the vector transport operator $\mathcal{T}_{\boldsymbol{\Theta} \to \boldsymbol{\Theta}_{\mathrm{new}}}(\cdot) = \mathcal{P}_{T_{\boldsymbol{\Theta}_{\mathrm{new}}}}(\cdot)$.

### 6. Retraction (`retraction.m`)
Given tangent search direction $\boldsymbol{\Xi}$ and step size $\alpha > 0$, each block $\mathbf{Y}_g = \boldsymbol{\Theta}_g + \alpha \boldsymbol{\Xi}_g$ is retracted back onto $\mathcal{U}(R_g)$ via QR decomposition with a diagonal phase normalization:
$$[\mathbf{Q}, \mathbf{R}_{\mathrm{mat}}] = \mathrm{qr}(\mathbf{Y}_g), \qquad \mathbf{D} = \mathrm{diag}(\mathbf{R}_{\mathrm{mat}}), \qquad \boldsymbol{\Theta}_{g,\mathrm{new}} = \mathbf{Q} \, \mathrm{diag}\!\left( \frac{D_m}{|D_m|} \right).$$
Normalizing by the phase of $\mathrm{diag}(\mathbf{R}_{\mathrm{mat}})$ forces positive-real diagonal entries in $\mathbf{R}_{\mathrm{mat}}$, eliminating arbitrary QR column phase flips and ensuring $\mathcal{R}_{\boldsymbol{\Theta}}(\mathbf{0}) = \boldsymbol{\Theta}$.

### 7. Polak–Ribière Conjugate Gradient Ascent (`run_cga_optimizer.m`)
Starting from $\boldsymbol{\Xi}^{(0)} = \mathbf{r}^{(0)}$, at each iteration $t$:
1. Transport both previous direction and previous gradient to $T_{\boldsymbol{\Theta}^{(t+1)}}\mathcal{U}$: $\boldsymbol{\Xi}_{\mathrm{tr}} = \mathcal{P}_{T_{\boldsymbol{\Theta}^{(t+1)}}}(\boldsymbol{\Xi}^{(t)})$ and $\mathbf{r}_{\mathrm{tr}} = \mathcal{P}_{T_{\boldsymbol{\Theta}^{(t+1)}}}(\mathbf{r}^{(t)})$.
2. Compute the non-negative Polak–Ribière coefficient:
   $$\beta_{\mathrm{PR}} = \max\!\left(0, \ \frac{\Re\,\mathrm{tr}\!\left(\mathbf{r}_{\mathrm{new}}^H (\mathbf{r}_{\mathrm{new}} - \mathbf{r}_{\mathrm{tr}})\right)}{\Re\,\mathrm{tr}\!\left(\mathbf{r}_{\mathrm{tr}}^H \mathbf{r}_{\mathrm{tr}}\right) + 10^{-16}}\right).$$
3. Form $\boldsymbol{\Xi}_{\mathrm{new}} = \mathbf{r}_{\mathrm{new}} + \beta_{\mathrm{PR}} \boldsymbol{\Xi}_{\mathrm{tr}}$, resetting $\boldsymbol{\Xi}_{\mathrm{new}} = \mathbf{r}_{\mathrm{new}}$ if $\Re\,\mathrm{tr}(\mathbf{r}_{\mathrm{new}}^H \boldsymbol{\Xi}_{\mathrm{new}}) \le 0$.
4. **Configurable Iteration Cap (M4 Task 1):** Maximum iterations `max_iter` is configurable via `opts.max_iter` (highest priority) or `p.max_iter`, defaulting to `8000` when omitted or empty. `general_fixedV_optimizer.m` delegates to `run_cga_optimizer` with $\nu = 0$, guaranteeing identical `max_iter` and `eps_tol` (`1e-8`) for fair comparison.

### 8. Armijo Line Search (`armijo_search.m`)
With $(\boldsymbol{\tau}, \mathbf{y}, \mathbf{V})$ frozen during the inner line search, Armijo backtracking seeks sufficient ascent on $F_{\mathrm{obj}}$:
$$F_{\mathrm{obj}}(\mathcal{R}_{\boldsymbol{\Theta}}(\alpha \boldsymbol{\Xi})) \ge F_{\mathrm{obj}}(\boldsymbol{\Theta}) + c \, \alpha \, \Re\,\mathrm{tr}(\mathbf{r}^H \boldsymbol{\Xi}).$$
Verified code parameters in `armijo_search.m`:
- Initial step size: $\alpha_0 = 1 / \|\boldsymbol{\Xi}\|_F$ (falls back to `1` if `Inf` or `NaN`)
- Sufficient increase coefficient: $c = 2 \times 10^{-11}$ (chosen small to accommodate physical-unit channel scaling where $PL_{\mathrm{BS-RIS}} \cdot PL_{\mathrm{RIS-user}} \sim 2.4 \times 10^{-11}$)
- Contraction factor: `0.75`
- Maximum backtracking steps per CGA iteration: `max_steps = 200`

### 9. Final Symmetrisation (`enforce_symmetry_unitarity.m`)
Because $-\nu \|\boldsymbol{\Theta} - \boldsymbol{\Theta}^T\|_F^2$ enforces symmetry softly during CGA, the iterate at termination typically retains a small symmetry residual ($\|\boldsymbol{\Theta}_{\mathrm{opt}} - \boldsymbol{\Theta}_{\mathrm{opt}}^T\|_F > 0$). Each block is first projected onto the complex symmetric subspace:
$$\boldsymbol{\Theta}_{\mathrm{sym},g} = \frac{1}{2}\left(\boldsymbol{\Theta}_g + \boldsymbol{\Theta}_g^T\right).$$

### 10. SVD-Based Polar Projection (`enforce_symmetry_unitarity.m`)
Each symmetrised block $\boldsymbol{\Theta}_{\mathrm{sym},g}$ is then projected onto the unitary group via SVD polar factor extraction:
$$\boldsymbol{\Theta}_{\mathrm{sym},g} = \mathbf{U} \boldsymbol{\Sigma} \mathbf{W}^H \implies \boldsymbol{\Theta}_{\mathrm{final},g} = \mathbf{U} \mathbf{W}^H.$$
Because the unitary polar factor of a complex symmetric matrix is itself complex symmetric, $\boldsymbol{\Theta}_{\mathrm{final},g}$ strictly satisfies both $\boldsymbol{\Theta}_{\mathrm{final},g}^H \boldsymbol{\Theta}_{\mathrm{final},g} = \mathbf{I}_{R_g}$ and $\boldsymbol{\Theta}_{\mathrm{final},g} = \boldsymbol{\Theta}_{\mathrm{final},g}^T$ to machine precision ($\sim 10^{-15}$ to $10^{-14}$).

---

## 3.4 Convergence Behavior and Distinct Stopping Conditions

### Evidence Separation: M2 Anchor vs. M3 Preliminary Checks vs. Pending M4 Runs
1. **M2 50-Draw Matched Anchor (Executed Baseline, Read-Only Reference Copy):** Stored in `M4_Group9/Results/anchor_rayleigh_R32_50draws/` (`per_draw.csv`, `summary.csv`, `config_used.txt`, copied verbatim from `Results/matched_rayleigh_R32_50draws/`). Configuration: $R=32, \nu=1.0, \epsilon_{\mathrm{tol}}=10^{-8}, \texttt{max\_iter}=8000$, canonical SC start and frozen initial MMSE precoder:
   - **SC ($R_g = 1$):** Mean `296.4` iterations (`std 323.1`, range `15–1615`), `0/50` cap hits, mean `rec_fv = 8.5166`, `gen_fv = 8.5166`, `0.0000 bps/Hz` reciprocity gap (**`0.00%`**).
   - **GC ($R_g = 4, G = 8$):** Mean `1421.3` iterations (`std 2378.1`, range `27–8000`), **`4/50` cap hits** (Draws `21, 26, 31, 34`), mean `rec_fv = 9.9089` (`rec_v2 = 10.4492`), `gen_fv = 10.0119` (`gen_v2 = 10.5748`), mean reciprocity gap `0.1030 bps/Hz`, giving a primary Percentage Gap of **`1.03%`** (`1.0285%` from `(10.0119 - 9.9089) / 10.0119 * 100`; Member 4's per-draw percentage mean in `summary.csv` is `0.88%`). General V-frozen (`nu=0`) averaged `746.3` iterations (`max 6375`, `0/50` cap hits).
   - **FC ($R_g = 32, G = 1$):** Mean `569.8` iterations (`std 794.0`, range `86–4395`), `0/50` cap hits, mean `rec_fv = 10.3105` (`rec_v2 = 10.8568`), `gen_fv = 10.3313` (`gen_v2 = 10.8782`), mean reciprocity gap `0.0209 bps/Hz`, giving a primary Percentage Gap of **`0.20%`** (`0.2021%` from `(10.3313 - 10.3105) / 10.3313 * 100`; Member 4's per-draw percentage mean in `summary.csv` is `0.17%`).
   - **Draw-Level Sign and Tie Classification (`tol = 1e-4 bps/Hz`):** Both solvers are non-convex local optimizers, so small negative gaps (`gen_fv < rec_fv`) reflect optimizer stationary-point or solver-tolerance differences rather than a physical advantage of reciprocity. Using a consistent numerical tie tolerance of $\tau_{\mathrm{tie}} = 10^{-4}\text{ bps/Hz}$ on `M4_Group9/Results/anchor_rayleigh_R32_50draws/per_draw.csv`:
     - **FC ($50$ draws):** Raw `gap_fv < 0` occurs in **`7/50`** draws (`Draw 4: -9.89e-6`, `Draw 7: -2.84e-8`, `Draw 9: -8.44e-5`, `Draw 13: -0.1299`, `Draw 25: -2.58e-6`, `Draw 34: -5.23e-5`, `Draw 49: -0.00256`). Five of those seven magnitudes lie below $10^{-4}\text{ bps/Hz}$ (numerical ties). Classifying by $\tau_{\mathrm{tie}} = 10^{-4}$: **`2` Reciprocal better** (`Draw 13` at `-0.1299` — the sole substantial negative case `~ -0.13 bps/Hz` — and `Draw 49` at `-0.00256`), **`26` Numerical ties** (`|gap_fv| <= 1e-4`: 5 negative + 21 positive), and **`22` General better** (`gap_fv > 1e-4`). *(Discrepancy note: `M4_Group9/Code/src/common/README.md` states `"6 of 50 for FC, at most 0.27 bps/Hz"`; the CSV actually shows `7` raw negative FC draws, max FC negative magnitude `0.1299 bps/Hz`, and `0.2706 bps/Hz` occurs in GC Draw 13.)*
     - **GC ($50$ draws):** `2/50` raw negative (`Draw 13: -0.2706`, `Draw 50: -0.1878`) $\implies$ **`2` Reciprocal better**, **`10` Numerical ties**, and **`38` General better**.
     - **SC ($50$ draws):** **`50` Numerical ties** (`0.0000` gap).
### Crucial Distinction: Armijo Limit vs. CGA Iteration Cap
Two distinct stopping conditions exist at different levels of the solver and **must not be conflated or treated as contradictory**:
1. **Armijo Line-Search Backtracking Limit (`max_steps = 200`):**  
   This inner-loop safeguard in `armijo_search.m` caps the number of $\alpha \leftarrow 0.75\alpha$ step contractions within a *single* CGA iteration (`hist.armijo_max_hit`). Because M2's matched `per_draw.csv` did not record inner Armijo hit counts, the 3 M2 anchor rows ($R=32$) in `sweep_summary.csv` contain `NaN`. In contrast, the M4 pipeline explicitly exports `armijo_max_hits` across all scripts (`run_cga_optimizer.m`, `general_fixedV_optimizer.m`, `run_matched_experiment.m`, `run_cap_diagnostic.m`, `run_nu_sensitivity.m`, and `run_ris_size_sweep.m`). Across all **9 M4-executed rows**, inner Armijo limit hits are strictly **0**.
2. **Outer CGA Iteration Cap (`max_iter = 8000`, reached in `4/50` M2 Matched GC runs):**  
   This outer-loop budget in `run_cga_optimizer.m` stops the CGA sequence if $|\mathrm{obj}_{\mathrm{new}} - \mathrm{obj}_{\mathrm{val}}| < \epsilon_{\mathrm{tol}} = 10^{-8}$ is not achieved within 8,000 iterations (`term_reason = 'hit_max_iter'`). In the M2 matched GC anchor, Draws `21, 26, 31, 34` reached the `max_iter = 8000` outer iteration cap before satisfying the $|\Delta F| < 10^{-8}$ objective-change stopping tolerance.

Thus, inner Armijo limit hits and outer CGA `max_iter` cap hits measure two independent stopping mechanisms: one checks step-size acceptance within an iteration, while the other caps total outer iterations against the $\epsilon_{\mathrm{tol}} = 10^{-8}$ objective-change criterion.

2. **M3 Preliminary E6 Evidence (Copied Prior M3 Reference — Historical Context):** Copied verbatim into `M4_Group9/Results/diagnostics/M3_E6_reference/E6_per_run.csv` (original `M3/results/E6_nu_sweep/E6_per_run.csv`, cap `25,000`, $\nu = 1$, reciprocal-only, 4 capped GC draws): Draws `21, 26, 31` reached $|\Delta F| < 10^{-8}$ at `19,303`, `14,053`, and `14,704` iterations, while Draw `34` still hit `25,000`.

3. **M4 Executed Findings (Complete Experimental Evidence):**
   - **Task 2: Iteration-Cap Diagnostic (`run_cap_diagnostic.m`, `cap_check_summary.csv`):**
     Tested across 10 GC draws ($R_g=4, R=32$) comparing `max_iter = 8000` vs `max_iter = 40000`:
     - *Ordinary Draws (1–6):* Rates are identical between 8k and 40k caps (`rec_rate = 7.6822 bps/Hz`, `gen_rate = 7.7110 bps/Hz`, gap `0.0288 bps/Hz`, ratio-of-means `0.37%`). Mean reciprocal iterations was `319.2`, general iterations `592.5`.
     - *M2-Capped Draws (21, 26, 31, 34):* With the cap extended to 40,000, Draws 21, 26, and 31 successfully converged to tolerance $|\Delta F| < 10^{-8}$ at `19,303`, `14,053`, and `14,704` iterations, with rate improvements of only $+0.0016$, $+0.0039$, and $+0.0012$ bps/Hz. Draw 34 hit the 40,000 cap (`delta_rec = +0.0125 bps/Hz`). Across the 4 capped draws, mean reciprocal rate increased by merely $+0.0048$ bps/Hz (`12.2557` $\to$ `12.2605` bps/Hz), shifting the mean gap from $0.2039$ to $0.1991$ bps/Hz ($1.64\% \to 1.60\%$).
     - *Armijo Backtracking Hits:* Exactly `0` across all 10 draws for both solvers.
     - *Conclusion:* Capping iterations at 8,000 preserves over $99.96\%$ of asymptotic rate accuracy while avoiding tens of thousands of trailing iterations on slow-converging draws.
   - **Task 3: Penalty Sensitivity (`run_nu_sensitivity.m`, `nu_sensitivity_summary.csv`):**
     Evaluated over 20 independent draws (seeds 1–20) for GC ($R_g=4$) and FC ($R_g=32$) across $\nu \in \{0.1, 1.0, 10.0\}$:
     - *GC ($R_g=4$) Empirical Performance:*
       - Mean reciprocal rates: $\nu = 0.1 \to 9.240 \pm 0.462$, $\nu = 1.0 \to 9.207 \pm 0.463$, $\nu = 10.0 \to 9.241 \pm 0.468$ bps/Hz.
       - The paired difference between $\nu = 1.0$ and $\nu = 0.1$ is **$-0.032 \pm 0.050$ bps/Hz**. Given this paired variation, performance across all three $\nu$ values is **statistically indistinguishable**.
       - *Important GC Seed 11 Anomaly:* At $\nu = 1.0$, GC Seed 11 terminates after only 27 iterations due to a premature tolerance stop ($|\Delta F| < 10^{-8}$), leaving an anomalous gap of **$0.932$ bps/Hz** (reciprocal rate $9.191$ vs general rate $10.123$ bps/Hz). In contrast, on the exact same channel, $\nu = 0.1$ converges after 158 iterations with a gap of only $0.037$ bps/Hz, and $\nu = 10.0$ yields a gap of $0.013$ bps/Hz. The same anomaly occurs in the M2 anchor dataset (Draw 11 gap is $0.932$ bps/Hz), inflating the overall 50-draw GC mean gap by approximately **$0.02$ bps/Hz** ($0.932 / 50 \approx 0.0186$ bps/Hz).
     - *FC ($R_g=32$) Empirical Performance:*
       - $\nu = 1.0$ beats $\nu = 0.1$ by **$+0.019 \pm 0.008$ bps/Hz**, avoiding the substantial post-projection distortion ($0.0177$ bps/Hz projection loss) seen at $\nu = 0.1$.
       - $\nu = 1.0$ and $\nu = 10.0$ yield identical post-projection rates to six decimal places ($9.6226$ bps/Hz).
     - *Computational Stalling at $\nu = 10.0$:*
       - Although $\nu = 10.0$ minimizes projection cost ($< 0.0003$ bps/Hz), it stiffens the Riemannian gradient severely. For GC, **7 out of 20 draws hit the 8,000 cap** (mean iterations spike from $845.8$ to $4971.8$). In the 25k subset, **2 of 4 seeds still hit the 25,000 cap**.
     - *Conclusion on $\nu = 1.0$:* $\nu = 1.0$ is an **adequate practical engineering default, not a proven mathematical optimum**. It avoids the FC projection loss of $\nu = 0.1$ while avoiding the heavy convergence stalling and cap-hit inflation of $\nu = 10.0$.
   - **Task 4: Full Multi-Size RIS Sweep (`run_ris_size_sweep.m`, `sweep_summary.csv`):**
     Complete 50-draw Monte Carlo sweep across $R \in \{16, 32, 48, 64\}$:
     - *Single-Connected ($R_g=1$):* Sum rates scale with $R$ from $5.4341 \pm 0.1738$ ($R=16$) to $8.5166 \pm 0.2675$ ($R=32$), $10.9144 \pm 0.2499$ ($R=48$), and $11.8942 \pm 0.3506$ ($R=64$) bps/Hz. Reciprocity gap is analytically and numerically 0.
     - *Group-Connected ($R_g=4$):* Reciprocal sum rates scale as $6.6438 \pm 0.2039$ ($R=16$), $9.9089 \pm 0.2984$ ($R=32$), $12.3227 \pm 0.2785$ ($R=48$), and $13.2184 \pm 0.3807$ ($R=64$) bps/Hz. The reciprocity gap remains tightly bounded between $0.10$ and $0.16$ bps/Hz ($0.1397$ bps/Hz / $2.06\%$ at $R=16$; $0.1030$ bps/Hz / $1.03\%$ at $R=32$; $0.1555$ bps/Hz / $1.25\%$ at $R=48$; $0.1548$ bps/Hz / $1.16\%$ at $R=64$).
     - *Fully-Connected ($R_g=R$):* Reciprocal sum rates reach $7.0328 \pm 0.2312$ ($R=16$), $10.3105 \pm 0.3218$ ($R=32$), $12.7789 \pm 0.2996$ ($R=48$), and $13.6150 \pm 0.4103$ ($R=64$) bps/Hz. The reciprocity gap remains minuscule across all sizes ($0.0145$ bps/Hz / $0.21\%$ at $R=16$; $0.0209$ bps/Hz / $0.20\%$ at $R=32$; $0.0433$ bps/Hz / $0.34\%$ at $R=48$; $0.1133$ bps/Hz / $0.82\%$ at $R=64$).
     - *SC Control Gain:* BD-RIS architectures consistently provide large beamforming power gains over SC: GC adds $+1.21$ to $+1.41$ bps/Hz, while FC adds $+1.60$ to $+1.86$ bps/Hz over SC across all sizes.
     - *Iteration-Cap Hits and Capped-Draw Sensitivity:*
       The number of draws reaching the 8,000-iteration cap in `sweep_summary.csv` is:

       | $R$ | GC Reciprocal Cap Hits | GC General Cap Hits | FC Reciprocal Cap Hits | FC General Cap Hits |
       |---|---:|---:|---:|---:|
       | **16** | 4 | 0 | 0 | 0 |
       | **48** | 12 | 3 | 3 | 0 |
       | **64** | 5 | 2 | 1 | 4 |

       Cap-limited results must be interpreted cautiously:
       - For $R=48$ GC, excluding draws where either solver reached the cap changes the mean gap from **$0.1555$ to $0.1388$ bps/Hz** (with **38 uncapped draws retained**).
       - For $R=64$ GC, excluding capped draws changes the mean gap from **$0.1548$ to $0.1398$ bps/Hz** (with **43 uncapped draws retained**).
       - For $R=64$ FC, the unconstrained general solver hit the cap in **4 draws** (while reciprocal hit in 1 draw); thus, the reported gap of $0.1133$ bps/Hz may be slightly understated.
       Primary reported benchmarks retain all 50 draws to preserve an unbiased Monte Carlo protocol, while the uncapped comparison provides sensitivity validation.
     - *Negative Per-Draw Gap Analysis ($\text{Gap} < -10^{-4}$ bps/Hz):*
       Across the 450 runs in the M4 sweep, a negative gap occurs in **16 draws**:
       - **9 draws are small ($\le 0.03$ bps/Hz):** 5 draws in $R=48$ FC (Draws 12, 16, 26, 31, 42), 1 draw in $R=64$ GC (Draw 11: $-0.0002$), and 3 draws in $R=64$ FC (Draws 6, 31, 42).
       - **7 draws exceed $0.03$ bps/Hz:** $R=16$ FC Draw 2 ($-0.0918$), $R=48$ FC Draw 37 ($-0.2750$), $R=64$ GC Draw 10 ($-0.6196$), $R=64$ GC Draw 27 ($-0.1596$), $R=64$ FC Draw 2 ($-0.0756$), $R=64$ FC Draw 30 ($-0.1868$), and $R=64$ FC Draw 43 ($-0.1419$).
       - *Investigation of $R=64$ GC Draw 10 (largest magnitude: $-0.620$ bps/Hz):* In this draw, the general solver did not hit the 8,000 cap; rather, it terminated after only 111 iterations due to a premature tolerance stop ($|\Delta F| < 10^{-8}$ at rate $13.8627$ bps/Hz). The reciprocal solver continued taking accepted steps for 1,623 iterations, reaching $14.4822$ bps/Hz post-projection. Because intermediate landscape curvature is unrecorded, whether this reflects an early plateau on the unconstrained manifold or convergence to a distinct stationary point cannot be established from the available evidence and remains unresolved.
       - *General Interpretation:* Because both solvers navigate non-convex landscapes from initial SC MMSE beamforming, negative gaps indicate optimizer stationary-point variations rather than a physical advantage of reciprocity.
     - *Armijo Robustness:* Inner Armijo limit hits are strictly 0 across all 50 draws in all 9 M4-executed rows (the 3 M2 anchor rows contain `NaN` as Armijo hits were unrecorded in M2).

---

## 3.5 Limitations, Assumptions, and M3 Stretch Context

1. **Non-Convexity & Local Optima:** Sum-rate maximization over $\mathcal{U}(R, R_g)$ is non-convex. Single-start runs (`n_restarts = 1`) from canonical SC phase initialization converge to a stationary point of the penalized FP surrogate, not a certified global optimum.
2. **Soft Penalty + Post-Projection Trade-off:** Optimizing with $-\nu \|\boldsymbol{\Theta} - \boldsymbol{\Theta}^T\|_F^2$ followed by `enforce_symmetry_unitarity` introduces a projection rate loss that scales approximately as $1/\nu$ (in copied prior M3 E6 data at `M4_Group9/Results/diagnostics/M3_E6_reference/E6_summary.csv`: $0.0994\text{ bps/Hz}$ at $\nu=0.1$ vs $0.00876\text{ bps/Hz}$ at $\nu=1.0$). Conversely, overly large $\nu$ (e.g., $\nu \ge 10$) stiffens the penalty gradient and causes CGA cap hits (`4/4` at `25,000` in M3 E6).
3. **Frozen Precoder ($\mathbf{V}$) Assumption:** The fixed-$\mathbf{V}$ pipeline freezes $\mathbf{V}$ at the initial SC MMSE precoder to isolate the passive scattering reciprocity gap cleanly. While recomputing MMSE $\mathbf{V}_2$ after optimization increases absolute rates (e.g., GC M2 mean `9.91` $\to$ `10.45` bps/Hz), it does not jointly optimize $(\mathbf{V}, \boldsymbol{\Theta})$.
4. **Perfect CSI Assumption:** Both $\mathbf{H}_{\mathrm{TX}}$ and $\mathbf{H}_{\mathrm{RX}}$ are assumed perfectly known without channel estimation error or pilot overhead.
5. **M3 Joint Reciprocal Design (Copied Prior M3 Stretch Evidence Only):** `M4_Group9/Code/src/reciprocal/reciprocal_joint_optimizer.m` and prior M3 Experiment E8 (using Li's surrogate, polar retraction, `c = 1e-4`, `max_outer = 300`, `max_cg = 30`) are preserved as supporting evidence copied into `M4_Group9/Results/diagnostics/M3_E8_reference/`, not replaced or rerun in M4. Its documented limitations remain: `50/50` SC and GC runs and `47/50` FC runs hit the `300` outer-iteration cap (likewise `50/50` SC/GC and `49/50` FC for Li's general baseline), and the updated-MMSE-$\mathbf{V}$ post-projection rate is diagnostic only and not an apples-to-apples comparison against Li's jointly optimized precoder.

