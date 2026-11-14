% run_nu_sensitivity.m
% Member 2 Task 3: Penalty sensitivity experiment across nu in {0.1, 1, 10}.
% Evaluates GC (Rg = 4, G = 8) and FC (Rg = 32, G = 1) over 20 matched
% Rayleigh channel draws (seeds 1..20) at R = 32, N = 2, K = 2, Pmax = 20 dBm.
% Uses Member 4's common_* helpers, includes per-run checkpointing/resume,
% and records Armijo limit-hit counts.
%
% Records per run:
%   - Sum rate (reciprocal pre/post-projection, recomputed-V, general fixed-V)
%   - Sum-rate gap (gen_fv - rec_post)
%   - Iteration count (reciprocal and general fixed-V)
%   - Armijo max-step hit counts (reciprocal and general fixed-V)
%   - Convergence / cap status
%   - Projection cost (rate_pre - rate_post) and symmetry residual
%
% Outputs saved under M4_Group9/Results/diagnostics/nu_sensitivity/:
%   - nu_sensitivity_per_run.csv
%   - nu_sensitivity_summary.csv
%   - nu_sensitivity_results.mat
%   - nu_sensitivity_plots.png
%   - nu_sensitivity_high_cap_per_run.csv    (when run_high_cap_subset = true)
%   - nu_sensitivity_high_cap_summary.csv    (when run_high_cap_subset = true)
%   - nu_sensitivity_high_cap_results.mat    (when run_high_cap_subset = true)

fprintf('=================================================================\n');
fprintf('  M4 TASK 3: PENALTY SENSITIVITY (nu in {0.1, 1, 10}, GC & FC)\n');
fprintf('=================================================================\n\n');

exp_dir  = fileparts(mfilename('fullpath'));
src_dir  = fileparts(exp_dir);
code_dir = fileparts(src_dir);
m4_root  = fileparts(code_dir);

addpath(src_dir);
setup_paths();

out_dir = fullfile(m4_root, 'Results', 'diagnostics', 'nu_sensitivity');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
ckpt_file = fullfile(out_dir, 'nu_sensitivity_checkpoint.mat');
hc_ckpt_file = fullfile(out_dir, 'nu_sensitivity_high_cap_checkpoint.mat');

if ~exist('max_iter_nu', 'var'), max_iter_nu = 8000; end
if ~exist('nd_nu', 'var'), nd_nu = 20; end
if ~exist('resume_ckpt', 'var'), resume_ckpt = true; end
if ~exist('run_high_cap_subset', 'var'), run_high_cap_subset = true; end
if ~exist('high_cap_nu', 'var'), high_cap_nu = 25000; end
if ~exist('high_cap_seeds', 'var'), high_cap_seeds = [1, 6, 11, 16]; end

p = default_config(struct( ...
    'N', 2, 'K', 2, 'R', 32, 'G', 8, ...
    'Pmax_dBm', 20, 'N0_dBm', -80, ...
    'fading', 'rayleigh', 'eps_tol', 1e-8, ...
    'max_iter', max_iter_nu, 'run_joint', false));

nu_values  = [0.1, 1.0, 10.0];
arch_names = {'GC', 'FC'};
Rg_list    = [4, 32];
seeds      = 1:nd_nu;

n_arch = numel(arch_names);
n_nu   = numel(nu_values);
total_runs = n_arch * n_nu * nd_nu;

rows = repmat(struct( ...
    'arch', '', 'Rg', 0, 'G', 0, 'nu', 0, 'draw', 0, 'seed', 0, 'cap', max_iter_nu, ...
    'rec_rate_pre', 0, 'rec_rate_post', 0, 'rec_rate_v2', 0, ...
    'gen_rate_fv', 0, 'gen_rate_v2', 0, 'gap_fv', 0, 'gap_fv_pct', 0, ...
    'proj_cost', 0, 'penalty_residual', 0, 'final_sym_err', 0, 'final_uni_err', 0, ...
    'rec_iters', 0, 'gen_iters', 0, ...
    'rec_armijo_hits', 0, 'gen_armijo_hits', 0, ...
    'rec_converged', false, 'rec_hit_cap', false, 'rec_status', '', 'rec_term_reason', '', ...
    'gen_converged', false, 'gen_hit_cap', false, 'gen_status', '', ...
    'rec_time_s', 0, 'gen_time_s', 0), total_runs, 1);

