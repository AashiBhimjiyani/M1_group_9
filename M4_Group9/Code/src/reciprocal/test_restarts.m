% test_restarts.m
% Validates Task 2.1: Multi-start / Restarts option in reciprocal optimizer.
% Checks:
%   1. Comparison of n_restarts=1 against stored M2 reference.
%   2. Caller RNG state preservation (no global stream mutation).
%   3. Draw-dependent seeding (different initializations across draws).
%   4. Supplied custom initialization behavior via opts.inits.
%   5. Multi-start logging of restart IDs, pre/post rates, and best-of selection.
%   6. Exact reproducibility across repeated runs with identical seed.
%   7. Feasibility of all generated solutions (unitarity & symmetry <= 1e-12).

fprintf('========================================================\n');
fprintf('  TASK 2.1: COMPREHENSIVE MULTI-START / RESTARTS VALIDATION\n');
fprintf('========================================================\n\n');

script_dir = fileparts(mfilename('fullpath'));
src_dir = fileparts(script_dir);
addpath(src_dir);
setup_paths();

p = config(32);
p.Kf_dB = -Inf; % Rayleigh fading
nu = 1.0;

%% Test 1: Compare n_restarts=1 against frozen M2 reference (Draw 1)
fprintf('Test 1: Comparing n_restarts=1 against frozen M2 per_draw.csv reference...\n');
[m2_csv, m2_src] = resolve_anchor_path('per_draw.csv');
fprintf('  Using anchor (%s): %s\n', m2_src, m2_csv);
m2_table = readtable(m2_csv);

% Filter Draw 1 for SC, GC, FC
row_fc = m2_table(m2_table.draw == 1 & strcmp(m2_table.arch, 'FC'), :);
expected_fc_rate = row_fc.rec_fv;

rng(1, 'twister');
[H_TX_1, H_RX_1] = generate_channels(p);
Theta_init_1 = initialize_theta(p.R, 'SC', p.R);
V_1 = mmse_beamformer(H_TX_1, H_RX_1, Theta_init_1, p);

opts_m2 = struct('n_restarts', 1, 'max_iter', 8000, 'eps_tol', 1e-8);
[Th_m2, ~, info_m2] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_m2);
diff_m2_fc = abs(info_m2.best_rate - expected_fc_rate);
assert(diff_m2_fc < 1e-4, sprintf('M2 Draw 1 FC rate mismatch: got %.6f, expected %.6f (diff = %.2e)', ...
    info_m2.best_rate, expected_fc_rate, diff_m2_fc));
fprintf('  [PASS] Single-restart matches M2 reference rate within tolerance (got %.6f, ref %.6f, diff = %.2e)\n\n', ...
    info_m2.best_rate, expected_fc_rate, diff_m2_fc);

%% Test 2: Caller RNG state preservation
fprintf('Test 2: Verifying caller global RNG stream is preserved...\n');
rng(12345, 'twister');
rand_before = rand(10, 1);

% Reset to same state
rng(12345, 'twister');
% Run optimizer with multiple restarts (which uses twister inside for restart generation)
opts_rng = struct('n_restarts', 3, 'seed', 999, 'max_iter', 50);
run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_rng);

% Now generate next 10 random numbers in caller space
rand_after = rand(10, 1);
diff_rng = norm(rand_before - rand_after);
assert(diff_rng == 0, sprintf('Caller RNG stream was altered! diff = %.2e', diff_rng));
fprintf('  [PASS] Caller RNG state perfectly preserved (diff = %.2e)\n\n', diff_rng);

%% Test 3: Draw-dependent seeding
fprintf('Test 3: Checking that restart seeds vary across draws...\n');
opts_d1 = struct('n_restarts', 2, 'seed', 500, 'draw_id', 1, 'max_iter', 10);
[~, ~, info_d1] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_d1);

opts_d2 = struct('n_restarts', 2, 'seed', 500, 'draw_id', 2, 'max_iter', 10);
[~, ~, info_d2] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_d2);

init_diff = norm(info_d1.restarts(2).Theta_opt - info_d2.restarts(2).Theta_opt, 'fro');
assert(init_diff > 1e-4, 'Restart 2 produced identical initializations across different draws!');
fprintf('  [PASS] Different draws produce distinct restart initializations (diff = %.4f)\n\n', init_diff);

%% Test 4: Supplied custom initialization behavior
fprintf('Test 4: Verifying custom initialization via opts.inits...\n');
custom_Th2 = initialize_theta(p.R, 'GC', 8);
opts_custom = struct('n_restarts', 2, 'inits', {{Theta_init_1, custom_Th2}}, 'max_iter', 50);
[~, ~, info_custom] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 4, nu, opts_custom);
assert(numel(info_custom.restarts) == 2, 'Custom inits restart count mismatch!');
fprintf('  [PASS] Successfully ran custom supplied initialization cell array.\n\n');

%% Test 5: Multi-start best-of selection on FC architecture (n_restarts=4)
fprintf('Test 5: Multi-start best-of selection on FC (Rg=32, n_restarts=4)...\n');
opts_fc = struct('n_restarts', 4, 'seed', 2026, 'draw_id', 1, 'max_iter', 1000, 'verbose', true);
[Th_fc, hist_fc, info_fc] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_fc);

fprintf('\nRestart Log Table for FC:\n');
fprintf('  ID | Post-Rate (bps/Hz) | Pre-Rate (bps/Hz) | Iters | Term Reason       | Final-SymErr | Final-UniErr\n');
fprintf(' ----+--------------------+-------------------+-------+-------------------+--------------+--------------\n');
for s = 1:numel(info_fc.restarts)
    r = info_fc.restarts(s);
    fprintf('  %2d |      %8.4f      |      %8.4f     | %5d | %-17s |   %10.2e |   %10.2e\n', ...
        r.restart_id, r.rate, r.pre_rate, r.iters, r.termination_reason, r.final_sym_err, r.final_uni_err);
    assert(r.final_sym_err < 1e-12, 'Final symmetry error exceeds 1e-12!');
    assert(r.final_uni_err < 1e-12, 'Final unitarity error exceeds 1e-12!');
end

assert(info_fc.best_restart_id >= 1 && info_fc.best_restart_id <= 4, 'Invalid best restart ID!');
assert(abs(info_fc.best_rate - max(info_fc.all_rates)) < 1e-12, 'Best rate is not max of all rates!');
assert(info_fc.best_rate >= info_fc.restarts(1).rate - 1e-12, 'Best-of rate is worse than first start!');
fprintf('\n  [PASS] Best restart %d correctly selected (Best Rate = %.4f bps/Hz >= Start 1 = %.4f bps/Hz)\n\n', ...
    info_fc.best_restart_id, info_fc.best_rate, info_fc.restarts(1).rate);

%% Test 6: Reproducibility across independent runs with identical seed
fprintf('Test 6: Checking reproducibility across independent runs...\n');
[~, ~, info_rep1] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_fc);
[~, ~, info_rep2] = run_cga_optimizer(H_TX_1, H_RX_1, Theta_init_1, V_1, p, 32, nu, opts_fc);

max_diff = max(abs(info_rep1.all_rates - info_rep2.all_rates));
assert(max_diff < 1e-12, 'Multi-start runs with identical seed are not reproducible!');
fprintf('  [PASS] Exact reproducibility confirmed across multiple runs (max rate diff = %.2e)\n\n', max_diff);

fprintf('========================================================\n');
fprintf('  ALL TASK 2.1 MULTI-START TESTS PASSED SUCCESSFULLY!  \n');
fprintf('========================================================\n');
