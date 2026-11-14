# State-of-the-Art Positioning

## 1. Strongest existing approaches

The base paper by Li, Shen and Clerckx (IEEE TWC, 2023) establishes a unified BD-RIS framework spanning reflective, transmissive and hybrid modes, and single-, group- and fully-connected architectures. It develops joint transmit-precoder/BD-RIS optimisation for sum-rate maximisation. Its central scope is the architecture/mode framework; it is not itself a matched study of the reciprocity gap defined in this project.

The related scattering-network work by Shen, Clerckx and Murch (IEEE TWC, 2022) is relevant to modelling RIS hardware through scattering parameters. The exact assumptions and claims must be cited from the full paper.

The M2 SOTA notes also identify arXiv:2607.22170, arXiv:2604.22469, arXiv:2511.07683 and arXiv:2509.20246. Their full-text claims and publication metadata remain **NOT VERIFIED** in the current evidence package. See `Report/verification_checklist.md`. Do not present abstract-only claims as verified findings.

## 2. What this project achieves

This project narrows the broad BD-RIS framework to reflective-mode MU-MISO and compares:
- General lossless design: ΘᴴΘ=I.
- Reciprocal lossless design: ΘᴴΘ=I and Θ=Θᵀ.

The primary metric is a matched fixed-precoder sum-rate gap. SC is used as a zero-gap control; GC and FC expose the effect of the added symmetry restriction. M4 adds a GC group-size sweep at R=32 and a Rician anchor at K-factor 2 dB.

## 3. Evidence-backed contributions

- Matched channel and common frozen-MMSE-precoder comparison across general and reciprocal designs.
- SC, GC and FC architecture comparison.
- GC group-size points Rg=2, 8, 16 at R=32, 50 draws each.
- Rician anchor with 50 draws per architecture.
- Saved per-draw and summary CSV evidence for the Rician anchor.
- Explicit reporting of negative gaps and reciprocal solver iteration-cap hits.

## 4. Limitations and open issues

The primary metric freezes the precoder, so it isolates the RIS-matrix comparison under a common V but is not a full joint-design comparison. The Rician experiment has reciprocal iteration-cap hits (8 GC and 1 FC), and individual negative gaps occur. The current M4 results do not include all group-level and system-level sweeps listed in the full group guide. The validation log T1–T14 remains NOT RUN until test outputs are recorded. Full-text verification of the listed SOTA papers remains outstanding.

## 5. What would close the distance

Complete the assigned full-text paper checks; retain the raw group-size CSVs in the final repository; run and document T1–T14; investigate capped reciprocal draws with a higher iteration cap and penalty sensitivity; and compare additional operating points only where time and team results permit.

## Hypothesis status

See `06_results_and_analysis.md` for the evidence-based H1–H5 status. In brief: H1 partially supported; H2 not tested in these M4 runs; H3 partially tested; H4 open; H5 partially tested. These are not claims of full validation.
