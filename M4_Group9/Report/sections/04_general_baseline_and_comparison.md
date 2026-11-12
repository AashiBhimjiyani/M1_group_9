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
| Qualitative trends (rate grows with Pmax; FC >= GC >= SC) | `nonreciprocal/validate_li_trends.m` via `experiments/run_li_trend_validation.m`, 20 draws | TODO: result in `Results/diagnostics/li_trends/results/` |
| Power-convention check (Pmax = 23 dBm, total) | `experiments/run_power_convention_check.m`, 50 draws | TODO: result in `Results/diagnostics/power_convention/` |

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
| Power, Pmax = 0, 5, 10, 15 dBm (20 dBm is the anchor) | `Results/sweep_power/` | TODO |
| N = K = 3, 4, 6 (N = K = 2 is the anchor) | `Results/sweep_antennas/` | TODO. GC block size is smaller than N + K for N = K = 3 and 4. |
| Power convention check, Pmax = 23 dBm | `Results/diagnostics/power_convention/` | TODO |
| Li trend validation, N = K = 4, 20 draws | `Results/diagnostics/li_trends/` | TODO |

## 4.6 Known open question

The reciprocal FC rate in the M2 anchor (10.32 bps/Hz, 50 draws) is well below the roughly 14 bps/Hz in the source paper's Fig. 3. The power-convention check tests one candidate explanation (per-user versus total power). It does not tune any parameter. Whatever the result, it is reported as a tested hypothesis; the cause is not yet established.
