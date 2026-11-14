% test_task1_max_iter.m
% Verifies Member 2 Task 1 & M4 second-round integration requirements:
%   1. Path resolution confirms setup_paths resolves M4_Group9/Code/src functions.
%   2. Default max_iter == 8000 in default_config and run_cga_optimizer.
%   3. Backward compatibility: 7-arg / 2-output call [Th, hist] = run_cga_optimizer(...).
%   4. Custom p.max_iter configures max_iter for both reciprocal and general_fixedV_optimizer.
%   5. opts.max_iter overrides p.max_iter for both reciprocal and general_fixedV_optimizer.
%   6. Empty p.max_iter = [] falls back cleanly to 8000.
%   7. Tiny matched run + checkpoint save/resume + checkpoint config invalidation.

exp_dir = fileparts(mfilename('fullpath'));
src_dir = fileparts(exp_dir);
addpath(src_dir);
setup_paths();

% 0. Verify intended M4 function resolution inside M4_Group9/Code/src (and no duplicates)
resolved_runner = which('run_matched_experiment');
resolved_saver  = which('save_matched_results');
resolved_plot   = which('plot_matched_results');
resolved_cfg    = which('default_config');
resolved_ch     = which('common_generate_channels');
assert(contains(resolved_runner, fullfile('M4_Group9', 'Code', 'src', 'common')) && numel(which('run_matched_experiment', '-all')) == 1, ...
    'run_matched_experiment resolution/uniqueness failed: %s', resolved_runner);
assert(contains(resolved_saver, fullfile('M4_Group9', 'Code', 'src', 'common')) && numel(which('save_matched_results', '-all')) == 1, ...
    'save_matched_results resolution/uniqueness failed: %s', resolved_saver);
assert(contains(resolved_plot, fullfile('M4_Group9', 'Code', 'src', 'common')) && numel(which('plot_matched_results', '-all')) == 1, ...
    'plot_matched_results resolution/uniqueness failed: %s', resolved_plot);
assert(contains(resolved_cfg, fullfile('M4_Group9', 'Code', 'src', 'configs')) && numel(which('default_config', '-all')) == 1, ...
    'default_config resolution/uniqueness failed: %s', resolved_cfg);
assert(contains(resolved_ch, fullfile('M4_Group9', 'Code', 'src', 'common')), ...
    'common_generate_channels resolved to unexpected path: %s', resolved_ch);

p = default_config(struct('R', 16, 'G', 4, 'fading', 'rayleigh'));
rng(21, 'twister');
[H_TX, H_RX] = common_generate_channels(p);
Theta_init   = common_init_theta(p);
V            = common_mmse_beamformer(H_TX, H_RX, Theta_init, p);
Rg = 4;

% 1. Default == 8000 (explicit p without max_iter AND default_config)
assert(p.max_iter == 8000, 'default_config().max_iter must be 8000.');
p_no_cap = rmfield(p, 'max_iter');
[~, ~, info_def] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_no_cap, Rg, 1.0);
assert(info_def.max_iter == 8000, 'Default max_iter when omitted must be 8000.');

% 2. Backward-compatible 7-arg, 2-output M2 call
[Th_2out, h_2out] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_no_cap, Rg, 1.0);
assert(isequal(size(Th_2out), [16, 16]) && numel(h_2out.sumrate) >= 1, '7-arg / 2-output call failed.');

% 3. Custom p.max_iter applied equally to reciprocal and general_fixedV_optimizer
p_cap = p;
p_cap.max_iter = 25;
[~, h_rec, info_rec] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_cap, Rg, 1.0);
[~, h_gen, out_gen]  = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p_cap, Rg);
assert(info_rec.max_iter == 25 && out_gen.max_iter == 25, 'p.max_iter=25 not propagated to both optimizers.');
assert(numel(h_rec.sumrate) <= 25 && numel(h_gen.sumrate) <= 25, 'Iteration count exceeded p.max_iter=25.');
assert(isfield(info_rec, 'armijo_max_hits') && isfield(out_gen, 'armijo_max_hits'), ...
    'armijo_max_hits field missing from info/out.');

