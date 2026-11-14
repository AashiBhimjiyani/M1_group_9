function [Theta, V, hist, info] = reciprocal_joint_optimizer(H_TX, H_RX, Theta_init, p, Rg, nu, opts)
% RECIPROCAL_JOINT_OPTIMIZER  Joint precoder and reciprocal BD-RIS scattering matrix design.
%   Combines:
%     - Li's closed-form auxiliary updates (li_aux_update)
%     - Li's optimal precoder update via bisection (li_precoder_update)
%     - Reciprocal Riemannian CGA Theta update with symmetry penalty -nu * ||Theta - Theta.'||_F^2
%     - Final exact symmetry and unitarity enforcement (enforce_symmetry_unitarity)
%
%   Inputs:
%       H_TX        : R x N BS-to-RIS channel
%       H_RX        : K x R RIS-to-user channel
%       Theta_init  : R x R initial scattering matrix
%       p           : configuration struct (p.Pmax, p.N0, etc.)
%       Rg          : block size (1 = SC, R/G = GC, R = FC)
%       nu          : symmetry penalty weight (default: 1.0)
%       opts        : optional struct with fields:
%                       .max_outer   : maximum outer alternating iterations (default: 300)
%                       .tol         : outer loop convergence tolerance in rate (default: 1e-6)
%                       .max_cg      : inner CG iterations per outer loop (default: 30)
%                       .V_init      : initial precoder (default: MMSE precoder)
%                       .n_restarts  : multi-start restart count (default: 1)
%                       .seed        : random seed for restarts
%                       .retraction  : 'polar' (default) or 'qr'
%
%   Outputs:
%       Theta       : R x R final reciprocal scattering matrix (strictly symmetric and unitary)
%       V           : N x K final transmit precoder (original units, ||V||_F^2 <= p.Pmax)
%       hist        : struct with convergence history:
%                       .sumrate  : rate per outer iteration before final enforcement (bps/Hz)
%                       .cg_iters : inner CG iteration count per outer step
%       info        : diagnostics struct:
%                       .rate_final    : sum-rate after exact symmetry/unitarity enforcement
%                       .pre_sym_err   : symmetry violation ||Theta - Theta.'||_F before final projection
%                       .final_sym_err : symmetry violation after final projection
%                       .final_uni_err : unitarity violation ||Theta'*Theta - I||_F
%                       .proj_loss     : rate loss due to final enforcement

    if nargin < 6 || isempty(nu), nu = 1.0; end
    if nargin < 7, opts = struct(); end

    rec_dir = fileparts(mfilename('fullpath'));
    addpath(rec_dir);
    addpath(fullfile(fileparts(rec_dir), 'nonreciprocal'));

    n_restarts = dflt(opts, 'n_restarts', 1);
    if isfield(opts, 'restarts'), n_restarts = opts.restarts; end

    if n_restarts == 1
        [Theta, V, hist, info] = reciprocal_joint_single(H_TX, H_RX, Theta_init, p, Rg, nu, opts);
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

    best_rate = -inf;
    best_idx  = 1;
    best_Theta = Theta_init;
    best_V    = [];
    best_hist = [];
    best_info = [];

    restarts_log = repmat(struct('restart_id', 0, 'rate', 0, 'iters', 0, 'converged', false, 'term_reason', ''), n_restarts, 1);

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
                    Th_init_s(idx, idx) = Q * Q.';
                end
            end
        end

        opts_s = opts;
        opts_s.n_restarts = 1;
        if isfield(opts_s, 'V_init') && s > 1, opts_s = rmfield(opts_s, 'V_init'); end

        [Th_s, V_s, h_s, inf_s] = reciprocal_joint_single(H_TX, H_RX, Th_init_s, p, Rg, nu, opts_s);
        rate_s = inf_s.rate_final;

        restarts_log(s).restart_id  = s;
        restarts_log(s).rate        = rate_s;
        restarts_log(s).iters       = numel(h_s.sumrate);
        restarts_log(s).converged   = inf_s.converged;
        restarts_log(s).term_reason = inf_s.termination_reason;

        if rate_s > best_rate
            best_rate  = rate_s;
            best_idx   = s;
            best_Theta = Th_s;
            best_V     = V_s;
            best_hist  = h_s;
            best_info  = inf_s;
        end
    end

    Theta = best_Theta;
    V     = best_V;
    hist  = best_hist;
    info  = best_info;
    info.best_restart_id    = best_idx;
    info.restarts           = restarts_log;
    info.all_rates          = [restarts_log.rate];
    info.converged          = best_info.converged;
    info.termination_reason = best_info.termination_reason;
