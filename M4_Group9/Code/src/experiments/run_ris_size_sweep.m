% run_ris_size_sweep.m
% Member 2 Task 4: RIS-size sweep experiment (R in {16, 48, 64}, Rg = 4, G in {4, 12, 16}).
% Includes ALL THREE architectures: SC (Rg=1), GC (Rg=4), FC (Rg=R).
% Anchor baseline: R = 32, Rg = 4, G = 8 (M2 Results/matched_rayleigh_R32_50draws/).
%
% Audit fixes applied:
%   - Runs SC, GC, and FC (not GC only) via Member 4's default_config + run_matched_experiment
%   - Per-draw checkpointing & resume (checkpoint.mat inside each output directory)
%   - Armijo max-step hit tracking (rec_armijo_hits, gen_armijo_hits)
%   - Quick test ('quick') runs standalone without requiring any M2 anchor CSV
%   - Full mode resolves M2 R=32 anchor via resolve_anchor_path() and validates CSV column names
%   - Upserts sweep_summary.csv keyed by (R, arch) so running R_list subsets never overwrites prior R results
%
% Optional workspace overrides before running:
%   sweep_mode : 'quick' | 'full' | 'both' (default: 'quick')
%   R_list     : subset of [16, 48, 64] (default: [16, 48, 64])
%   nd_R64     : draw count for R=64 in 'full' mode (default: 50, drops to 30 if quick test >120 s/draw)

exp_dir  = fileparts(mfilename('fullpath'));
src_dir  = fileparts(exp_dir);
code_dir = fileparts(src_dir);
m4_root  = fileparts(code_dir);

addpath(src_dir);
setup_paths();

if ~exist('sweep_mode', 'var'), sweep_mode = 'quick'; end
if ~exist('R_list', 'var'), R_list = [16, 48, 64]; end

Rg_val = 4;

if strcmp(sweep_mode, 'quick') || strcmp(sweep_mode, 'both')
    fprintf('=================================================================\n');
    fprintf('  TASK 4 QUICK TEST (3 DRAWS PER R, SC/GC/FC): R = [%s], Rg = %d\n', num2str(R_list), Rg_val);
    fprintf('=================================================================\n\n');
    quick_times_per_draw = zeros(size(R_list));
    for idx_r = 1:numel(R_list)
        R_val = R_list(idx_r);
        G_val = R_val / Rg_val;
        cfg = default_config(struct( ...
            'N', 2, 'K', 2, 'R', R_val, 'G', G_val, ...
            'Pmax_dBm', 20, 'N0_dBm', -80, ...
            'fading', 'rayleigh', 'nu', 1.0, 'eps_tol', 1e-8, ...
            'max_iter', 8000, 'seed_base', 0, ...
            'num_draws', 3, 'run_joint', false));

        out_dir = fullfile(m4_root, 'Results', 'sweep_ris_size', sprintf('R%d', R_val), 'quick_test_3draws');
        ckpt_path = fullfile(out_dir, 'checkpoint.mat');
        t0 = tic;
        res = run_matched_experiment(cfg, struct('checkpoint_file', ckpt_path, 'resume', true, 'fail_on_error', true));
        elapsed = toc(t0);
        quick_times_per_draw(idx_r) = elapsed / cfg.num_draws;

        save_matched_results(res, out_dir);
        plot_matched_results(res, out_dir);

        fprintf('[QUICK OK] R=%d (G=%d, SC/GC/FC): 3 draws in %.2fs (%.2fs/draw) -> %s\n\n', ...
            R_val, G_val, elapsed, quick_times_per_draw(idx_r), out_dir);
    end
end

