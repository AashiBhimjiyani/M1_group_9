# 4. General Baseline and Comparison Protocol

*Owner: Member 3. Numbers marked TODO come from `Results/` once the sweeps finish. Nothing here is a measured result until it is traced to a file there.*

## 4.1 Baseline method

The general (non-reciprocal-capable) baseline follows Li, Shen and Clerckx, "Beyond Diagonal RIS: From Transmitting and Reflecting Modes to Single-, Group-, and Fully-Connected Architectures" (arXiv 2205.02866), Algorithms 1 and 2, reflective mode only (K_t = 0). The scattering matrix is block-diagonal and unitary, with block size Rg = 1 (SC), Rg = R/G (GC) or Rg = R (FC). No symmetry constraint is imposed, so Theta need not equal Theta^T.

Two modes run from the same channel, the same start and the same initial precoder:

| Mode | Code | Purpose |
| --- | --- | --- |
| Joint (paper-faithful) | `nonreciprocal/li_joint_optimizer.m` (Li Algorithm 1) | Baseline comparable with the paper. Updates V and Theta together, so it is not like-for-like with the reciprocal method. |
| Matched, V-frozen | `nonreciprocal/general_fixedV_optimizer.m` (reciprocal CGA with nu = 0, plus plain unitary projection) | The like-for-like comparison for the reciprocity gap. |

The reciprocity gap is always computed inside the matched mode: gap = general (V-frozen) minus reciprocal (V-frozen). The joint-versus-frozen difference is an effect of updating V, not of reciprocity.

## 4.2 Deviations from the paper

Copied from `nonreciprocal/README.md`:

1. Reflective mode only (K_t = 0, Phi_t = 0). No direct BS-user link.
2. All G blocks are updated jointly on the product manifold, not one group at a time. The stationary points are the same.
3. The tangent projection is the standard block-unitary one, Gamma - Theta sym(Theta^H Gamma). Eq. (31) in the arXiv text is not the unitary-manifold projection as printed.
4. The retraction is the polar factor via SVD.
5. Channels are rescaled internally (noise = 1) for numerical conditioning. SINR is invariant to this. Final rates are evaluated with the shared `common_sinr` and `common_sumrate` in physical units.

## 4.3 Validation evidence

| Check | Source | Status |
| --- | --- | --- |
| Finite-difference gradient check, surrogate vs eq. (21a), monotone ascent, unitarity about 1e-15, power constraint, block structure | `nonreciprocal/test_general_baseline.m` | TODO: record PASS/FAIL and observed output in `Results/validation_log.md` (Member 1) |
| Qualitative trends (rate grows with Pmax; FC >= GC >= SC) | `nonreciprocal/validate_li_trends.m` via `experiments/run_li_trend_validation.m`, 20 draws | PASS. Mean rate (bps/Hz) at 0, 5, 10, 15, 20 dBm: SC 1.94, 3.80, 6.85, 11.29, 16.92; GC 2.68, 5.31, 9.48, 15.10, 21.00; FC 3.00, 6.06, 10.89, 16.74, 22.97. Source: `Results/diagnostics/li_trends/results/validate_li_trends.mat` |
| Power-convention check (Pmax = 23 dBm, total) | `experiments/run_power_convention_check.m`, 50 draws | Done, 0 failed runs. Reciprocal FC = 12.17 ± 0.34 bps/Hz. Gap (general minus reciprocal, V-frozen): GC 0.101 ± 0.019 (0.73 ± 0.14 %), FC 0.023 ± 0.012 (0.17 ± 0.09 %). Source: `Results/diagnostics/power_convention/P23dBm/` |

## 4.4 Fair-comparison protocol

Every matched comparison in this report uses the same:

- channel realisation: `rng(seed_base + d, 'twister')`, then `common_generate_channels`
- start matrix: `common_init_theta`
- initial precoder: `common_mmse_beamformer` at that start
- transmit power budget, noise, path loss, and metric functions (`common_sinr`, `common_sumrate`)
- iteration cap (8000 for the CGA; 300 outer iterations for the joint design)
- seed range: draws 1 to 50 (`seed_base = 0`)

Because the reciprocal and general matched runs share all of the above, the difference in their rates is attributable to the symmetry constraint (plus the penalty and projection used to enforce it).

## 4.5 Sweeps run for the general baseline

| Sweep | Folder | Result |
| --- | --- | --- |
| Power, Pmax = 0, 5, 10, 15 dBm (20 dBm is the anchor) | `Results/sweep_power/` | 50 draws, 0 failed runs per point. Gap (general minus reciprocal, V-frozen), mean ± SE. GC: 0.148 ± 0.028 (10.3 ± 2.5 %) at 0 dBm, 0.156 ± 0.010 (5.1 ± 0.3 %) at 5 dBm, 0.147 ± 0.017 (2.9 ± 0.3 %) at 10 dBm, 0.125 ± 0.022 (1.6 ± 0.3 %) at 15 dBm. FC: 0.0096 ± 0.0018 (0.57 ± 0.12 %), 0.0170 ± 0.0029 (0.51 ± 0.09 %), 0.0051 ± 0.0022 (0.09 ± 0.05 %), 0.0067 ± 0.0057 (0.07 ± 0.06 %). SC gap is 0 by construction. |
| N = K = 3, 4, 6 (N = K = 2 is the anchor) | `Results/sweep_antennas/` | 50 draws, 0 failed runs per point, Pmax = 20 dBm. Gap, mean ± SE. GC: 0.591 ± 0.044 (5.2 ± 0.3 %) at N = K = 3, 1.068 ± 0.073 (9.1 ± 0.8 %) at N = K = 4, 1.683 ± 0.061 (15.0 ± 0.4 %) at N = K = 6. FC: 0.085 ± 0.023 (0.72 ± 0.17 %), 0.110 ± 0.024 (0.93 ± 0.21 %), 0.292 ± 0.039 (2.10 ± 0.28 %). GC block size is smaller than N + K for N = K = 3 and 4. |
| Power convention check, Pmax = 23 dBm | `Results/diagnostics/power_convention/` | Done. See 4.3. |
| Li trend validation, 20 draws | `Results/diagnostics/li_trends/` | PASS. See 4.3. |

## 4.6 Known open question

The reciprocal FC rate in the M2 anchor (10.32 bps/Hz, 50 draws) is well below the roughly 14 bps/Hz in the source paper's Fig. 3. The power-convention check tests one candidate explanation (per-user versus total power). It does not tune any parameter. Whatever the result, it is reported as a tested hypothesis; the cause is not yet established.

Result of the 23 dBm check: the reciprocal FC rate is 12.17 ± 0.34 bps/Hz (50 draws). That is higher than the 20 dBm anchor (10.32), so the total-power convention narrows the gap to the paper's ~14 bps/Hz, but it does not close it. The rate changes were not tuned to match the paper. The cause remains open.