end

function [Theta, V, hist, info] = reciprocal_joint_single(H_TX, H_RX, Theta_init, p, Rg, nu, opts)
    max_outer   = dflt(opts, 'max_outer', 300);
    tol         = dflt(opts, 'tol', 1e-6);
    max_cg      = dflt(opts, 'max_cg', 30);
    c_armijo    = dflt(opts, 'c_armijo', 1e-4);
    retract_mode = dflt(opts, 'retraction', 'polar');

    % ---- Channel Normalization (matching Li baseline) ----
    aG = sqrt(mean(abs(H_TX(:)).^2));
    aH = sqrt(mean(abs(H_RX(:)).^2));
    G  = H_TX / aG;
    Hr = H_RX / aH;
    scale = aG * aH / sqrt(p.N0);        % v_n = v * scale
    Pn    = p.Pmax * scale^2;            % normalised power budget

    Theta = Theta_init;
    E = Hr * Theta * G;

    if isfield(opts, 'V_init')
        Vn = opts.V_init * scale;
    else
        Vu = (E' * E + eye(size(G, 2))) \ E';             % MMSE precoder
        Vn = sqrt(Pn) * Vu / norm(Vu, 'fro');
    end

    hist.sumrate  = zeros(max_outer, 1);
    hist.cg_iters = zeros(max_outer, 1);
    rate_old = -inf;

    for it = 1:max_outer
        E = Hr * Theta * G;
        % 1. Update auxiliary variables (iota, tau)
        [iota, tau, ~] = li_aux_update(E, Vn, 1);
        
        % 2. Update precoder V via bisection
        Vn = li_precoder_update(E, iota, tau, Pn);
        
        % 3. Refresh auxiliary variables with new V
        [iota, tau] = li_aux_update(E, Vn, 1);
        
        % 4. Build subproblem matrices for Theta update
        [X, Y, Z] = li_theta_terms(G, Hr, Vn, iota, tau);
        
        % 5. Reciprocal Theta update (CGA on unitary manifold with symmetry penalty)
        [Theta, nit] = reciprocal_theta_cga(Theta, X, Y, Z, Rg, nu, max_cg, c_armijo, retract_mode);
        
        % 6. Evaluate outer rate
        E = Hr * Theta * G;
        [~, ~, sinr] = li_aux_update(E, Vn, 1);
        rate = sum(log2(1 + sinr));
        hist.sumrate(it)  = rate;
        hist.cg_iters(it) = nit;
        
        conv_step = abs(rate - rate_old) < tol;
        if conv_step, break; end
        rate_old = rate;
    end

    hist.sumrate  = hist.sumrate(1:it);
    hist.cg_iters = hist.cg_iters(1:it);

    % Pre-projection metrics
    pre_sym_err = norm(Theta - Theta.', 'fro');
    rate_pre = hist.sumrate(end);

    % Exact final symmetry and unitarity projection
    Theta = enforce_symmetry_unitarity(Theta, Rg);
    V = Vn / scale;

    % 1. Post-projection rate evaluated using old V (held fixed)
    final_sinr_oldV = calculate_sinr(H_TX, H_RX, Theta, V, p);
    rate_post_oldV = calculate_sumrate(final_sinr_oldV);

    % 2. Post-projection rate evaluated after updating V for the projected Theta
    V_updated = mmse_beamformer(H_TX, H_RX, Theta, p);
    final_sinr_updatedV = calculate_sinr(H_TX, H_RX, Theta, V_updated, p);
    rate_post_updatedV = calculate_sumrate(final_sinr_updatedV);

    % Primary rate is the standard achievable post-projection rate with old V
    rate_final = rate_post_oldV;

    converged = conv_step;
    if converged
        term_reason = 'converged_tol';
    else
        term_reason = 'hit_max_outer';
    end

    info.rate_final         = rate_final;
    info.rate_post_oldV     = rate_post_oldV;
    info.rate_post_updatedV = rate_post_updatedV;
    info.V_updated          = V_updated;
    info.rate_pre           = rate_pre;
    info.proj_loss          = rate_pre - rate_post_oldV;
    info.proj_loss_updatedV = rate_pre - rate_post_updatedV;
    info.pre_sym_err        = pre_sym_err;
    info.final_sym_err      = norm(Theta - Theta.', 'fro');
    info.final_uni_err      = norm(Theta' * Theta - eye(size(Theta, 1)), 'fro');
    info.outer_iters        = it;
    info.converged          = converged;
    info.termination_reason = term_reason;
end

function [Theta, nit] = reciprocal_theta_cga(Theta, X, Y, Z, Rg, nu, max_cg, c_armijo, retract_mode)
% Reciprocal Riemannian CGA update on block-unitary manifold with symmetry penalty
    R = size(Theta, 1);
    f = li_theta_objective(Theta, X, Y, Z) - nu * norm(Theta - Theta.', 'fro')^2;
    
    grad_e = reciprocal_theta_grad(Theta, X, Y, Z, Rg, nu);
    r = tproj(Theta, grad_e, Rg);
    Xi = r;
    alpha = 1 / max(norm(Xi, 'fro'), eps);
    nit = 0;

    for it = 1:max_cg
        gn = norm(r, 'fro');
        if gn < 1e-12, break; end
        slope = real(trace(r' * Xi));

        % Armijo line search
        ok = false;
        for ls = 1:50
            Tn = retract_block_unitary(Theta + alpha * Xi, Rg, retract_mode);
            fn = li_theta_objective(Tn, X, Y, Z) - nu * norm(Tn - Tn.', 'fro')^2;
            if fn >= f + c_armijo * alpha * slope
                ok = true;
                break;
            end
            alpha = alpha / 2;
        end
        if ~ok, break; end
        nit = it;

        % New gradient and Polak-Ribiere search direction
        grad_en = reciprocal_theta_grad(Tn, X, Y, Z, Rg, nu);
        rn = tproj(Tn, grad_en, Rg);
        rt = tproj(Tn, r, Rg);
        Xt = tproj(Tn, Xi, Rg);

        beta = max(0, real(trace(rn' * (rn - rt))) / (real(trace(r' * r)) + 1e-300));
        Xn = rn + beta * Xt;
        if real(trace(rn' * Xn)) <= 0
            Xn = rn;
        end

        small = (fn - f) < 1e-13 * (1 + abs(f));
        Theta = Tn;
        f = fn;
        r = rn;
        Xi = Xn;
        alpha = 2 * alpha;
        if small, break; end
    end
end

function Gr = reciprocal_theta_grad(Theta, X, Y, Z, Rg, nu)
% Combined Euclidean gradient: Li objective gradient - 4*nu*(Theta - Theta.')
    Full = 2 * (X' - Z * Theta * Y) - 4 * nu * (Theta - Theta.');
    R  = size(Theta, 1);
    Gr = zeros(R, R);
    for g = 1:(R / Rg)
        idx = (g-1)*Rg + 1 : g*Rg;
        Gr(idx, idx) = Full(idx, idx);
    end
end

function Tn = retract_block_unitary(Y, Rg, mode)
    if strcmp(mode, 'qr')
        R = size(Y, 1);
        Tn = zeros(R, R);
        for g = 1:(R / Rg)
            idx = (g-1)*Rg + 1 : g*Rg;
            [Q, R_mat] = qr(Y(idx, idx));
            D = diag(R_mat);
            ph = D ./ abs(D);
            Tn(idx, idx) = Q * diag(ph);
        end
    else
        % Polar retraction via SVD (default)
        Tn = project_unitary_blocks(Y, Rg);
    end
end

function T = tproj(Theta, Gam, Rg)
% Riemannian tangent space projection for block-unitary manifold
    R = size(Theta, 1);
    T = zeros(R, R);
    for g = 1:(R / Rg)
        idx = (g-1)*Rg + 1 : g*Rg;
        Tg = Theta(idx, idx);
        Gg = Gam(idx, idx);
        M  = Tg' * Gg;
        T(idx, idx) = Gg - Tg * (M + M') / 2;
    end
end

function v = dflt(s, name, d)
    if isfield(s, name), v = s.(name); else, v = d; end
end