% Cache general fixed-V results per (arch, draw) since nu = 0 does not depend on nu
gen_cache = cell(n_arch, nd_nu);
done_mask = false(total_runs, 1);

if resume_ckpt && exist(ckpt_file, 'file') == 2
    S_ckpt = load(ckpt_file);
    if isfield(S_ckpt, 'total_runs') && S_ckpt.total_runs == total_runs && ...
            isfield(S_ckpt, 'max_iter_nu') && S_ckpt.max_iter_nu == max_iter_nu && ...
            isfield(S_ckpt, 'rows') && isfield(S_ckpt, 'done_mask') && ...
            isfield(S_ckpt, 'p') && isfield(S_ckpt, 'nu_values') && isequal(S_ckpt.nu_values, nu_values) && ...
            isfield(S_ckpt, 'arch_names') && isequal(S_ckpt.arch_names, arch_names) && ...
            isfield(S_ckpt, 'Rg_list') && isequal(S_ckpt.Rg_list, Rg_list) && ...
            isfield(S_ckpt, 'seeds') && isequal(S_ckpt.seeds, seeds)
        [ckpt_ok, ckpt_reason] = configs_match_ckpt(S_ckpt.p, p);
        if ckpt_ok
            rows = S_ckpt.rows;
            done_mask = S_ckpt.done_mask;
            if isfield(S_ckpt, 'gen_cache'), gen_cache = S_ckpt.gen_cache; end
            fprintf('[Resume] Loaded checkpoint %s (%d/%d runs complete).\n\n', ...
                ckpt_file, sum(done_mask), total_runs);
        else
            fprintf('[Checkpoint] Ignoring stale checkpoint %s (%s). Starting fresh.\n\n', ...
                ckpt_file, ckpt_reason);
        end
    else
        fprintf('[Checkpoint] Ignoring incomplete/stale checkpoint %s. Starting fresh.\n\n', ckpt_file);
    end
end

fprintf('Running %d draws (seeds 1..%d) x %d architectures x %d nu values (max_iter=%d)...\n\n', ...
    nd_nu, nd_nu, n_arch, n_nu, max_iter_nu);

