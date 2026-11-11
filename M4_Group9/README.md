# M4 Group 9: Quantifying the Sum-Rate Cost of Reciprocity in Beyond-Diagonal RIS-Aided MU-MISO Systems

Status: skeleton only. Sweeps, analysis, figures, and report are in progress.

## Repository structure

| Path | Contents |
| --- | --- |
| `Report/` | Final PDF report and the section drafts in `Report/sections/` |
| `Video/` | Link file for the 20-minute video |
| `Code/` | MATLAB code and how-to-run instructions (see `Code/README.md`) |
| `Data/` | Documentation of the synthetic data and how to regenerate it |
| `Results/` | Every result folder, with an index in `Results/README.md` |

## Requirements

MATLAB R2024b (tested on Windows). See `Code/README.md` for setup.

## Contributions

| Member | Role | Status |
| --- | --- | --- |
| Member 1 | Literature, formulation, data docs, validation log, SOTA positioning, group-size and Rician sweeps | Not started in M4 |
| Member 2 | Reciprocal method, RIS size sweep, optimiser diagnostics | Not started in M4 |
| Member 3 | General baseline, power and antenna sweeps, FC reproduction check | In progress |
| Member 4 | Code folder, analysis script, figures, READMEs, report assembly, video | Skeleton in progress |

## Limitations

Synthetic data only. Perfect CSI. Reflective-mode BD-RIS only. Frozen MMSE precoder for the matched comparison.
