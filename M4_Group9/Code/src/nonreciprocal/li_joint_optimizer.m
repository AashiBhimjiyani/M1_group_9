function [Theta, V, hist, info] = li_joint_optimizer(H_TX, H_RX, Theta_init, p, Rg, opts)
% LI_JOINT_OPTIMIZER  General (non-reciprocal-capable) BD-RIS baseline:
%   joint transmit-precoder / scattering-matrix design of
%   H. Li, S. Shen, B. Clerckx, "Beyond Diagonal Reconfigurable Intelligent
%   Surfaces: From Transmitting and Reflecting Modes to Single-, Group-, and
%   Fully-Connected Architectures" (Algorithm 1), reflective mode, K_t = 0.
%
%   Supports multi-start / restarts via opts.n_restarts (default: 1).
%
%   Inputs  H_TX (R x N), H_RX (K x R)  -- exactly the outputs of Member 2's
%           generate_channels(p), so both methods see the same channel.
%           Theta_init : R x R block-unitary start (use the same one as Member 2)
%           p          : config struct (needs p.Pmax, p.N0)
%           Rg         : block size (1 = SC, R/G = GC, R = FC)
%           opts       : optional struct: max_outer (300), tol (1e-6 bps/Hz),
%                        max_cg (30), V_init (default: MMSE for Theta_init),
%                        n_restarts (default: 1), seed, verbose
%   Outputs Theta (R x R, block-unitary, generally NOT symmetric),
%           V (N x K, original units, ||V||_F^2 <= p.Pmax),
%           hist.sumrate (per outer iteration, bps/Hz), hist.cg_iters,
%           info (restarts log, best_restart_id, all_rates).

    if nargin < 6, opts = struct(); end
    n_restarts = dflt(opts, 'n_restarts', 1);
    if isfield(opts, 'restarts'), n_restarts = opts.restarts; end

    if n_restarts == 1
        [Theta, V, hist, inf_s] = li_joint_single(H_TX, H_RX, Theta_init, p, Rg, opts);
        info.best_restart_id    = 1;
        info.best_rate          = hist.sumrate(end);
        info.all_rates          = hist.sumrate(end);
        info.rate_final         = inf_s.rate_final;
        info.outer_iters        = inf_s.outer_iters;
        info.converged          = inf_s.converged;
        info.termination_reason = inf_s.termination_reason;
        return;
    end

    % Multi-start wrapper
    orig_rng = rng();
    cleanup_rng = onCleanup(@() rng(orig_rng));

    base_seed = [];
    if isfield(opts, 'seed'), base_seed = opts.seed;
    elseif isfield(p, 'seed'), base_seed = p.seed;
    end
    draw_id = dflt(opts, 'draw_id', dflt(p, 'draw_id', 0));

    restarts_log = repmat(struct('restart_id', 0, 'rate', 0, 'iters', 0, 'converged', false, 'term_reason', ''), n_restarts, 1);
    best_rate = -inf;
    best_idx = 1;
    best_Theta = Theta_init;
    best_V = [];
    best_hist = [];
    best_inf = [];

    for s = 1:n_restarts
        if s == 1
            Th_init_s = Theta_init;
        elseif isfield(opts, 'inits') && numel(opts.inits) >= s && ~isempty(opts.inits{s})
            Th_init_s = opts.inits{s};
        else
            if ~isempty(base_seed)
                s_seed = mod(base_seed + draw_id * 1000 + s * 17, 2^32);
                rng(s_seed, 'twister');
            end
            if Rg == 1
                Th_init_s = diag(exp(1i * 2 * pi * rand(p.R, 1)));
            else
                Th_init_s = zeros(p.R, p.R);
                for g = 1:(p.R / Rg)
                    idx = (g-1)*Rg + 1 : g*Rg;
                    [Q, ~] = qr((randn(Rg, Rg) + 1i * randn(Rg, Rg)) / sqrt(2));
                    Th_init_s(idx, idx) = Q;
                end
            end
        end

        opts_s = opts;
        opts_s.n_restarts = 1;
        if isfield(opts_s, 'V_init') && s > 1, opts_s = rmfield(opts_s, 'V_init'); end
        [Th_s, V_s, h_s, inf_s] = li_joint_single(H_TX, H_RX, Th_init_s, p, Rg, opts_s);
        rate_s = h_s.sumrate(end);

        restarts_log(s).restart_id  = s;
        restarts_log(s).rate        = rate_s;
        restarts_log(s).iters       = numel(h_s.sumrate);
        restarts_log(s).converged   = inf_s.converged;
        restarts_log(s).term_reason = inf_s.termination_reason;

        if rate_s > best_rate
            best_rate = rate_s;
            best_idx = s;
            best_Theta = Th_s;
            best_V = V_s;
            best_hist = h_s;
            best_inf = inf_s;
        end
    end

    Theta = best_Theta;
    V = best_V;
    hist = best_hist;
    info.best_restart_id    = best_idx;
    info.best_rate          = best_rate;
    info.rate_final         = best_rate;
    info.outer_iters        = best_inf.outer_iters;
    info.restarts           = restarts_log;
    info.all_rates          = [restarts_log.rate];
    info.converged          = best_inf.converged;
    info.termination_reason = best_inf.termination_reason;