row_idx = 0;
for a = 1:n_arch
    arch = arch_names{a};
    Rg   = Rg_list(a);
    G    = p.R / Rg;

    for i_nu = 1:n_nu
        nu = nu_values(i_nu);
        fprintf('--- %s (Rg=%d, G=%d), nu = %g ---\n', arch, Rg, G, nu);

        for d = 1:nd_nu
            row_idx = row_idx + 1;
            if done_mask(row_idx)
                fprintf('  seed %2d [SKIP cached]\n', seeds(d));
                continue;
            end
            seed = seeds(d);

            rng(p.seed_base + seed, 'twister');
            [H_TX, H_RX] = common_generate_channels(p);
            Theta_init   = common_init_theta(p);
            V            = common_mmse_beamformer(H_TX, H_RX, Theta_init, p);

            % General fixed-V baseline (run once per arch & draw)
            if isempty(gen_cache{a, d})
                tg = tic;
                [Th_gen, hf, of] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p, Rg);
                gen_t = toc(tg);
                rate_gen_fv = common_sumrate(common_sinr(H_TX, H_RX, Th_gen, V, p));
                Vg_v2       = common_mmse_beamformer(H_TX, H_RX, Th_gen, p);
                rate_gen_v2 = common_sumrate(common_sinr(H_TX, H_RX, Th_gen, Vg_v2, p));
                gen_cache{a, d} = struct( ...
                    'rate_fv', rate_gen_fv, ...
                    'rate_v2', rate_gen_v2, ...
                    'iters', numel(hf.sumrate), ...
                    'armijo_hits', of.armijo_max_hits, ...
                    'converged', of.converged, ...
                    'status', status_str(of.converged), ...
                    'time_s', gen_t);
            end
            gc = gen_cache{a, d};

            % Reciprocal optimizer
            tr = tic;
            [Th_opt, hr, ir] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p, Rg, nu);
            rec_t = toc(tr);

            rate_pre  = common_sumrate(common_sinr(H_TX, H_RX, Th_opt, V, p));
            pen_res   = norm(Th_opt - Th_opt.', 'fro');

            Th_final  = enforce_symmetry_unitarity(Th_opt, Rg);
            rate_post = common_sumrate(common_sinr(H_TX, H_RX, Th_final, V, p));
            V2_rec    = common_mmse_beamformer(H_TX, H_RX, Th_final, p);
            rate_v2   = common_sumrate(common_sinr(H_TX, H_RX, Th_final, V2_rec, p));

            proj_cost = rate_pre - rate_post;
            gap_fv    = gc.rate_fv - rate_post;
            gap_pct   = 100 * gap_fv / gc.rate_fv;

            rows(row_idx).arch             = arch;
            rows(row_idx).Rg               = Rg;
            rows(row_idx).G                = G;
            rows(row_idx).nu               = nu;
            rows(row_idx).draw             = d;
            rows(row_idx).seed             = seed;
            rows(row_idx).cap              = max_iter_nu;
            rows(row_idx).rec_rate_pre     = rate_pre;
            rows(row_idx).rec_rate_post    = rate_post;
            rows(row_idx).rec_rate_v2      = rate_v2;
            rows(row_idx).gen_rate_fv      = gc.rate_fv;
            rows(row_idx).gen_rate_v2      = gc.rate_v2;
            rows(row_idx).gap_fv           = gap_fv;
            rows(row_idx).gap_fv_pct       = gap_pct;
            rows(row_idx).proj_cost        = proj_cost;
            rows(row_idx).penalty_residual = pen_res;
            rows(row_idx).final_sym_err    = norm(Th_final - Th_final.', 'fro');
            rows(row_idx).final_uni_err    = norm(Th_final' * Th_final - eye(p.R), 'fro');
            rows(row_idx).rec_iters        = numel(hr.sumrate);
            rows(row_idx).gen_iters        = gc.iters;
            rows(row_idx).rec_armijo_hits  = ir.armijo_max_hits;
            rows(row_idx).gen_armijo_hits  = gc.armijo_hits;
            rows(row_idx).rec_converged    = ir.converged;
            rows(row_idx).rec_hit_cap      = ~ir.converged;
            rows(row_idx).rec_status       = status_str(ir.converged);
            rows(row_idx).rec_term_reason  = ir.termination_reason;
            rows(row_idx).gen_converged    = gc.converged;
            rows(row_idx).gen_hit_cap      = ~gc.converged;
            rows(row_idx).gen_status       = gc.status;
            rows(row_idx).rec_time_s       = rec_t;
            rows(row_idx).gen_time_s       = gc.time_s;

            done_mask(row_idx) = true;
            save(ckpt_file, 'rows', 'done_mask', 'gen_cache', 'total_runs', 'max_iter_nu', ...
                'nu_values', 'arch_names', 'Rg_list', 'seeds', 'p', '-v7');
            writetable(struct2table(rows(done_mask)), fullfile(out_dir, 'nu_sensitivity_per_run.csv'));
            partial_rows = rows(done_mask);
            save(fullfile(out_dir, 'nu_sensitivity_results.mat'), 'partial_rows', 'done_mask', ...
                'nu_values', 'arch_names', 'Rg_list', 'seeds', 'p', '-v7');

            fprintf('  seed %2d | rec=%.4f | gen=%.4f | gap=%+.4f | proj=%+.2e | res=%.2e | it=%4d (%s, arm=%d)\n', ...
                seed, rate_post, gc.rate_fv, gap_fv, proj_cost, pen_res, ...
                rows(row_idx).rec_iters, rows(row_idx).rec_status, rows(row_idx).rec_armijo_hits);
        end
        fprintf('\n');
    end
end

% Summary table across (arch, nu), separating convergence status from sum-rate metrics
sum_rows = repmat(struct( ...
    'arch', '', 'Rg', 0, 'nu', 0, 'cap', max_iter_nu, 'n_draws', 0, ...
    'rec_converged_count', 0, 'rec_hit_cap_count', 0, ...
    'gen_converged_count', 0, 'gen_hit_cap_count', 0, ...
    'rec_armijo_hits_total', 0, 'gen_armijo_hits_total', 0, ...
    'mean_rec_rate_post', 0, 'se_rec_rate_post', 0, ...
    'mean_rec_rate_post_conv_only', NaN, 'se_rec_rate_post_conv_only', NaN, ...
    'mean_rec_rate_pre', 0, 'mean_gen_rate_fv', 0, 'se_gen_rate_fv', 0, ...
    'mean_gap_fv', 0, 'se_gap_fv', 0, 'pct_gap_of_means', 0, 'mean_per_draw_gap_fv_pct', 0, ...
    'mean_gap_fv_conv_only', NaN, 'se_gap_fv_conv_only', NaN, ...
    'mean_proj_cost', 0, 'se_proj_cost', 0, ...
    'mean_penalty_residual', 0, 'se_penalty_residual', 0, ...
    'mean_rec_iters', 0, 'max_rec_iters', 0, 'mean_gen_iters', 0), n_arch * n_nu, 1);

s_idx = 0;
for a = 1:n_arch
    arch = arch_names{a};
    Rg   = Rg_list(a);
    for i_nu = 1:n_nu
        nu = nu_values(i_nu);
        s_idx = s_idx + 1;
        mask = strcmp({rows.arch}, arch) & ([rows.nu] == nu);
        sub = rows(mask);
        n_sub = numel(sub);
        rec_conv_mask = [sub.rec_converged];
        n_conv = sum(rec_conv_mask);

        sum_rows(s_idx).arch                  = arch;
        sum_rows(s_idx).Rg                    = Rg;
        sum_rows(s_idx).nu                    = nu;
        sum_rows(s_idx).cap                   = max_iter_nu;
        sum_rows(s_idx).n_draws               = n_sub;
        sum_rows(s_idx).rec_converged_count   = n_conv;
        sum_rows(s_idx).rec_hit_cap_count     = sum([sub.rec_hit_cap]);
        sum_rows(s_idx).gen_converged_count   = sum([sub.gen_converged]);
        sum_rows(s_idx).gen_hit_cap_count     = sum([sub.gen_hit_cap]);
        sum_rows(s_idx).rec_armijo_hits_total = sum([sub.rec_armijo_hits]);
        sum_rows(s_idx).gen_armijo_hits_total = sum([sub.gen_armijo_hits]);
        sum_rows(s_idx).mean_rec_rate_post    = mean([sub.rec_rate_post]);
        sum_rows(s_idx).se_rec_rate_post      = std([sub.rec_rate_post]) / sqrt(n_sub);
        if n_conv > 0
            rec_conv_vals = [sub(rec_conv_mask).rec_rate_post];
            gap_conv_vals = [sub(rec_conv_mask).gap_fv];
            sum_rows(s_idx).mean_rec_rate_post_conv_only = mean(rec_conv_vals);
            sum_rows(s_idx).mean_gap_fv_conv_only        = mean(gap_conv_vals);
            if n_conv > 1
                sum_rows(s_idx).se_rec_rate_post_conv_only = std(rec_conv_vals) / sqrt(n_conv);
                sum_rows(s_idx).se_gap_fv_conv_only        = std(gap_conv_vals) / sqrt(n_conv);
            else
                sum_rows(s_idx).se_rec_rate_post_conv_only = 0;
                sum_rows(s_idx).se_gap_fv_conv_only        = 0;
            end
        end
        sum_rows(s_idx).mean_rec_rate_pre     = mean([sub.rec_rate_pre]);
        sum_rows(s_idx).mean_gen_rate_fv      = mean([sub.gen_rate_fv]);
        sum_rows(s_idx).se_gen_rate_fv        = std([sub.gen_rate_fv]) / sqrt(n_sub);
        sum_rows(s_idx).mean_gap_fv               = mean([sub.gap_fv]);
        sum_rows(s_idx).se_gap_fv                 = std([sub.gap_fv]) / sqrt(n_sub);
        sum_rows(s_idx).pct_gap_of_means          = 100 * (sum_rows(s_idx).mean_gen_rate_fv - sum_rows(s_idx).mean_rec_rate_post) / sum_rows(s_idx).mean_gen_rate_fv;
        sum_rows(s_idx).mean_per_draw_gap_fv_pct  = mean([sub.gap_fv_pct]);
        sum_rows(s_idx).mean_proj_cost        = mean([sub.proj_cost]);
        sum_rows(s_idx).se_proj_cost          = std([sub.proj_cost]) / sqrt(n_sub);
        sum_rows(s_idx).mean_penalty_residual = mean([sub.penalty_residual]);
        sum_rows(s_idx).se_penalty_residual   = std([sub.penalty_residual]) / sqrt(n_sub);
        sum_rows(s_idx).mean_rec_iters        = mean([sub.rec_iters]);
        sum_rows(s_idx).max_rec_iters         = max([sub.rec_iters]);
        sum_rows(s_idx).mean_gen_iters        = mean([sub.gen_iters]);
    end
end

writetable(struct2table(rows), fullfile(out_dir, 'nu_sensitivity_per_run.csv'));
writetable(struct2table(sum_rows), fullfile(out_dir, 'nu_sensitivity_summary.csv'));
save(fullfile(out_dir, 'nu_sensitivity_results.mat'), 'rows', 'sum_rows', 'nu_values', 'arch_names', 'Rg_list', 'seeds', 'p', '-v7');

% Generate summary plots
fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 420]);
for sp = 1:3
    subplot(1, 3, sp); hold on; grid on;
    for a = 1:n_arch
        sub = sum_rows(strcmp({sum_rows.arch}, arch_names{a}));
        if sp == 1
            errorbar(1:n_nu, [sub.mean_gap_fv], [sub.se_gap_fv], '-o', 'LineWidth', 1.6, 'DisplayName', arch_names{a});
        elseif sp == 2
            plot(1:n_nu, max([sub.mean_proj_cost], 1e-12), '-s', 'LineWidth', 1.6, 'DisplayName', [arch_names{a} ' Proj Cost']);
            plot(1:n_nu, max([sub.mean_penalty_residual], 1e-12), '--^', 'LineWidth', 1.4, 'DisplayName', [arch_names{a} ' Residual']);
        else
            plot(1:n_nu, [sub.mean_rec_iters], '-d', 'LineWidth', 1.6, 'DisplayName', arch_names{a});
        end
    end
    set(gca, 'XTick', 1:n_nu, 'XTickLabel', {'0.1', '1', '10'});
    xlabel('\nu');
    if sp == 1
        ylabel('Mean Sum-Rate Gap (bps/Hz)');
        title('Reciprocity Gap vs \nu');
        legend('Location', 'best');
    elseif sp == 2
        set(gca, 'YScale', 'log');
        ylabel('Projection Cost / Residual');
        title('Projection Cost & Residual (log)');
        legend('Location', 'best');
    else
        ylabel('Mean Reciprocal Iterations');
        title(sprintf('Iterations vs \\nu (cap=%d)', max_iter_nu));
        legend('Location', 'best');
    end
end
exportgraphics(fig, fullfile(out_dir, 'nu_sensitivity_plots.png'), 'Resolution', 200);
close(fig);

fprintf('Saved nu sensitivity outputs to %s\n', out_dir);

% ---- Optional Higher-Cap Diagnostic on Representative Subset ----
if run_high_cap_subset && ~isempty(high_cap_seeds)
    fprintf('\n--- High-Cap Subset Check (max_iter = %d, seeds = [%s]) ---\n', ...
        high_cap_nu, num2str(high_cap_seeds));

    p_hc = p;
    p_hc.max_iter = high_cap_nu;
    n_hc_seeds = numel(high_cap_seeds);
    total_hc = n_arch * n_nu * n_hc_seeds;

    hc_rows = repmat(rows(1), total_hc, 1);
    hc_done = false(total_hc, 1);
    hc_gen_cache = cell(n_arch, n_hc_seeds);

    if resume_ckpt && exist(hc_ckpt_file, 'file') == 2
        S_hc = load(hc_ckpt_file);
        if isfield(S_hc, 'total_hc') && S_hc.total_hc == total_hc && ...
                isfield(S_hc, 'high_cap_nu') && S_hc.high_cap_nu == high_cap_nu && ...
                isfield(S_hc, 'high_cap_seeds') && isequal(S_hc.high_cap_seeds, high_cap_seeds) && ...
                isfield(S_hc, 'hc_rows') && isfield(S_hc, 'hc_done') && ...
                isfield(S_hc, 'p_hc') && isfield(S_hc, 'nu_values') && isequal(S_hc.nu_values, nu_values)
            [hc_ok, hc_reason] = configs_match_ckpt(S_hc.p_hc, p_hc);
            if hc_ok
                hc_rows = S_hc.hc_rows;
                hc_done = S_hc.hc_done;
                if isfield(S_hc, 'hc_gen_cache'), hc_gen_cache = S_hc.hc_gen_cache; end
                fprintf('[Resume] Loaded high-cap checkpoint %s (%d/%d complete).\n', ...
                    hc_ckpt_file, sum(hc_done), total_hc);
            else
                fprintf('[Checkpoint] Ignoring stale high-cap checkpoint (%s).\n', hc_reason);
            end
        end
    end

    hc_idx = 0;
    for a = 1:n_arch
        arch = arch_names{a};
        Rg   = Rg_list(a);
        G    = p_hc.R / Rg;
        for i_nu = 1:n_nu
            nu = nu_values(i_nu);
            for d_hc = 1:n_hc_seeds
                hc_idx = hc_idx + 1;
                if hc_done(hc_idx), continue; end
                seed = high_cap_seeds(d_hc);

                rng(p_hc.seed_base + seed, 'twister');
                [H_TX, H_RX] = common_generate_channels(p_hc);
                Theta_init   = common_init_theta(p_hc);
                V            = common_mmse_beamformer(H_TX, H_RX, Theta_init, p_hc);

                if isempty(hc_gen_cache{a, d_hc})
                    tg = tic;
                    [Th_gen, hf, of] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V, p_hc, Rg);
                    gen_t = toc(tg);
                    rate_gen_fv = common_sumrate(common_sinr(H_TX, H_RX, Th_gen, V, p_hc));
                    Vg_v2       = common_mmse_beamformer(H_TX, H_RX, Th_gen, p_hc);
                    rate_gen_v2 = common_sumrate(common_sinr(H_TX, H_RX, Th_gen, Vg_v2, p_hc));
                    hc_gen_cache{a, d_hc} = struct( ...
                        'rate_fv', rate_gen_fv, 'rate_v2', rate_gen_v2, ...
                        'iters', numel(hf.sumrate), 'armijo_hits', of.armijo_max_hits, ...
                        'converged', of.converged, 'status', status_str(of.converged), 'time_s', gen_t);
                end
                gc = hc_gen_cache{a, d_hc};

                tr = tic;
                [Th_opt, hr, ir] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p_hc, Rg, nu);
                rec_t = toc(tr);

                rate_pre  = common_sumrate(common_sinr(H_TX, H_RX, Th_opt, V, p_hc));
                pen_res   = norm(Th_opt - Th_opt.', 'fro');
                Th_final  = enforce_symmetry_unitarity(Th_opt, Rg);
                rate_post = common_sumrate(common_sinr(H_TX, H_RX, Th_final, V, p_hc));
                V2_rec    = common_mmse_beamformer(H_TX, H_RX, Th_final, p_hc);
                rate_v2   = common_sumrate(common_sinr(H_TX, H_RX, Th_final, V2_rec, p_hc));

                proj_cost = rate_pre - rate_post;
                gap_fv    = gc.rate_fv - rate_post;
                gap_pct   = 100 * gap_fv / gc.rate_fv;

                hc_rows(hc_idx).arch             = arch;
                hc_rows(hc_idx).Rg               = Rg;
                hc_rows(hc_idx).G                = G;
                hc_rows(hc_idx).nu               = nu;
                hc_rows(hc_idx).draw             = d_hc;
                hc_rows(hc_idx).seed             = seed;
                hc_rows(hc_idx).cap              = high_cap_nu;
                hc_rows(hc_idx).rec_rate_pre     = rate_pre;
                hc_rows(hc_idx).rec_rate_post    = rate_post;
                hc_rows(hc_idx).rec_rate_v2      = rate_v2;
                hc_rows(hc_idx).gen_rate_fv      = gc.rate_fv;
                hc_rows(hc_idx).gen_rate_v2      = gc.rate_v2;
                hc_rows(hc_idx).gap_fv           = gap_fv;
                hc_rows(hc_idx).gap_fv_pct       = gap_pct;
                hc_rows(hc_idx).proj_cost        = proj_cost;
                hc_rows(hc_idx).penalty_residual = pen_res;
                hc_rows(hc_idx).final_sym_err    = norm(Th_final - Th_final.', 'fro');
                hc_rows(hc_idx).final_uni_err    = norm(Th_final' * Th_final - eye(p_hc.R), 'fro');
                hc_rows(hc_idx).rec_iters        = numel(hr.sumrate);
                hc_rows(hc_idx).gen_iters        = gc.iters;
                hc_rows(hc_idx).rec_armijo_hits  = ir.armijo_max_hits;
                hc_rows(hc_idx).gen_armijo_hits  = gc.armijo_hits;
                hc_rows(hc_idx).rec_converged    = ir.converged;
                hc_rows(hc_idx).rec_hit_cap      = ~ir.converged;
                hc_rows(hc_idx).rec_status       = status_str(ir.converged);
                hc_rows(hc_idx).rec_term_reason  = ir.termination_reason;
                hc_rows(hc_idx).gen_converged    = gc.converged;
                hc_rows(hc_idx).gen_hit_cap      = ~gc.converged;
                hc_rows(hc_idx).gen_status       = gc.status;
                hc_rows(hc_idx).rec_time_s       = rec_t;
                hc_rows(hc_idx).gen_time_s       = gc.time_s;

                hc_done(hc_idx) = true;
                save(hc_ckpt_file, 'hc_rows', 'hc_done', 'hc_gen_cache', 'total_hc', ...
                    'high_cap_nu', 'high_cap_seeds', 'nu_values', 'p_hc', '-v7');
                writetable(struct2table(hc_rows(hc_done)), fullfile(out_dir, 'nu_sensitivity_high_cap_per_run.csv'));
                partial_hc_rows = hc_rows(hc_done);
                save(fullfile(out_dir, 'nu_sensitivity_high_cap_results.mat'), ...
                    'partial_hc_rows', 'hc_done', 'nu_values', 'arch_names', 'Rg_list', 'high_cap_seeds', 'p_hc', '-v7');
            end
        end
    end

    hc_sum = repmat(sum_rows(1), n_arch * n_nu, 1);
    hs_idx = 0;
    for a = 1:n_arch
        arch = arch_names{a};
        Rg   = Rg_list(a);
        for i_nu = 1:n_nu
            nu = nu_values(i_nu);
            hs_idx = hs_idx + 1;
            sub = hc_rows(strcmp({hc_rows.arch}, arch) & ([hc_rows.nu] == nu));
            n_sub = numel(sub);
            rec_conv_mask = [sub.rec_converged];
            n_conv = sum(rec_conv_mask);
            hc_sum(hs_idx).arch                  = arch;
            hc_sum(hs_idx).Rg                    = Rg;
            hc_sum(hs_idx).nu                    = nu;
            hc_sum(hs_idx).cap                   = high_cap_nu;
            hc_sum(hs_idx).n_draws               = n_sub;
            hc_sum(hs_idx).rec_converged_count   = n_conv;
            hc_sum(hs_idx).rec_hit_cap_count     = sum([sub.rec_hit_cap]);
            hc_sum(hs_idx).gen_converged_count   = sum([sub.gen_converged]);
            hc_sum(hs_idx).gen_hit_cap_count     = sum([sub.gen_hit_cap]);
            hc_sum(hs_idx).rec_armijo_hits_total = sum([sub.rec_armijo_hits]);
            hc_sum(hs_idx).gen_armijo_hits_total = sum([sub.gen_armijo_hits]);
            hc_sum(hs_idx).mean_rec_rate_post    = mean([sub.rec_rate_post]);
            hc_sum(hs_idx).se_rec_rate_post      = std([sub.rec_rate_post]) / sqrt(max(1, n_sub));
            if n_conv > 0
                hc_sum(hs_idx).mean_rec_rate_post_conv_only = mean([sub(rec_conv_mask).rec_rate_post]);
                hc_sum(hs_idx).mean_gap_fv_conv_only        = mean([sub(rec_conv_mask).gap_fv]);
                if n_conv > 1
                    hc_sum(hs_idx).se_rec_rate_post_conv_only = std([sub(rec_conv_mask).rec_rate_post]) / sqrt(n_conv);
                    hc_sum(hs_idx).se_gap_fv_conv_only        = std([sub(rec_conv_mask).gap_fv]) / sqrt(n_conv);
                else
                    hc_sum(hs_idx).se_rec_rate_post_conv_only = 0;
                    hc_sum(hs_idx).se_gap_fv_conv_only        = 0;
                end
            else
                hc_sum(hs_idx).mean_rec_rate_post_conv_only = NaN;
                hc_sum(hs_idx).se_rec_rate_post_conv_only   = NaN;
                hc_sum(hs_idx).mean_gap_fv_conv_only        = NaN;
                hc_sum(hs_idx).se_gap_fv_conv_only          = NaN;
            end
            hc_sum(hs_idx).mean_rec_rate_pre     = mean([sub.rec_rate_pre]);
            hc_sum(hs_idx).mean_gen_rate_fv      = mean([sub.gen_rate_fv]);
            hc_sum(hs_idx).se_gen_rate_fv        = std([sub.gen_rate_fv]) / sqrt(max(1, n_sub));
            hc_sum(hs_idx).mean_gap_fv               = mean([sub.gap_fv]);
            hc_sum(hs_idx).se_gap_fv                 = std([sub.gap_fv]) / sqrt(max(1, n_sub));
            hc_sum(hs_idx).pct_gap_of_means          = 100 * (hc_sum(hs_idx).mean_gen_rate_fv - hc_sum(hs_idx).mean_rec_rate_post) / hc_sum(hs_idx).mean_gen_rate_fv;
            hc_sum(hs_idx).mean_per_draw_gap_fv_pct  = mean([sub.gap_fv_pct]);
            hc_sum(hs_idx).mean_proj_cost        = mean([sub.proj_cost]);
            hc_sum(hs_idx).se_proj_cost          = std([sub.proj_cost]) / sqrt(max(1, n_sub));
            hc_sum(hs_idx).mean_penalty_residual = mean([sub.penalty_residual]);
            hc_sum(hs_idx).se_penalty_residual   = std([sub.penalty_residual]) / sqrt(max(1, n_sub));
            hc_sum(hs_idx).mean_rec_iters        = mean([sub.rec_iters]);
            hc_sum(hs_idx).max_rec_iters         = max([sub.rec_iters]);
            hc_sum(hs_idx).mean_gen_iters        = mean([sub.gen_iters]);
        end
    end

    writetable(struct2table(hc_rows), fullfile(out_dir, 'nu_sensitivity_high_cap_per_run.csv'));
    writetable(struct2table(hc_sum), fullfile(out_dir, 'nu_sensitivity_high_cap_summary.csv'));
    save(fullfile(out_dir, 'nu_sensitivity_high_cap_results.mat'), ...
        'hc_rows', 'hc_sum', 'nu_values', 'arch_names', 'Rg_list', 'high_cap_seeds', 'p_hc', '-v7');
    fprintf('Saved high-cap subset outputs to %s\n', out_dir);
end

function lbl = status_str(is_conv)
    if is_conv
        lbl = 'converged';
    else
        lbl = 'hit_cap';
    end
end
