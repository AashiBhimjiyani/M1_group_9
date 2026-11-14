# Validation Log T1–T14

**Status at package preparation: NOT RUN / evidence not supplied.** This is intentional. Do not mark a test PASS from an expected result or from a sweep completing with zero failed entries.

Run MATLAB from the actual `M4_Group9/Code/src` directory after `setup_paths`. The exact helper names must be checked against the actual repository; commands below are starting commands based on the M4 project layout.

| ID | Validation | Suggested MATLAB command/procedure | Expected check | Status |
|---|---|---|---|---|
| T1 | Configuration and units | `p=default_config(); [p.Pmax,p.N0]` | 20 dBm = 0.1 W; −80 dBm = 1e−11 W | NOT RUN |
| T2 | Channel dimensions | `p=default_config(); [H_TX,H_RX]=common_generate_channels(p); size(H_TX),size(H_RX)` | H_TX is R×N; H_RX is K×R (anchor: 32×2 and 2×32) | NOT RUN |
| T3 | Seed reproducibility | Set same `rng(seed,'twister')` before two channel generations and compare matrices | Identical matrices for identical seed/call order | NOT RUN |
| T4 | Fading/path-loss sanity | Generate a sufficiently large Rayleigh and Rician sample; inspect finite values and average powers | Finite samples; scaling consistent with configured path loss | NOT RUN |
| T5 | Precoder power | Generate common MMSE V and inspect `norm(V,'fro')^2` | Equals configured power budget within tolerance | NOT RUN |
| T6 | Rate evaluator | Construct a small deterministic channel and calculate SINR/rate manually against project evaluator | Agreement within numerical tolerance | NOT RUN |
| T7 | General unitarity | `norm(Theta_g'*Theta_g-eye(p.R),'fro')` | Below documented tolerance | NOT RUN |
| T8 | Reciprocal feasibility | Check unitarity and `norm(Theta_r-Theta_r.','fro')` | Both errors below documented tolerance | NOT RUN |
| T9 | Architecture structure | Inspect SC off-diagonal entries, GC off-block entries, FC full matrix | Forbidden entries zero within tolerance | NOT RUN |
| T10 | SC zero-gap control | Inspect SC rows in each `per_draw.csv`, especially `gap_fv` | SC gap zero for every matched draw | NOT RUN (must inspect saved CSV) |
| T11 | Gradient finite difference | `run('reciprocal/test_gradient_fd.m')` if present | Analytic directional derivative agrees with centred finite difference | NOT RUN |
| T12 | Convergence/monotonicity | Inspect solver history, accepted steps and line-search objective | No unexplained objective decrease; report cap hits | NOT RUN |
| T13 | Matched-trial protocol | Inspect `run_matched_experiment.m`; verify same channel, initial Theta and frozen V for both solvers | Both methods use matched inputs and common rate evaluator | NOT RUN |
| T14 | Reproducible output | Repeat a seeded small experiment and compare saved metrics/configuration | Same metrics within numerical tolerance | NOT RUN |

## Evidence record — complete separately for each test
- Date/time:
- Git commit: `git rev-parse HEAD`
- MATLAB version: `version`
- Toolboxes: `ver`
- Exact command:
- Observed output (paste verbatim):
- Expected output:
- Status: PASS / FAIL / NOT RUN
- Evidence file path:

### Rician experiment evidence (not a substitute for T1–T14)
The supplied Rician experiment contains 150 architecture/draw rows and reports zero failed draw-architecture entries. This verifies that the experiment runner completed without recorded failed entries; it does **not** establish that all 14 validation tests passed. The Rician results also contain reciprocal iteration-cap hits (GC: 8; FC: 1), which must be reported.
