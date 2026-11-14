# M4_Group9 — Quantifying the Sum-Rate Cost of Reciprocity in Beyond-Diagonal RIS-Aided MU-MISO Systems

**Milestone:** Milestone 4 (M4)  
**Group:** Group 9  
**Repository Working Directory:** `M4_Group9/`  

---

## 1. Project Overview

This project investigates and quantifies the sum-rate cost of electromagnetic reciprocity in Beyond-Diagonal Reconfigurable Intelligent Surface (BD-RIS) aided Multi-User MISO (MU-MISO) wireless communication systems. By enforcing the physical constraint that passive, lossless BD-RIS scattering matrices must be both unitary and complex symmetric ($\boldsymbol{\Theta} = \boldsymbol{\Theta}^T$), we benchmark reciprocal performance against general (non-reciprocal) unitary bounds across Single-Connected (SC), Group-Connected (GC), and Fully-Connected (FC) architectures.

---

## 2. Group 9 Member Responsibilities and Ownership

| Member | Role | Primary Milestone 4 Responsibilities | Status |
|---|---|---|---|
| **Member 1** | Project Coordination & Documentation Lead | Milestone synthesis, presentation coordination, repository management, final video delivery. | In Progress (Video link pending) |
| **Member 2** | Reciprocal Optimizer Lead | Reciprocal Riemannian CGA optimizer, iteration-cap diagnostic, penalty sensitivity ($\nu$), multi-size BD-RIS sweep ($R \in \{16, 48, 64\}$), reciprocal methodology report. | Completed & Verified |
| **Member 3** | Non-Reciprocal Baseline Lead | General unitary fixed-$V$ baseline (`general_fixedV_optimizer.m`), Li et al. joint baseline evaluation, non-reciprocal comparison report. | Completed & Verified |
| **Member 4** | Framework Integration & Common Metrics Lead | Shared channel/precoder/metric framework (`src/common/`), benchmark configuration, cross-member verification, final report assembly. | Integration Active |

*For Member 2's detailed work log, see [Report/sections/member2_work_log.md](Report/sections/member2_work_log.md).*

---

## 3. Directory Structure

```text
M4_Group9/
├── README.md                              <- Team project overview and contribution table
├── Code/
│   ├── README.md                          <- Code layout, dependencies, and execution guide
│   └── src/
│       ├── setup_paths.m                  <- Environment and path configuration
│       ├── configs/                       <- Simulation configuration (default_config.m)
│       ├── common/                        <- Member 4 shared channel, precoder, and metric framework
│       ├── reciprocal/                    <- Member 2 reciprocal Riemannian CGA optimizer
│       ├── nonreciprocal/                 <- Member 3 general baseline optimizers
│       ├── experiments/                   <- M4 experiment drivers (cap check, nu sensitivity, sweeps)
│       └── tests/                         <- Common framework parity test suite
├── Results/
│   ├── validation_log_member2.md          <- Member 2 verification test execution log
│   ├── anchor_rayleigh_R32_50draws/       <- M2 R=32 50-draw benchmark anchor reference
│   ├── diagnostics/
│   │   ├── task1_max_iter_diff.md         <- Task 1 code change diff
│   │   ├── cap_check/                     <- Task 2 iteration-cap diagnostic results
│   │   ├── nu_sensitivity/                <- Task 3 penalty sensitivity results
│   │   ├── gradient_fd_check.txt          <- Finite-difference gradient verification output
│   │   ├── M3_E6_reference/               <- Prior M3 E6 reference data (read-only)
│   │   └── M3_E8_reference/               <- Prior M3 E8 reference data (read-only)
│   └── sweep_ris_size/
│       ├── sweep_summary.csv              <- Consolidated 12-row sweep summary table
│       ├── R16/                           <- 50-draw results for R=16
│       ├── R48/                           <- 50-draw results for R=48
│       └── R64/                           <- 50-draw results for R=64
├── Report/
│   └── sections/
│       ├── 03_reciprocal_method.md        <- Member 2 Reciprocal Optimization Methodology
│       └── member2_work_log.md            <- Member 2 detailed work log and technical record
├── Data/
│   └── README.md                          <- Synthetic channel generation and data notes
└── Video/
    └── M4_Group9_video_Link.txt           <- Milestone video presentation link (pending)
```

---

## 4. Overall Milestone 4 Task Status

| Component | Task | Status | Notes |
|---|---|---|---|
| **Member 2** | Task 1: Configurable Iteration Cap | **Completed and Tested** | Prioritized overrides in `run_cga_optimizer.m`, backward compatible |
| **Member 2** | Task 2: Cap Diagnostic (8k vs 40k) | **Completed and Tested** | 10 GC draws evaluated; negligible rate difference ($< 0.005$ bps/Hz) |
| **Member 2** | Task 3: Penalty Sensitivity ($\nu$) | **Completed and Tested** | 20 draws GC & FC evaluated; $\nu=1.0$ validated as practical default |
| **Member 2** | Task 4: Multi-Size Sweep ($R=16,48,64$) | **Completed and Tested** | 50 draws each for SC, GC, FC merged into `sweep_summary.csv` |
| **Member 2** | Task 5: Methodology Section 03 | **Completed and Tested** | Real empirical data, mathematical formulation, and limitation analysis |
| **Member 3** | Non-Reciprocal Baseline Integration | **Completed and Tested** | Matched fixed-$V$ baseline integrated into sweep pipeline |
| **Member 4** | Shared Framework Integration | **Completed and Tested** | Unique path resolution, zero function shadowing |
| **Team Stretch**| Joint Reciprocal Design | **Partially Completed / Unfinished** | Prior M3 E8 reference preserved; outer-iteration cap limitations documented |
| **Team Deliverable** | M4 Presentation Video | **Pending** | `Video/M4_Group9_video_Link.txt` awaiting final video URL |

---

## 5. Baseline Preservation Notice

All previous milestone repositories (`code/`, `Results/`, `Document/`, `M3/`) and original `.zip` archives remain strictly untouched as read-only baselines. All M4 modifications, scripts, logs, and outputs reside exclusively within `M4_Group9/`.
