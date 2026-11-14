# Task 1 Change Summary: Configurable Iteration Cap (`p.max_iter`)

## Overview
- **Default iteration cap:** Preserved at `8000` (not changed globally to `40000`).
- **Precedence:** `opts.max_iter` (if non-empty) > `p.max_iter` (if non-empty) > `8000` default.
- **Backward compatibility:** 7-input / 2-output M2 signature `[Theta, hist] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p, Rg, nu)` continues to work identically alongside the 8-input / 3-output M3/M4 signature `[Theta, hist, info] = run_cga_optimizer(..., opts)`.
- **Fair comparison parity:** `general_fixedV_optimizer` (Member 3's matched baseline) delegates directly to `run_cga_optimizer(..., nu=0, opts)` using the same `p` struct, guaranteeing identical `max_iter` and `eps_tol` across reciprocal and general V-frozen runs, and now also propagates `armijo_max_hits`.
- **M2 Common Framework integration:** `src/configs/default_config.m` sets `p.max_iter = 8000` (with empty-fallback & integer validation) and `src/common/run_matched_experiment.m` captures `info`/`out` convergence and Armijo limit-hit telemetry.

## Exact Diffs vs. M3 Copies

### 1. `M4_Group9/Code/src/reciprocal/run_cga_optimizer.m` (vs. `M3/code/reciprocal/run_cga_optimizer.m`)
```diff
--- M3/code/reciprocal/run_cga_optimizer.m
+++ M4_Group9/Code/src/reciprocal/run_cga_optimizer.m
@@ -16,8 +16,8 @@
 %       nu          : symmetry penalty weight (M2 default: 1.0)
 %       opts        : optional struct with fields:
 %                       .n_restarts / .restarts : number of restarts (default: 1)
-%                       .max_iter               : iteration cap (default: 8000)
-%                       .eps_tol                : convergence tolerance (default: 1e-8)
+%                       .max_iter               : iteration cap (overrides p.max_iter; default: 8000)
+%                       .eps_tol                : convergence tolerance (overrides p.eps_tol; default: 1e-8)
 %                       .seed                   : random seed for restart generation
 %                       .verbose                : display progress per restart (default: false)
 %                       .inits                  : cell array of custom initial matrices
@@ -50,18 +50,19 @@
         n_restarts = p.restarts;
     end
 
-    % Extract iteration cap and tolerance
-    if isfield(opts, 'max_iter')
+    % Extract iteration cap and tolerance (opts takes precedence over p; default 8000)
+    if isfield(opts, 'max_iter') && ~isempty(opts.max_iter)
         max_iter = opts.max_iter;
-    elseif isfield(p, 'max_iter')
+    elseif isfield(p, 'max_iter') && ~isempty(p.max_iter)
         max_iter = p.max_iter;
     else
         max_iter = 8000;
     end
+    validateattributes(max_iter, {'numeric'}, {'scalar', 'integer', 'positive'});
 
-    if isfield(opts, 'eps_tol')
+    if isfield(opts, 'eps_tol') && ~isempty(opts.eps_tol)
         eps_tol = opts.eps_tol;
-    elseif isfield(p, 'eps_tol')
+    elseif isfield(p, 'eps_tol') && ~isempty(p.eps_tol)
         eps_tol = p.eps_tol;
     else
         eps_tol = 1e-8;
@@ -160,6 +161,8 @@
     info.best_rate          = best_rate;
     info.restarts           = restarts_log;
     info.all_rates          = all_rates;
+    info.iters              = restarts_log(best_idx).iters;
+    info.max_iter           = max_iter;
+    info.armijo_max_hits    = restarts_log(best_idx).armijo_max_hits;
     info.converged          = restarts_log(best_idx).converged;
     info.termination_reason = restarts_log(best_idx).termination_reason;
     info.Theta_final        = restarts_log(best_idx).Theta_final;
```

### 2. `M4_Group9/Code/src/nonreciprocal/general_fixedV_optimizer.m` (vs. `M3/code/nonreciprocal/general_fixedV_optimizer.m`)
```diff
--- M3/code/nonreciprocal/general_fixedV_optimizer.m
+++ M4_Group9/Code/src/nonreciprocal/general_fixedV_optimizer.m
@@ -1,5 +1,5 @@
 function [Theta_final, hist, out] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p, Rg, opts)
-% GENERAL_FIXEDV_OPTIMIZER  "Matched" baseline: <Member 2 name>'s reciprocal CGA machinery
+% GENERAL_FIXEDV_OPTIMIZER  "Matched" baseline: Member 2's reciprocal CGA machinery
 %   (run_cga_optimizer: FP surrogate, V frozen, Armijo, retraction) with the
 %   symmetry penalty switched off (nu = 0) and a plain unitary projection at the
 %   end instead of enforce_symmetry_unitarity.  Same start, same V, same
@@ -17,5 +17,9 @@
     out.rate_recomputedV = calculate_sumrate(calculate_sinr(H_TX, H_RX, Theta_final, V2, p));
     out.sym_err = norm(Theta_final - Theta_final.', 'fro');         % expected > 0
     out.uni_err = norm(Theta_final' * Theta_final - eye(size(Theta_final,1)), 'fro');
+    out.max_iter = info.max_iter;
+    out.armijo_max_hits = info.armijo_max_hits;
+    out.converged = info.converged;
+    out.termination_reason = info.termination_reason;
     out.info = info;
 end
```

### 3. Difference Relative to M2 (`code/reciprocal/run_cga_optimizer.m`) & Framework Integration
M2 hardcoded `max_iter = 8000;` with 7 inputs and 2 outputs `[Theta, hist]`. M4 adopts the M3 8-input / 3-output architecture (`opts`, `info`, multi-start support, RNG state isolation via `onCleanup`, explicit `converged` / `termination_reason` flags, and `line_search_failed` stagnation guard), adds empty-field guards plus `armijo_max_hits` telemetry, and integrates cleanly with Member 4's `src/configs/default_config.m` and `src/common/run_matched_experiment.m` while keeping 7-input / 2-output calls backward-compatible.