end

function [Theta, V, hist, info] = li_joint_single(H_TX, H_RX, Theta_init, p, Rg, opts)
    max_outer = dflt(opts, 'max_outer', 300);
    tol       = dflt(opts, 'tol', 1e-6);
    max_cg    = dflt(opts, 'max_cg', 30);

    % ---- normalisation: noise -> 1, channels -> unit-variance scale ----
    aG = sqrt(mean(abs(H_TX(:)).^2));
    aH = sqrt(mean(abs(H_RX(:)).^2));
    G  = H_TX / aG;   Hr = H_RX / aH;
    scale = aG * aH / sqrt(p.N0);        % v_n = v * scale
    Pn    = p.Pmax * scale^2;            % normalised power budget

    Theta = Theta_init;
    E = Hr * Theta * G;
    if isfield(opts, 'V_init')
        Vn = opts.V_init * scale;
    else
        Vu = (E' * E + eye(size(G, 2))) \ E';             % MMSE precoder, sigma^2 = 1
        Vn = sqrt(Pn) * Vu / norm(Vu, 'fro');
    end

    hist.sumrate = zeros(max_outer, 1);
    hist.cg_iters = zeros(max_outer, 1);
    rate_old = -inf;
    for it = 1:max_outer
        E = Hr * Theta * G;
        [iota, tau, ~] = li_aux_update(E, Vn, 1);                  % (17),(18)
        Vn = li_precoder_update(E, iota, tau, Pn);                 % (19),(20)
        [iota, tau] = li_aux_update(E, Vn, 1);                     % refresh with new V
        [X, Y, Z] = li_theta_terms(G, Hr, Vn, iota, tau);          % (23)
        [Theta, nit] = li_theta_update(Theta, X, Y, Z, Rg, max_cg);% Algorithm 2
        E = Hr * Theta * G;
        [~, ~, sinr] = li_aux_update(E, Vn, 1);
        rate = sum(log2(1 + sinr));
        hist.sumrate(it) = rate;
        hist.cg_iters(it) = nit;
        conv_step = abs(rate - rate_old) < tol;
        if conv_step, break; end
        rate_old = rate;
    end
    hist.sumrate  = hist.sumrate(1:it);
    hist.cg_iters = hist.cg_iters(1:it);
    Theta = project_unitary_blocks(Theta, Rg);                     % remove round-off
    V = Vn / scale;

    converged = conv_step;
    if converged
        term_reason = 'converged_tol';
    else
        term_reason = 'hit_max_outer';
    end

    info.outer_iters        = it;
    info.converged          = converged;
    info.termination_reason = term_reason;
    info.rate_final         = hist.sumrate(end);
end

function v = dflt(s, name, d)
    if isfield(s, name), v = s.(name); else, v = d; end
end