% 4. opts.max_iter overrides p.max_iter in BOTH reciprocal and general_fixedV_optimizer
[~, h_ovr_r, info_ovr_r] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_cap, Rg, 1.0, struct('max_iter', 10));
[~, h_ovr_g, out_ovr_g]  = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p_cap, Rg, struct('max_iter', 10));
assert(info_ovr_r.max_iter == 10 && numel(h_ovr_r.sumrate) <= 10, 'opts.max_iter override failed (reciprocal).');
assert(out_ovr_g.max_iter == 10 && numel(h_ovr_g.sumrate) <= 10, 'opts.max_iter override failed (general).');

% 5. Empty p.max_iter falls back to 8000
p_empty = p;
p_empty.max_iter = [];
[~, ~, info_emp] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_empty, Rg, 1.0);
assert(info_emp.max_iter == 8000, 'Empty p.max_iter must fall back to 8000.');

% 6. Config synchronization & checkpoint save/resume + invalidation check
tmp_ckpt = fullfile(tempdir(), 'm4_task1_test_checkpoint.mat');
if exist(tmp_ckpt, 'file') == 2, delete(tmp_ckpt); end

p_tiny = default_config(struct('R', 8, 'G', 2, 'num_draws', 1, 'max_iter', 10, 'run_joint', false));
assert(isequal(p_tiny.Rg_list, [1 4 8]), 'G override did not update Rg_list.');
p_ric = default_config(struct('Kf_dB', 5));
assert(strcmp(p_ric.fading, 'rician') && abs(p_ric.Kf - 10^(5/10)) < 1e-12, 'Kf_dB->fading sync failed.');

res1 = run_matched_experiment(p_tiny, struct('checkpoint_file', tmp_ckpt, 'resume', true));
assert(exist(tmp_ckpt, 'file') == 2, 'Checkpoint file was not saved.');
res2 = run_matched_experiment(p_tiny, struct('checkpoint_file', tmp_ckpt, 'resume', true));
assert(isequaln(res1.rec_fv, res2.rec_fv) && isequaln(res1.gen_fv, res2.gen_fv), ...
    'Checkpoint resume altered matched results.');

% Mutate all required parameters (Pmax_dBm, N, K, fading, Kf_dB, max_iter, seed_base) and confirm rejection
mut_cases = { ...
    {'Pmax_dBm', 10}, ...
    {'N', 3}, ...
    {'K', 3}, ...
    {'fading', 'rician'}, ...
    {'Kf_dB', 5}, ...
    {'max_iter', 15}, ...
    {'seed_base', 100}};
for mc = 1:numel(mut_cases)
    fn = mut_cases{mc}{1};
    fv = mut_cases{mc}{2};
    ov = struct('R', 8, 'G', 2, 'num_draws', 1, 'max_iter', 10, 'run_joint', false);
    ov.(fn) = fv;
    p_mut = default_config(ov);
    [is_valid, reason_str] = configs_match_ckpt(res1.p, p_mut);
    assert(~is_valid && ~isempty(reason_str), 'configs_match_ckpt failed to detect %s change.', fn);
end

p_changed = default_config(struct('R', 8, 'G', 2, 'num_draws', 1, 'max_iter', 10, 'Pmax_dBm', 10, 'run_joint', false));
res3 = run_matched_experiment(p_changed, struct('checkpoint_file', tmp_ckpt, 'resume', true));
assert(abs(res3.p.Pmax_dBm - 10) < 1e-12 && all(~isnan(res3.rec_fv(:))), ...
    'Invalidated checkpoint run did not recompute cleanly with new config.');
if exist(tmp_ckpt, 'file') == 2, delete(tmp_ckpt); end

fprintf('[PASS] All Task 1, path resolution, checkpoint, and M4 audit checks passed.\n');
