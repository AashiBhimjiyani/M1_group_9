# Results index

Every condition folder holds `per_draw.csv` (one row per draw and architecture), `summary.csv`, `config_used.txt`, figures, and (where analysed) `gap_table.csv` with the paired gap statistics.

| Folder | Condition |
|---|---|
| `anchor_rayleigh_R32_50draws/` | Rayleigh, N = K = 2, R = 32, Rg = 4, 20 dBm (anchor) |
| `rician_anchor/` | Rician K-factor 2 dB, anchor parameters |
| `sweep_power/P*dBm/` | 0, 5, 10, 15 dBm |
| `sweep_antennas/NK*/` | N = K = 3, 4, 6 |
| `sweep_ris_size/R*/` | R = 16, 48, 64 (Rg = 4) |
| `sweep_group_size/` | GC block size sweep at R = 32 |
| `diagnostics/` | iteration-cap check, penalty sensitivity, power-convention check, baseline validation, Li trend validation, verification logs, M3 reference data |
| `figures/` | report figures |
