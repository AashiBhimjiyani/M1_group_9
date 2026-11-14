% run_cap_diagnostic.m
% Member 2 Task 2: Iteration-cap diagnostic for GC (R=32, Rg=4, G=8, Rayleigh).
% Evaluates the 4 draws that hit the 8,000 cap in M2 (21, 26, 31, 34) plus
% 6 ordinary draws (1, 2, 3, 4, 5, 6), comparing reciprocal and general
% V-frozen designs at p.max_iter = 40000 against p.max_iter = 8000.
% Uses Member 4's common_* framework, includes per-draw checkpointing/resume,
% tracks Armijo limit hits, and strictly validates M2 anchor CSV existence.
%
% Outputs saved under M4_Group9/Results/diagnostics/cap_check/:
%   - cap_check_per_draw.csv
%   - cap_check_summary.csv
%   - cap_check_results.mat

fprintf('=================================================================\n');
fprintf('  M4 TASK 2: CAP DIAGNOSTIC (GC Rg=4, 8000 vs 40000 ITERATIONS)\n');
fprintf('=================================================================\n\n');

exp_dir  = fileparts(mfilename('fullpath'));
src_dir  = fileparts(exp_dir);
code_dir = fileparts(src_dir);
m4_root  = fileparts(code_dir);

addpath(src_dir);
setup_paths();

out_dir = fullfile(m4_root, 'Results', 'diagnostics', 'cap_check');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
ckpt_file = fullfile(out_dir, 'cap_check_checkpoint.mat');

% Verify M2 R=32 anchor CSV loudly (Priority 1: M4 anchor copy, Priority 2: read-only M2 Results)
[m2_csv, m2_anchor_source] = resolve_anchor_path('per_draw.csv');
fprintf('Using M2 anchor CSV (%s): %s\n\n', m2_anchor_source, m2_csv);
m2_tbl = readtable(m2_csv, 'TextType', 'char');
req_cols = {'draw', 'arch', 'rec_fv'};
miss_cols = req_cols(~ismember(req_cols, m2_tbl.Properties.VariableNames));
if ~isempty(miss_cols)
    error('run_cap_diagnostic:InvalidAnchorSchema', ...
        'Anchor CSV %s missing required column(s): %s', m2_csv, strjoin(miss_cols, ', '));
end

% Configuration matching M2 anchor (GC, R=32, Rg=4, G=8)
p_base = default_config(struct( ...
    'N', 2, 'K', 2, 'R', 32, 'G', 8, ...
    'Pmax_dBm', 20, 'N0_dBm', -80, ...
    'fading', 'rayleigh', 'eps_tol', 1e-8, ...
    'nu', 1.0, 'run_joint', false));

Rg = 4;
nu = p_base.nu;

ordinary_draws = [1, 2, 3, 4, 5, 6];
capped_draws   = [21, 26, 31, 34];
draw_ids       = [ordinary_draws, capped_draws];
n_draws        = numel(draw_ids);

row_tmpl = struct( ...
    'draw', 0, 'draw_group', '', ...
    'rec_rate_8k', 0, 'gen_rate_8k', 0, 'gap_8k', 0, ...
    'rec_iters_8k', 0, 'gen_iters_8k', 0, ...
    'rec_armijo_hits_8k', 0, 'gen_armijo_hits_8k', 0, ...
    'rec_converged_8k', false, 'rec_status_8k', '', ...
    'gen_converged_8k', false, 'gen_status_8k', '', ...
    'rec_rate_40k', 0, 'rec_pre_rate_40k', 0, 'rec_v2_40k', 0, ...
    'gen_rate_40k', 0, 'gen_v2_40k', 0, ...
    'gap_40k', 0, 'gap_40k_pct', 0, ...
    'rec_iters_40k', 0, 'gen_iters_40k', 0, ...
    'rec_armijo_hits_40k', 0, 'gen_armijo_hits_40k', 0, ...
    'rec_converged_40k', false, 'rec_status_40k', '', 'rec_term_40k', '', ...
    'gen_converged_40k', false, 'gen_status_40k', '', 'gen_term_40k', '', ...
    'delta_rec_rate', 0, 'delta_gen_rate', 0, 'delta_gap', 0, ...
    'rec_sym_err_40k', 0, 'rec_uni_err_40k', 0, ...
    'm2_ref_rec_8k', 0, 'm2_ref_diff_8k', 0, ...
    'rec_time_40k_s', 0, 'gen_time_40k_s', 0);