if strcmp(sweep_mode, 'full') || strcmp(sweep_mode, 'both')
    fprintf('=================================================================\n');
    fprintf('  TASK 4 FULL EXPERIMENT (SC/GC/FC): R = [%s], Rg = %d\n', num2str(R_list), Rg_val);
    fprintf('=================================================================\n\n');

    % Resolve M2 R=32 anchor baseline (Priority 1: M4 anchor copy, Priority 2: read-only M2 Results)
    [anchor_sum_csv, src_sum] = resolve_anchor_path('summary.csv');
    [anchor_per_csv, src_per] = resolve_anchor_path('per_draw.csv');
    fprintf('Using M2 R=32 anchor (%s): %s\n', src_sum, anchor_sum_csv);
    fprintf('Using M2 R=32 anchor (%s): %s\n\n', src_per, anchor_per_csv);
    anchor_rows = build_m2_anchor_rows(anchor_sum_csv, anchor_per_csv);
    summary_csv = fullfile(m4_root, 'Results', 'sweep_ris_size', 'sweep_summary.csv');

    new_rows = [];
    for idx_r = 1:numel(R_list)
        R_val = R_list(idx_r);
        G_val = R_val / Rg_val;

        if R_val == 64
            if exist('nd_R64', 'var') && ~isempty(nd_R64)
                n_draws = nd_R64;
            elseif exist('quick_times_per_draw', 'var') && numel(quick_times_per_draw) >= idx_r && quick_times_per_draw(idx_r) > 120
                n_draws = 30;
                fprintf('R=64 exceeded 120s/draw in quick test (%.1fs/draw); using 30 draws.\n', quick_times_per_draw(idx_r));
            else
                n_draws = 50;
            end
        else
            n_draws = 50;
        end

        cfg = default_config(struct( ...
            'N', 2, 'K', 2, 'R', R_val, 'G', G_val, ...
            'Pmax_dBm', 20, 'N0_dBm', -80, ...
            'fading', 'rayleigh', 'nu', 1.0, 'eps_tol', 1e-8, ...
            'max_iter', 8000, 'seed_base', 0, ...
            'num_draws', n_draws, 'run_joint', false));

        out_dir = fullfile(m4_root, 'Results', 'sweep_ris_size', sprintf('R%d', R_val));
        ckpt_path = fullfile(out_dir, 'checkpoint.mat');
        t0 = tic;
        res = run_matched_experiment(cfg, struct('checkpoint_file', ckpt_path, 'resume', true, 'fail_on_error', true));
        elapsed = toc(t0);

        save_matched_results(res, out_dir);
        plot_matched_results(res, out_dir);

        r_rows = [];
        sc_rec_mean = res.summary.rec_fv.mean(1);
        for a = 1:numel(cfg.arch_names)
            rec_caps = sum(~res.rec_conv(:, a));
            gen_caps = sum(~res.gen_conv(:, a));
            pct_of_means = 100 * (res.summary.gen_fv.mean(a) - res.summary.rec_fv.mean(a)) / res.summary.gen_fv.mean(a);
            row_sum = struct( ...
                'R', R_val, ...
                'arch', cfg.arch_names{a}, ...
                'Rg', cfg.Rg_list(a), ...
                'G', G_val, ...
                'num_draws', n_draws, ...
                'source', 'M4_run', ...
                'rec_fv_mean', res.summary.rec_fv.mean(a), ...
                'rec_fv_se', res.summary.rec_fv.se(a), ...
                'gen_fv_mean', res.summary.gen_fv.mean(a), ...
                'gen_fv_se', res.summary.gen_fv.se(a), ...
                'gap_fv_mean', res.summary.gap_fv.mean(a), ...
                'gap_fv_se', res.summary.gap_fv.se(a), ...
                'gap_fv_pct_of_means', pct_of_means, ...
                'per_draw_gap_fv_pct_mean', res.summary.gap_fv_pct.mean(a), ...
                'sc_control_gain_rec', res.summary.rec_fv.mean(a) - sc_rec_mean, ...
                'rec_mean_iters', mean(res.rec_it(:, a)), ...
                'gen_mean_iters', mean(res.gen_it(:, a)), ...
                'rec_cap_hits', rec_caps, ...
                'gen_cap_hits', gen_caps, ...
                'rec_armijo_hits_total', sum(res.rec_armijo_hits(:, a)), ...
                'gen_armijo_hits_total', sum(res.gen_armijo_hits(:, a)), ...
                'total_time_s', elapsed);
            r_rows = [r_rows; row_sum]; %#ok<AGROW>
        end
        new_rows = [new_rows; r_rows]; %#ok<AGROW>
        merged_tbl = upsert_sweep_summary(summary_csv, struct2table([anchor_rows; r_rows]));
        writetable(merged_tbl, summary_csv);

        fprintf('[FULL OK] R=%d (G=%d, %d draws) in %.1fs -> %s\n\n', ...
            R_val, G_val, n_draws, elapsed, out_dir);
    end

    fprintf('Updated merged sweep summary at %s (%d rows).\n', summary_csv, height(merged_tbl));
end

