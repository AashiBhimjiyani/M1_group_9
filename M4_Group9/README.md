# M4_Group9 — Quantifying the Sum-Rate Cost of Reciprocity in Beyond-Diagonal RIS-Aided MU-MISO Systems

**Milestone 4 — Group 9, Ahmedabad University**
Aashi Bhimjiyani (AU2440027), Kahaan Shah (AU2440047), Prakshal Shah (AU2440265), Samridhi Mehrotra (AU2440033)

The project quantifies the sum-rate cost of enforcing reciprocity (a symmetric scattering matrix, Θ = Θᵀ) on a lossless BD-RIS, for single-, group- and fully-connected architectures, against a general (non-reciprocal) unitary baseline under matched channels, start matrices and frozen MMSE precoders.

**Final report:** [`Report/M4_G9_Report.pdf`](Report/M4_G9_Report.pdf) (figures in `Report/figures/`).

## Contributions

| Member | Contribution |
|---|---|
| Aashi Bhimjiyani | Reciprocal Riemannian optimiser; configurable iteration cap, cap diagnostic, penalty sensitivity, RIS-size sweep (R = 16, 48, 64) |
| Kahaan Shah | General non-reciprocal baseline (Li et al.); power sweep, N = K sweep, power-convention check, baseline validation |
| Prakshal Shah | Common framework (channels, metrics, matched runner); gap statistics with bootstrap CIs, figures, smoke test |
| Samridhi Mehrotra | Literature and SOTA positioning, problem formulation, Rician and group-size runs, results analysis, report integration |

## Directory structure

```text
M4_Group9/
├── README.md
├── Code/
│   ├── README.md                 <- code layout, dependencies, how to run
│   └── src/
│       ├── setup_paths.m
│       ├── configs/              <- default_config.m
│       ├── common/               <- shared channels, precoder, metrics, matched runner
│       ├── reciprocal/           <- reciprocal Riemannian CGA optimiser
│       ├── nonreciprocal/        <- general baseline and Li joint design
│       ├── experiments/          <- sweep drivers, gap analysis, figures
│       └── tests/                <- framework, anchor-statistics and smoke tests
├── Data/README.md                <- synthetic channel generation notes
├── Report/
│   ├── M4_G9_Report.pdf          <- final report
│   └── figures/
├── Results/
│   ├── README.md                 <- results index
│   ├── anchor_rayleigh_R32_50draws/
│   ├── rician_anchor/
│   ├── sweep_power/              <- P00, P05, P10, P15 dBm
│   ├── sweep_antennas/           <- N = K = 3, 4, 6
│   ├── sweep_ris_size/           <- R = 16, 48, 64
│   ├── sweep_group_size/
│   ├── diagnostics/              <- cap check, nu sensitivity, power convention, validation logs
│   └── figures/
└── Video/M4_Group9_video_Link.txt
```

## Running

```matlab
cd('M4_Group9/Code/src'); setup_paths;
m4_smoke_test            % framework tests + anchor statistics
```

Each experiment driver in `Code/src/experiments/` writes its outputs to the matching folder under `Results/`; see `Code/README.md`.

Earlier milestone folders (`M1_Group9/`, `M2/`, `M3/`) are kept unchanged as baselines.
