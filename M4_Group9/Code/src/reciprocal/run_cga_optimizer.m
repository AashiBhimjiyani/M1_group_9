function [Theta, hist, info] = run_cga_optimizer(H_TX, H_RX, Theta_init, V, p, Rg, nu, opts)
% RUN_CGA_OPTIMIZER  Riemannian conjugate-gradient ascent for reciprocal BD-RIS.
%   Optimizes scattering matrix Theta on the (block-)unitary manifold with
%   symmetry penalty -nu * ||Theta - Theta.'||_F^2 and Armijo line search.
%
%   Supports multi-start / restarts option via opts.n_restarts (default: 1).
%   Compatible with general-side restart-budget API.
%
%   Inputs:
%       H_TX        : R x N BS-to-RIS channel
%       H_RX        : K x R RIS-to-user channel
%       Theta_init  : R x R initial scattering matrix (used for restart 1)
%       V           : N x K transmit beamformer (frozen during CGA)
%       p           : configuration struct (p.R, p.N0, etc.)
%       Rg          : block size (1 = SC, R/G = GC, R = FC)
%       nu          : symmetry penalty weight (M2 default: 1.0)
%       opts        : optional struct with fields:
%                       .n_restarts / .restarts : number of restarts (default: 1)
%                       .max_iter               : iteration cap (overrides p.max_iter; default: 8000)
%                       .eps_tol                : convergence tolerance (overrides p.eps_tol; default: 1e-8)
%                       .seed                   : random seed for restart generation
%                       .verbose                : display progress per restart (default: false)
%                       .inits                  : cell array of custom initial matrices
%
%   Outputs:
%       Theta       : optimized R x R scattering matrix from best restart
%       hist        : convergence history struct for best restart
%       info        : struct containing multi-start logging and diagnostics:
%                       .best_restart_id : index of selected best restart
%                       .best_rate       : post-projection sum-rate of best restart
%                       .restarts        : array of structs with per-restart metrics
%                       .all_rates       : array of post-projection rates for all restarts
%                       .Theta_final     : post-projection matrix for best restart

    if nargin < 8, opts = struct(); end

    % Preserve caller's global RNG state
    orig_rng = rng();
    cleanup_rng = onCleanup(@() rng(orig_rng));

    % Extract restart count from opts or p
    n_restarts = 1;
    if isfield(opts, 'n_restarts')
        n_restarts = opts.n_restarts;
    elseif isfield(opts, 'restarts')
        n_restarts = opts.restarts;
    elseif isfield(p, 'n_restarts')
        n_restarts = p.n_restarts;
    elseif isfield(p, 'restarts')
        n_restarts = p.restarts;
    end

    % Extract iteration cap and tolerance (opts takes precedence over p; default 8000)
    if isfield(opts, 'max_iter') && ~isempty(opts.max_iter)
        max_iter = opts.max_iter;
    elseif isfield(p, 'max_iter') && ~isempty(p.max_iter)
        max_iter = p.max_iter;
    else
        max_iter = 8000;
    end
    validateattributes(max_iter, {'numeric'}, {'scalar', 'integer', 'positive'});

    if isfield(opts, 'eps_tol') && ~isempty(opts.eps_tol)
        eps_tol = opts.eps_tol;
    elseif isfield(p, 'eps_tol') && ~isempty(p.eps_tol)
        eps_tol = p.eps_tol;
    else
        eps_tol = 1e-8;
    end

    verbose = false;
    if isfield(opts, 'verbose'), verbose = opts.verbose; end

    base_seed = [];
    if isfield(opts, 'seed'), base_seed = opts.seed;
    elseif isfield(p, 'seed'), base_seed = p.seed;
    end

    % Extract draw_id to ensure restart seeds vary across draws
    draw_id = 1;
    if isfield(opts, 'draw_id'), draw_id = opts.draw_id;
    elseif isfield(opts, 'draw'), draw_id = opts.draw;
    elseif isfield(p, 'draw_id'), draw_id = p.draw_id;
    elseif isfield(p, 'draw'), draw_id = p.draw;
    end

    % Preallocate restart log
    restarts_log = repmat(struct('restart_id', 0, ...
                                 'rate', 0, ...
                                 'pre_rate', 0, ...
                                 'obj', 0, ...
                                 'iters', 0, ...
                                 'armijo_max_hits', 0, ...
                                 'pre_sym_err', 0, ...
                                 'final_sym_err', 0, ...
                                 'final_uni_err', 0, ...
                                 'converged', false, ...
                                 'termination_reason', '', ...
                                 'Theta_opt', [], ...
                                 'Theta_final', []), n_restarts, 1);

    all_hists = cell(n_restarts, 1);

    for s = 1:n_restarts
        % Generate or select initial Theta for restart s
        if s == 1
            Th_init_s = Theta_init;
        elseif isfield(opts, 'inits') && numel(opts.inits) >= s && ~isempty(opts.inits{s})
            Th_init_s = opts.inits{s};
        else
            % Generate reproducible random symmetric unitary start matching Rg
            % Deterministic formula combining base_seed, draw_id, and restart ID s
            if ~isempty(base_seed)
                s_seed = mod(base_seed + draw_id * 1000 + s * 17, 2^32);
            else
                s_seed = mod(draw_id * 10000 + s * 137, 2^32);
            end
            rng(s_seed, 'twister');
            Th_init_s = generate_restart_init(p.R, Rg);
        end

        % Run single-start CGA optimizer
        [Th_opt_s, h_s, conv_s, term_reason_s] = run_cga_single(H_TX, H_RX, Th_init_s, V, p, Rg, nu, max_iter, eps_tol);

        % Enforce exact symmetry and unitarity
        Th_final_s = enforce_symmetry_unitarity(Th_opt_s, Rg);

        % Compute post-projection sum-rate
        [tau_s, ~] = fp_variables(H_TX, H_RX, Th_final_s, V, p);
        rate_s = calculate_sumrate(tau_s);

        % Record logging info
        restarts_log(s).restart_id         = s;
        restarts_log(s).rate               = rate_s;
        restarts_log(s).pre_rate           = h_s.sumrate(end);
        restarts_log(s).obj                = h_s.obj(end);
        restarts_log(s).iters              = numel(h_s.sumrate);
        restarts_log(s).armijo_max_hits    = sum(h_s.armijo_max_hit);
        restarts_log(s).pre_sym_err        = norm(Th_opt_s - Th_opt_s.', 'fro');
        restarts_log(s).final_sym_err      = norm(Th_final_s - Th_final_s.', 'fro');
        restarts_log(s).final_uni_err      = norm(Th_final_s' * Th_final_s - eye(p.R), 'fro');
        restarts_log(s).converged          = conv_s;
        restarts_log(s).termination_reason = term_reason_s;
        restarts_log(s).Theta_opt          = Th_opt_s;
        restarts_log(s).Theta_final        = Th_final_s;

        all_hists{s} = h_s;

        if verbose
            fprintf('  [Restart %d/%d] Rate = %.4f bps/Hz (pre: %.4f), Iters = %d, Term = %s, Pre-SymErr = %.2e\n', ...
                s, n_restarts, rate_s, restarts_log(s).pre_rate, restarts_log(s).iters, term_reason_s, restarts_log(s).pre_sym_err);
        end
    end

    % Best-of selection across restarts based on post-projection sum-rate
    all_rates = [restarts_log.rate];
    [best_rate, best_idx] = max(all_rates);

    Theta = restarts_log(best_idx).Theta_opt;
    hist  = all_hists{best_idx};

    info.best_restart_id    = best_idx;
    info.best_rate          = best_rate;
    info.restarts           = restarts_log;
    info.all_rates          = all_rates;
    info.iters              = restarts_log(best_idx).iters;
    info.max_iter           = max_iter;
    info.armijo_max_hits    = restarts_log(best_idx).armijo_max_hits;
    info.converged          = restarts_log(best_idx).converged;
    info.termination_reason = restarts_log(best_idx).termination_reason;
    info.Theta_final        = restarts_log(best_idx).Theta_final;

    if verbose && n_restarts > 1
        fprintf('  --> Best restart: %d with Rate = %.4f bps/Hz\n', best_idx, best_rate);
    end
end

function [Theta, hist, converged, term_reason] = run_cga_single(H_TX, H_RX, Theta_init, V, p, Rg, nu, max_iter, eps_tol)
    Theta = Theta_init;

    % Initial variables
    [tau, y] = fp_variables(H_TX, H_RX, Theta, V, p);
    obj_val = objective(H_TX, H_RX, Theta, V, tau, y, p, nu);

    % Initial gradient and direction
    grad_eucl = gradient_theta(H_TX, H_RX, Theta, V, tau, y, p, Rg, nu);
    r = tangent_projection(Theta, grad_eucl, Rg);

    % Initial direction is steepest ascent
    Xi = r;

    hist.sumrate = zeros(max_iter, 1);
    hist.obj = zeros(max_iter, 1);
    hist.alpha = zeros(max_iter, 1);
    hist.gnorm = zeros(max_iter, 1);
    hist.armijo_max_hit = false(max_iter, 1);
    converged = false;
    term_reason = 'hit_max_iter';

    for iter = 1:max_iter
        % 1. Armijo line search
        [Theta_new, alpha, max_hit] = armijo_search(H_TX, H_RX, Theta, V, tau, y, p, Rg, nu, obj_val, r, Xi);
        hist.alpha(iter) = alpha;
        hist.gnorm(iter) = norm(r, 'fro');
        hist.armijo_max_hit(iter) = max_hit;

        % 2. Update auxiliary variables
        [tau_new, y_new] = fp_variables(H_TX, H_RX, Theta_new, V, p);
        obj_new = objective(H_TX, H_RX, Theta_new, V, tau_new, y_new, p, nu);

        % Record history
        true_sum_rate = calculate_sumrate(tau_new);
        hist.sumrate(iter) = true_sum_rate;
        hist.obj(iter) = obj_new;

        % 3. Check convergence
        if abs(obj_new - obj_val) < eps_tol
            hist.sumrate = hist.sumrate(1:iter);
            hist.obj = hist.obj(1:iter);
            hist.alpha = hist.alpha(1:iter);
            hist.gnorm = hist.gnorm(1:iter);
            hist.armijo_max_hit = hist.armijo_max_hit(1:iter);
            Theta = Theta_new;
            converged = true;
            term_reason = 'converged_tol';
            return;
        end

        % Check line search stagnation
        if max_hit && abs(obj_new - obj_val) < 1e-14
            hist.sumrate = hist.sumrate(1:iter);
            hist.obj = hist.obj(1:iter);
            hist.alpha = hist.alpha(1:iter);
            hist.gnorm = hist.gnorm(1:iter);
            hist.armijo_max_hit = hist.armijo_max_hit(1:iter);
            Theta = Theta_new;
            converged = false;
            term_reason = 'line_search_failed';
            return;
        end

        % 4. Compute new gradient and tangent projection
        grad_eucl_new = gradient_theta(H_TX, H_RX, Theta_new, V, tau_new, y_new, p, Rg, nu);
        r_new = tangent_projection(Theta_new, grad_eucl_new, Rg);

        % In manifold optimization, moving the previous gradient to the new tangent space 
        % requires vector transport. Projecting the direction when it is transported.
        Xi_transported = tangent_projection(Theta_new, Xi, Rg);
        r_transported = tangent_projection(Theta_new, r, Rg);

        % 5. Polak-Ribiere beta
        num_pr = real(trace(r_new' * (r_new - r_transported)));
        den_pr = real(trace(r_transported' * r_transported)) + 1e-16;
        beta = max(0, num_pr / den_pr);

        % 6. Ascent check
        Xi_new = r_new + beta * Xi_transported;

        % If <r_new, Xi_new> <= 0, reset to steepest ascent
        if real(trace(r_new' * Xi_new)) <= 0
            Xi_new = r_new;
        end

        % Update loop variables
        Theta = Theta_new;
        tau = tau_new;
        y = y_new;
        obj_val = obj_new;
        r = r_new;
        Xi = Xi_new;
    end

    % If loop completes without hitting tolerance
    hist.sumrate = hist.sumrate(1:max_iter);
    hist.obj = hist.obj(1:max_iter);
    hist.alpha = hist.alpha(1:max_iter);
    hist.gnorm = hist.gnorm(1:max_iter);
    hist.armijo_max_hit = hist.armijo_max_hit(1:max_iter);
    term_reason = 'hit_max_iter';
end

function Th = generate_restart_init(R, Rg)
    % Generates a block-diagonal symmetric unitary matrix matching Rg
    if Rg == 1
        % SC: diagonal unit-modulus phases (trivially symmetric)
        Th = diag(exp(1i * 2 * pi * rand(R, 1)));
    else
        % GC or FC: block-diagonal symmetric unitary via Q * Q.'
        num_blocks = R / Rg;
        Th = zeros(R, R);
        for g = 1:num_blocks
            idx = (g-1)*Rg + 1 : g*Rg;
            [Q, ~] = qr((randn(Rg, Rg) + 1i * randn(Rg, Rg)) / sqrt(2));
            Th(idx, idx) = Q * Q.';
        end
    end
end