function anchor_rows = build_m2_anchor_rows(sum_csv, per_csv)
    tsum = readtable(sum_csv, 'TextType', 'char');
    tper = readtable(per_csv, 'TextType', 'char');
    per_cols = tper.Properties.VariableNames;
    sum_cols = tsum.Properties.VariableNames;

    if ~ismember('arch', per_cols)
        error('run_ris_size_sweep:InvalidAnchorSchema', ...
            'Anchor per-draw CSV %s missing required column ''arch''.', per_csv);
    end

    has_sum_schema = all(ismember({'metric', 'arch', 'mean', 'se'}, sum_cols));
    has_rec_it   = ismember('rec_iters', per_cols);
    has_gen_it   = ismember('gen_iters', per_cols);
    has_rec_time = ismember('rec_time_s', per_cols);
    has_gen_time = ismember('gen_time_s', per_cols);
    has_rec_arm  = ismember('rec_armijo_hits', per_cols);
    has_gen_arm  = ismember('gen_armijo_hits', per_cols);

    archs = {'SC', 'GC', 'FC'};
    Rgs   = [1, 4, 32];
    anchor_rows = repmat(struct( ...
        'R', 32, 'arch', '', 'Rg', 0, 'G', 8, 'num_draws', 50, 'source', 'M2_anchor', ...
        'rec_fv_mean', NaN, 'rec_fv_se', NaN, 'gen_fv_mean', NaN, 'gen_fv_se', NaN, ...
        'gap_fv_mean', NaN, 'gap_fv_se', NaN, ...
        'gap_fv_pct_of_means', NaN, 'per_draw_gap_fv_pct_mean', NaN, ...
        'sc_control_gain_rec', NaN, ...
        'rec_mean_iters', NaN, 'gen_mean_iters', NaN, ...
        'rec_cap_hits', NaN, 'gen_cap_hits', NaN, ...
        'rec_armijo_hits_total', NaN, 'gen_armijo_hits_total', NaN, ...
        'total_time_s', NaN), numel(archs), 1);

    for k = 1:numel(archs)
        ar = archs{k};
        sub = tper(strcmp(tper.arch, ar), :);
        if isempty(sub)
            error('run_ris_size_sweep:MissingAnchorArch', 'Missing arch=%s in %s.', ar, per_csv);
        end

        anchor_rows(k).arch      = ar;
        anchor_rows(k).Rg        = Rgs(k);
        anchor_rows(k).num_draws = height(sub);

        [anchor_rows(k).rec_fv_mean, anchor_rows(k).rec_fv_se] = ...
            read_anchor_metric(tsum, has_sum_schema, sub, per_cols, 'rec_fv', ar, sum_csv, per_csv);
        [anchor_rows(k).gen_fv_mean, anchor_rows(k).gen_fv_se] = ...
            read_anchor_metric(tsum, has_sum_schema, sub, per_cols, 'gen_fv', ar, sum_csv, per_csv);
        [anchor_rows(k).gap_fv_mean, anchor_rows(k).gap_fv_se] = ...
            read_anchor_metric(tsum, has_sum_schema, sub, per_cols, 'gap_fv', ar, sum_csv, per_csv);
        anchor_rows(k).gap_fv_pct_of_means = ...
            100 * (anchor_rows(k).gen_fv_mean - anchor_rows(k).rec_fv_mean) / anchor_rows(k).gen_fv_mean;
        [anchor_rows(k).per_draw_gap_fv_pct_mean, ~] = ...
            read_anchor_metric(tsum, has_sum_schema, sub, per_cols, 'gap_fv_pct', ar, sum_csv, per_csv);
        anchor_rows(k).sc_control_gain_rec = anchor_rows(k).rec_fv_mean - anchor_rows(1).rec_fv_mean;

        if has_rec_it
            anchor_rows(k).rec_mean_iters = mean(sub.rec_iters);
            anchor_rows(k).rec_cap_hits   = sum(sub.rec_iters >= 8000);
        end
        if has_gen_it
            anchor_rows(k).gen_mean_iters = mean(sub.gen_iters);
            anchor_rows(k).gen_cap_hits   = sum(sub.gen_iters >= 8000);
        end
        if has_rec_arm
            anchor_rows(k).rec_armijo_hits_total = sum(sub.rec_armijo_hits);
        end
        if has_gen_arm
            anchor_rows(k).gen_armijo_hits_total = sum(sub.gen_armijo_hits);
        end
        if has_rec_time && has_gen_time
            anchor_rows(k).total_time_s = sum(sub.rec_time_s) + sum(sub.gen_time_s);
        end
    end
end

function [m_val, se_val] = read_anchor_metric(tsum, has_sum_schema, sub, per_cols, metric_name, arch, sum_csv, per_csv)
    if has_sum_schema
        row = tsum(strcmp(tsum.metric, metric_name) & strcmp(tsum.arch, arch), :);
        if ~isempty(row)
            m_val  = row.mean(1);
            se_val = row.se(1);
            return;
        end
    end
    if ismember(metric_name, per_cols)
        vals = sub.(metric_name);
        vals = vals(~isnan(vals));
        m_val = mean(vals);
        if numel(vals) > 1
            se_val = std(vals) / sqrt(numel(vals));
        else
            se_val = 0;
        end
        return;
    end
    error('run_ris_size_sweep:MissingAnchorMetric', ...
        'Anchor metric ''%s'' for arch=''%s'' not found in %s or %s.', ...
        metric_name, arch, sum_csv, per_csv);
end

function tbl_out = upsert_sweep_summary(csv_path, new_tbl)
    if exist(csv_path, 'file') == 2
        old_tbl = readtable(csv_path, 'TextType', 'char');
        for i = 1:height(new_tbl)
            keep = ~(old_tbl.R == new_tbl.R(i) & strcmp(old_tbl.arch, new_tbl.arch{i}));
            old_tbl = old_tbl(keep, :);
        end
        tbl_out = [old_tbl; new_tbl];
    else
        tbl_out = new_tbl;
    end
    arch_order = zeros(height(tbl_out), 1);
    for i = 1:height(tbl_out)
        switch tbl_out.arch{i}
            case 'SC', arch_order(i) = 1;
            case 'GC', arch_order(i) = 2;
            case 'FC', arch_order(i) = 3;
            otherwise, arch_order(i) = 99;
        end
    end
    tbl_out.arch_order_tmp = arch_order;
    tbl_out = sortrows(tbl_out, {'R', 'arch_order_tmp'});
    tbl_out.arch_order_tmp = [];
end
