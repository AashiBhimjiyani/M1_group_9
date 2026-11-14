# Experimental Results and Critical Analysis

## 1. Scope and metric

The primary metric is the fixed-precoder reciprocity gap
\[
\Delta R_{\mathrm{fv}}=R_{\mathrm{general,fv}}-R_{\mathrm{reciprocal,fv}}.
\]
Both designs are compared using matched channel draws and a common frozen MMSE precoder. Positive values favour the general design; negative values are retained because they can arise from numerical optimisation differences/local solutions. Joint-design values (`gen_jt`) are not part of this fixed-precoder gap.

## 2. Group-size sweep (Rayleigh)

The completed sweep used R=32, N=K=2, Pmax=20 dBm, 50 draws, and GC group sizes Rg=2, 8, and 16 (G=16, 4, and 2). All three configurations were reported by the MATLAB run as having zero failed entries.

Previously supplied group-size summary CSVs gave these GC means:

| GC block size Rg | Reciprocal mean rate | General mean rate | Mean gap (bps/Hz) |
|---:|---:|---:|---:|
| 2 | 9.2485 | 9.5865 | 0.3380 |
| 8 | 10.1824 | 10.2081 | 0.0258 |
| 16 | 10.2588 | 10.2816 | 0.0228 |

**Interpretation:** For these tested GC settings, the measured mean gap becomes smaller as the block size increases. This is an observation for the tested setup, not a universal law. The original three `summary.csv` files should be placed in their corresponding `Results/sweep_group_size/Rg02`, `Rg08`, and `Rg16` folders in the final repository so each number can be traced directly to a result file.

## 3. Rician anchor

The supplied Rician CSVs contain 50 draws for each of SC, GC and FC (150 rows total), with no recorded failed draw-architecture entries. The configured anchor is N=K=2, R=32, G=8, Pmax=20 dBm, Rician K-factor 2 dB, and `run_joint=false`.

| Architecture | Reciprocal mean rate | General mean rate | Mean gap (bps/Hz) | General wins | Reciprocal wins | Ties |
|---|---:|---:|---:|---:|---:|---:|
| SC | 9.0009 | 9.0009 | 0.0000 | 0 | 0 | 50 |
| GC | 10.3463 | 10.4310 | 0.0848 | 46 | 4 | 0 |
| FC | 10.6830 | 10.7201 | 0.0371 | 46 | 4 | 0 |

The win counts are calculated from the 50 per-draw `gap_fv` values for each architecture. The sample standard deviations of the gaps are approximately 0.2682 (GC) and 0.1299 (FC); corresponding standard errors are approximately 0.0379 and 0.0184.

### Numerical and solver diagnostics

- Maximum reciprocal symmetry error: approximately 3.66e−14 (FC).
- Maximum reciprocal unitarity error: approximately 1.55e−14 (FC).
- Reciprocal solver reached the 8,000-iteration cap in 8 GC draws and 1 FC draw; no SC cap hits were observed.
- `gen_jt` is NaN by design because `run_joint=false`; it is not a failed result.
- There are 4 negative fixed-precoder gaps each in GC and FC. They are retained and are consistent with per-realisation numerical/local-optimisation variation.
- The runner reports zero failed entries, but that does not mean all optimisations converged before their iteration cap.

## 4. Critical interpretation

SC is the zero-gap control because a diagonal matrix is already symmetric. GC and FC show positive average gaps in the Rician anchor, while individual draws can show the opposite ordering. The group-size sweep shows a decreasing mean GC gap across the three tested block sizes. The experiments support an architecture- and configuration-dependent measured gap; they do not establish a universal ordering across every channel or system setting.

The iteration-cap hits are an important caveat: part of an observed gap may reflect optimisation quality rather than only the physical reciprocity restriction. The current results use a common frozen precoder for the primary comparison. They should not be conflated with the separate joint V/Theta benchmark.

## 5. Hypothesis status (evidence-limited)

| Hypothesis | Current status | Evidence / limitation |
|---|---|---|
| H1: architecture/group-size effect | PARTIALLY SUPPORTED | Group-size GC means and SC/GC/FC Rician anchor show configuration-dependent gaps; other power/RIS-size sweeps are outside this package. |
| H2: joint-design effect | NOT TESTED HERE | `run_joint=false` for the group-size and Rician experiments; `gen_jt` is NaN by design. |
| H3: fading-model effect | PARTIALLY TESTED | Rician anchor completed. A controlled Rayleigh-versus-Rician comparison at identical parameters/seeds must be checked before making a strong causal claim. |
| H4: optimiser versus constraint contribution | OPEN | Reciprocal iteration-cap hits require a higher-cap/penalty-sensitivity diagnostic; do not attribute the full gap solely to reciprocity. |
| H5: robustness across operating conditions | PARTIALLY TESTED | Group-size and Rician points are available; the full power, RIS-size and N=K sweep matrix is not included here. |

## 6. Reproducibility files

Rician evidence is included at `Results/rician_anchor/per_draw.csv` and `Results/rician_anchor/summary.csv`. Group-size means above were provided from earlier uploaded summary files; add the three original CSVs to the final repository. All report numbers must be traced to saved result files. No values are inferred from plots.
