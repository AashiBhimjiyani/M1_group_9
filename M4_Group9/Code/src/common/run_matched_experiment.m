function res = run_matched_experiment(p, run_opts)
% RUN_MATCHED_EXPERIMENT  Matched reciprocal-vs-general comparison.
%   Based directly on Member 4's M2 framework (run_matched_experiment.m,
%   common_generate_channels, common_init_theta, common_mmse_beamformer,
%   common_sinr, common_sumrate), extended in M4 with:
%     - p.max_iter / opts support (Issues 1, 12)
%     - Armijo limit-hit & convergence tracking (Issue 9)
%     - per-draw checkpointing & resume (Issue 8)
%     - explicit error propagation instead of silent NaNs (Issue 3)
%
%   For every draw d = 1..p.num_draws
%       rng(p.seed_base + d, 'twister') -> ONE channel, ONE Theta_init, ONE V0
%   and for every architecture (SC, GC, FC; block size Rg = p.Rg_list)
%       reciprocal  (Member 2): run_cga_optimizer(nu = p.nu) + enforce_symmetry_unitarity
%       general-fv  (Member 3): general_fixedV_optimizer  (same CGA, nu = 0, V frozen)
%       general-jt  (Member 3): li_joint_optimizer        (Li Alg. 1, optional)
%   All final rates are re-evaluated HERE with common_sinr/common_sumrate, so
%   the numbers are guaranteed to come from one metric implementation.
%
%   Naming:  *_fv = rate with the frozen initial V0
%            *_v2 = rate after recomputing the MMSE V at the final Theta
%            *_jt = rate of Li's jointly optimised (Theta, V)
%   Like-for-like reciprocity gap:  gap_fv = gen_fv - rec_fv ,  gap_v2 = gen_v2 - rec_v2
%   (positive = reciprocity costs rate).  gen_jt is NOT comparable to rec_*
%   (it also optimises V) -- see src/common/README.md.
    common_dir = fileparts(mfilename('fullpath'));
    src_dir    = fileparts(common_dir);
    addpath(src_dir);
    setup_paths();

    if nargin < 1 || isempty(p)
        p = default_config();
    elseif ~isfield(p, 'PL_BS_RIS') || ~isfield(p, 'arch_names') || ...
           ~isfield(p, 'Rg_list')   || ~isfield(p, 'max_iter')
        p = default_config(p);
    end
    if nargin < 2 || isempty(run_opts), run_opts = struct(); end

    ckpt_file     = get_run_opt(run_opts, 'checkpoint_file', '');
    do_resume     = get_run_opt(run_opts, 'resume', true);
    fail_on_error = get_run_opt(run_opts, 'fail_on_error', true);
    cga_opts      = get_run_opt(run_opts, 'cga_opts', struct());

    nd = p.num_draws;   na = numel(p.Rg_list);
    nanm = @() nan(nd, na);

    res.p = p;
    res.rate_init = nan(nd, 1);
    res.chan_fro  = nan(nd, 2);                 % [||H_TX||_F  ||H_RX||_F] fingerprint
    res.rec_fv = nanm();  res.rec_v2 = nanm();  res.rec_pre = nanm();
    res.rec_it = nanm();  res.rec_time = nanm();
    res.rec_sym = nanm(); res.rec_uni = nanm();
    res.rec_conv = false(nd, na);  res.rec_term = cell(nd, na);  res.rec_armijo_hits = nanm();
    res.gen_fv = nanm();  res.gen_v2 = nanm();  res.gen_it = nanm();  res.gen_time = nanm();
    res.gen_sym = nanm(); res.gen_uni = nanm();
    res.gen_conv = false(nd, na);  res.gen_term = cell(nd, na);  res.gen_armijo_hits = nanm();
    res.gen_jt = nanm();  res.jt_it = nanm();   res.jt_time = nanm();
    res.rec_hist = cell(nd, na);  res.gen_hist = cell(nd, na);  res.jt_hist = cell(nd, na);
    res.errors = {};
    done_mask = false(nd, na);

    if ~isempty(ckpt_file) && do_resume && exist(ckpt_file, 'file') == 2
        S_ckpt = load(ckpt_file);
        if isfield(S_ckpt, 'res') && isfield(S_ckpt, 'done_mask') && isfield(S_ckpt.res, 'p')
            if isfield(S_ckpt, 'cga_opts')
                ckpt_cga_opts = S_ckpt.cga_opts;
            else
                ckpt_cga_opts = struct();
            end
            [ckpt_ok, ckpt_reason] = configs_match_ckpt(S_ckpt.res.p, p, ckpt_cga_opts, cga_opts);
            if ckpt_ok
                res = S_ckpt.res;
                done_mask = S_ckpt.done_mask;
                fprintf('[Resume] Loaded checkpoint %s (%d/%d draw-arch pairs complete).\n', ...
                    ckpt_file, sum(done_mask(:)), nd * na);
            else
                fprintf('[Checkpoint] Ignoring stale checkpoint %s (%s). Starting fresh.\n', ...
                    ckpt_file, ckpt_reason);
            end
        end
    end

    for d = 1:nd
        % ---- ONE shared channel / start / precoder per draw ----
        rng(p.seed_base + d, 'twister');
        [H_TX, H_RX] = common_generate_channels(p);
        Theta_init   = common_init_theta(p);
        V0           = common_mmse_beamformer(H_TX, H_RX, Theta_init, p);
        res.chan_fro(d, :) = [norm(H_TX, 'fro'), norm(H_RX, 'fro')];
        res.rate_init(d)   = common_sumrate(common_sinr(H_TX, H_RX, Theta_init, V0, p));

        if all(done_mask(d, :))
            continue;
        end

        for a = 1:na
            if done_mask(d, a), continue; end
            Rg = p.Rg_list(a);
            try
                % ---------- reciprocal (Member 2) ----------
                t = tic;
                [Th_opt, h, ir] = run_cga_optimizer(H_TX, H_RX, Theta_init, V0, p, Rg, p.nu, cga_opts);
                Th = enforce_symmetry_unitarity(Th_opt, Rg);
                res.rec_time(d,a) = toc(t);
                res.rec_pre(d,a)  = common_sumrate(common_sinr(H_TX, H_RX, Th_opt, V0, p));
                res.rec_fv(d,a)   = common_sumrate(common_sinr(H_TX, H_RX, Th, V0, p));
                Vr = common_mmse_beamformer(H_TX, H_RX, Th, p);
                res.rec_v2(d,a)   = common_sumrate(common_sinr(H_TX, H_RX, Th, Vr, p));
                res.rec_it(d,a)   = numel(h.sumrate);
                res.rec_sym(d,a)  = norm(Th - Th.', 'fro');
                res.rec_uni(d,a)  = norm(Th'*Th - eye(p.R), 'fro');
                res.rec_conv(d,a) = ir.converged;
                res.rec_term{d,a} = ir.termination_reason;
                res.rec_armijo_hits(d,a) = ir.armijo_max_hits;
                res.rec_hist{d,a} = h.sumrate;

                % ---------- general, V frozen (Member 3, matched) ----------
                t = tic;
                [Tg, hg, og] = general_fixedV_optimizer(H_TX, H_RX, Theta_init, V0, p, Rg, cga_opts);
                res.gen_time(d,a) = toc(t);
                res.gen_fv(d,a)   = common_sumrate(common_sinr(H_TX, H_RX, Tg, V0, p));
                Vg = common_mmse_beamformer(H_TX, H_RX, Tg, p);
                res.gen_v2(d,a)   = common_sumrate(common_sinr(H_TX, H_RX, Tg, Vg, p));
                res.gen_it(d,a)   = numel(hg.sumrate);
                res.gen_sym(d,a)  = norm(Tg - Tg.', 'fro');
                res.gen_uni(d,a)  = norm(Tg'*Tg - eye(p.R), 'fro');
                res.gen_conv(d,a) = og.converged;
                res.gen_term{d,a} = og.termination_reason;
                res.gen_armijo_hits(d,a) = og.armijo_max_hits;
                res.gen_hist{d,a} = hg.sumrate;

                % ---------- general, joint V/Theta (Member 3, paper-faithful) ----------
                if p.run_joint
                    t = tic;
                    [Tj, Vj, hj] = li_joint_optimizer(H_TX, H_RX, Theta_init, p, Rg);
                    res.jt_time(d,a) = toc(t);
                    res.gen_jt(d,a)  = common_sumrate(common_sinr(H_TX, H_RX, Tj, Vj, p));
                    res.jt_it(d,a)   = numel(hj.sumrate);
                    res.jt_hist{d,a} = hj.sumrate;
                end

                done_mask(d, a) = true;
                fprintf('draw %2d/%d %-2s (Rg=%2d) | rec %.3f (%d it, arm=%d) | gen-fv %.3f (%d it, arm=%d) | gap %.3f\n', ...
                    d, nd, p.arch_names{a}, Rg, res.rec_fv(d,a), res.rec_it(d,a), res.rec_armijo_hits(d,a), ...
                    res.gen_fv(d,a), res.gen_it(d,a), res.gen_armijo_hits(d,a), res.gen_fv(d,a) - res.rec_fv(d,a));
            catch err
                msg = sprintf('draw %d, %s: %s', d, p.arch_names{a}, err.message);
                res.errors{end+1} = msg;                       %#ok<AGROW>
                if fail_on_error
                    error('run_matched_experiment:fail', '%s', msg);
                else
                    warning('run_matched_experiment:fail', '%s', msg);
                end
            end
        end

        if ~isempty(ckpt_file)
            ckpt_dir = fileparts(ckpt_file);
            if ~isempty(ckpt_dir) && ~exist(ckpt_dir, 'dir'), mkdir(ckpt_dir); end
            save(ckpt_file, 'res', 'done_mask', 'cga_opts', '-v7');
        end
    end

    % ---- like-for-like reciprocity gaps (positive = reciprocity costs rate) ----
    res.gap_fv     = res.gen_fv - res.rec_fv;
    res.gap_v2     = res.gen_v2 - res.rec_v2;
    res.gap_fv_pct = 100 * res.gap_fv ./ res.gen_fv;
    res.gap_v2_pct = 100 * res.gap_v2 ./ res.gen_v2;
    res.summary    = summarize_results(res);
end

function val = get_run_opt(s, field, default_val)
    if isfield(s, field) && ~isempty(s.(field))
        val = s.(field);
    else
        val = default_val;
    end
end

function S = summarize_results(res)
% mean / standard error / n over valid draws, per architecture
    fields = {'rec_fv','rec_v2','gen_fv','gen_v2','gen_jt','gap_fv','gap_v2','gap_fv_pct','gap_v2_pct'};
    for f = 1:numel(fields)
        X = res.(fields{f});
        n = sum(~isnan(X), 1);
        S.(fields{f}).mean = mean(X, 1, 'omitnan');
        S.(fields{f}).se   = std(X, 0, 1, 'omitnan') ./ sqrt(max(n, 1));
        S.(fields{f}).n    = n;
    end
end