rows = repmat(row_tmpl, n_draws, 1);
done_mask = false(n_draws, 1);

if ~exist('resume_ckpt', 'var'), resume_ckpt = true; end
if resume_ckpt && exist(ckpt_file, 'file') == 2
    S_ckpt = load(ckpt_file);
    if isfield(S_ckpt, 'draw_ids') && isequal(S_ckpt.draw_ids, draw_ids) && ...
            isfield(S_ckpt, 'rows') && isfield(S_ckpt, 'done_mask') && ...
            isfield(S_ckpt, 'p_base') && isfield(S_ckpt, 'Rg') && isfield(S_ckpt, 'nu') && ...
            isequal(S_ckpt.Rg, Rg) && isequal(S_ckpt.nu, nu)
        [ckpt_ok, ckpt_reason] = configs_match_ckpt(S_ckpt.p_base, p_base);
        if ckpt_ok
            rows = S_ckpt.rows;
            done_mask = S_ckpt.done_mask;
            fprintf('[Resume] Loaded checkpoint %s (%d/%d draws done).\n\n', ...
                ckpt_file, sum(done_mask), n_draws);
        else
            fprintf('[Checkpoint] Ignoring stale checkpoint %s (%s). Starting fresh.\n\n', ...
                ckpt_file, ckpt_reason);
        end
    else
        fprintf('[Checkpoint] Ignoring incomplete/stale checkpoint %s. Starting fresh.\n\n', ckpt_file);
    end
end

for i = 1:n_draws
    d = draw_ids(i);
    if done_mask(i)
        fprintf('Draw %2d [SKIP cached]\n', d);
        continue;
    end
    if ismember(d, capped_draws)
        grp_label = 'm2_capped';
    else
        grp_label = 'ordinary';
    end

    % Strict lookup of M2 reference row (no silent NaN)
    m2_row = m2_tbl(m2_tbl.draw == d & strcmp(m2_tbl.arch, 'GC'), :);
    if isempty(m2_row)
        error('run_cap_diagnostic:MissingAnchorRow', ...
            'M2 anchor row missing for draw=%d, arch=GC in %s.', d, m2_csv);
    end
    m2_ref_rec = m2_row.rec_fv(1);

    % Identical channel, canonical SC start, and frozen MMSE V (Member 4 helpers)
    rng(p_base.seed_base + d, 'twister');
    [H_TX, H_RX] = common_generate_channels(p_base);
    Theta_init   = common_init_theta(p_base);
    V            = common_mmse_beamformer(H_TX, H_RX, Theta_init, p_base);

    % ---- 1. Baseline 8,000 iteration cap ----
    p_8k = p_base;
    p_8k.max_iter = 8000;

    [Th_rec_8k_opt, hr_8k, ir_8k] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_8k, Rg, nu);
    Th_rec_8k   = enforce_symmetry_unitarity(Th_rec_8k_opt, Rg);
    rec_rate_8k = common_sumrate(common_sinr(H_TX, H_RX, Th_rec_8k, V, p_8k));

    [Th_gen_8k, hf_8k, of_8k] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p_8k, Rg);
    gen_rate_8k = common_sumrate(common_sinr(H_TX, H_RX, Th_gen_8k, V, p_8k));
    gap_8k      = gen_rate_8k - rec_rate_8k;

    % ---- 2. Diagnostic 40,000 iteration cap ----
    p_40k = p_base;
    p_40k.max_iter = 40000;

    t0 = tic;
    [Th_rec_40k_opt, hr_40k, ir_40k] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_40k, Rg, nu);
    rec_time_40k = toc(t0);
    Th_rec_40k   = enforce_symmetry_unitarity(Th_rec_40k_opt, Rg);

    rec_pre_40k  = common_sumrate(common_sinr(H_TX, H_RX, Th_rec_40k_opt, V, p_40k));
    rec_rate_40k = common_sumrate(common_sinr(H_TX, H_RX, Th_rec_40k, V, p_40k));
    V2_rec_40k   = common_mmse_beamformer(H_TX, H_RX, Th_rec_40k, p_40k);
    rec_v2_40k   = common_sumrate(common_sinr(H_TX, H_RX, Th_rec_40k, V2_rec_40k, p_40k));

    t1 = tic;
    [Th_gen_40k, hf_40k, of_40k] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p_40k, Rg);
    gen_time_40k = toc(t1);
    gen_rate_40k = common_sumrate(common_sinr(H_TX, H_RX, Th_gen_40k, V, p_40k));
    V2_gen_40k   = common_mmse_beamformer(H_TX, H_RX, Th_gen_40k, p_40k);
    gen_v2_40k   = common_sumrate(common_sinr(H_TX, H_RX, Th_gen_40k, V2_gen_40k, p_40k));

    gap_40k     = gen_rate_40k - rec_rate_40k;
    gap_40k_pct = 100 * gap_40k / gen_rate_40k;
    m2_diff     = abs(rec_rate_8k - m2_ref_rec);

    rows(i).draw                = d;
    rows(i).draw_group          = grp_label;
    rows(i).rec_rate_8k         = rec_rate_8k;
    rows(i).gen_rate_8k         = gen_rate_8k;
    rows(i).gap_8k              = gap_8k;
    rows(i).rec_iters_8k        = numel(hr_8k.sumrate);
    rows(i).gen_iters_8k        = numel(hf_8k.sumrate);
    rows(i).rec_armijo_hits_8k  = ir_8k.armijo_max_hits;
    rows(i).gen_armijo_hits_8k  = of_8k.armijo_max_hits;
    rows(i).rec_converged_8k    = ir_8k.converged;
    rows(i).rec_status_8k       = conv_label(ir_8k.converged);
    rows(i).gen_converged_8k    = of_8k.converged;
    rows(i).gen_status_8k       = conv_label(of_8k.converged);
    rows(i).rec_rate_40k        = rec_rate_40k;
    rows(i).rec_pre_rate_40k    = rec_pre_40k;
    rows(i).rec_v2_40k          = rec_v2_40k;
    rows(i).gen_rate_40k        = gen_rate_40k;
    rows(i).gen_v2_40k          = gen_v2_40k;
    rows(i).gap_40k             = gap_40k;
    rows(i).gap_40k_pct         = gap_40k_pct;
    rows(i).rec_iters_40k       = numel(hr_40k.sumrate);
    rows(i).gen_iters_40k       = numel(hf_40k.sumrate);
    rows(i).rec_armijo_hits_40k = ir_40k.armijo_max_hits;
    rows(i).gen_armijo_hits_40k = of_40k.armijo_max_hits;
    rows(i).rec_converged_40k   = ir_40k.converged;
    rows(i).rec_status_40k      = conv_label(ir_40k.converged);
    rows(i).rec_term_40k        = ir_40k.termination_reason;
    rows(i).gen_converged_40k   = of_40k.converged;
    rows(i).gen_status_40k      = conv_label(of_40k.converged);
    rows(i).gen_term_40k        = of_40k.termination_reason;
    rows(i).delta_rec_rate      = rec_rate_40k - rec_rate_8k;
    rows(i).delta_gen_rate      = gen_rate_40k - gen_rate_8k;
    rows(i).delta_gap           = gap_40k - gap_8k;
    rows(i).rec_sym_err_40k     = norm(Th_rec_40k - Th_rec_40k.', 'fro');
    rows(i).rec_uni_err_40k     = norm(Th_rec_40k' * Th_rec_40k - eye(p_40k.R), 'fro');
    rows(i).m2_ref_rec_8k       = m2_ref_rec;
    rows(i).m2_ref_diff_8k      = m2_diff;
    rows(i).rec_time_40k_s      = rec_time_40k;
    rows(i).gen_time_40k_s      = gen_time_40k;

    done_mask(i) = true;
    save(ckpt_file, 'rows', 'done_mask', 'draw_ids', 'p_base', 'Rg', 'nu', '-v7');
    writetable(struct2table(rows(done_mask)), fullfile(out_dir, 'cap_check_per_draw.csv'));

    fprintf('Draw %2d (%-9s) | 8k: rec=%.4f(%5d,%s) gen=%.4f(%5d) gap=%+.4f | 40k: rec=%.4f(%5d,%s,arm=%d) gen=%.4f(%5d,%s,arm=%d) gap=%+.4f | dRec=%+.4e\n', ...
        d, grp_label, rec_rate_8k, rows(i).rec_iters_8k, rows(i).rec_status_8k, ...
        gen_rate_8k, rows(i).gen_iters_8k, gap_8k, ...
        rec_rate_40k, rows(i).rec_iters_40k, rows(i).rec_status_40k, rows(i).rec_armijo_hits_40k, ...
        gen_rate_40k, rows(i).gen_iters_40k, rows(i).gen_status_40k, rows(i).gen_armijo_hits_40k, ...
        gap_40k, rows(i).delta_rec_rate);
end

% Summary table by draw group (ordinary, m2_capped, all)
groups = {'ordinary', 'm2_capped', 'all'};
sum_rows = repmat(struct( ...
    'group', '', 'n_draws', 0, ...
    'rec_rate_8k_mean', 0, 'gen_rate_8k_mean', 0, 'gap_8k_mean', 0, 'pct_gap_8k_of_means', 0, ...
    'rec_rate_40k_mean', 0, 'gen_rate_40k_mean', 0, 'gap_40k_mean', 0, 'pct_gap_40k_of_means', 0, ...
    'delta_rec_mean', 0, 'delta_gen_mean', 0, 'delta_gap_mean', 0, ...
    'rec_iters_8k_mean', 0, 'rec_iters_40k_mean', 0, 'gen_iters_40k_mean', 0, ...
    'rec_conv_8k_count', 0, 'rec_conv_40k_count', 0, 'gen_conv_40k_count', 0, ...
    'rec_armijo_hits_40k_total', 0, 'gen_armijo_hits_40k_total', 0, ...
    'max_m2_ref_diff_8k', 0), numel(groups), 1);

for g = 1:numel(groups)
    gname = groups{g};
    if strcmp(gname, 'all')
        mask = true(n_draws, 1);
    else
        mask = strcmp({rows.draw_group}, gname).';
    end
    sub = rows(mask);
    sum_rows(g).group                     = gname;
    sum_rows(g).n_draws                   = numel(sub);
    sum_rows(g).rec_rate_8k_mean          = mean([sub.rec_rate_8k]);
    sum_rows(g).gen_rate_8k_mean          = mean([sub.gen_rate_8k]);
    sum_rows(g).gap_8k_mean               = mean([sub.gap_8k]);
    sum_rows(g).pct_gap_8k_of_means       = 100 * (sum_rows(g).gen_rate_8k_mean - sum_rows(g).rec_rate_8k_mean) / sum_rows(g).gen_rate_8k_mean;
    sum_rows(g).rec_rate_40k_mean         = mean([sub.rec_rate_40k]);
    sum_rows(g).gen_rate_40k_mean         = mean([sub.gen_rate_40k]);
    sum_rows(g).gap_40k_mean              = mean([sub.gap_40k]);
    sum_rows(g).pct_gap_40k_of_means      = 100 * (sum_rows(g).gen_rate_40k_mean - sum_rows(g).rec_rate_40k_mean) / sum_rows(g).gen_rate_40k_mean;
    sum_rows(g).delta_rec_mean            = mean([sub.delta_rec_rate]);
    sum_rows(g).delta_gen_mean            = mean([sub.delta_gen_rate]);
    sum_rows(g).delta_gap_mean            = mean([sub.delta_gap]);
    sum_rows(g).rec_iters_8k_mean         = mean([sub.rec_iters_8k]);
    sum_rows(g).rec_iters_40k_mean        = mean([sub.rec_iters_40k]);
    sum_rows(g).gen_iters_40k_mean        = mean([sub.gen_iters_40k]);
    sum_rows(g).rec_conv_8k_count         = sum([sub.rec_converged_8k]);
    sum_rows(g).rec_conv_40k_count        = sum([sub.rec_converged_40k]);
    sum_rows(g).gen_conv_40k_count        = sum([sub.gen_converged_40k]);
    sum_rows(g).rec_armijo_hits_40k_total = sum([sub.rec_armijo_hits_40k]);
    sum_rows(g).gen_armijo_hits_40k_total = sum([sub.gen_armijo_hits_40k]);
    sum_rows(g).max_m2_ref_diff_8k        = max([sub.m2_ref_diff_8k]);
end

writetable(struct2table(rows), fullfile(out_dir, 'cap_check_per_draw.csv'));
writetable(struct2table(sum_rows), fullfile(out_dir, 'cap_check_summary.csv'));
save(fullfile(out_dir, 'cap_check_results.mat'), 'rows', 'sum_rows', 'draw_ids', 'p_base', 'Rg', 'nu', '-v7');

fprintf('\nSaved cap diagnostic outputs to %s\n', out_dir);

function lbl = conv_label(is_conv)
    if is_conv
        lbl = 'converged';
    else
        lbl = 'hit_cap';
    end
end
