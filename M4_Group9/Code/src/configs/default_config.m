function p = default_config(overrides)
% DEFAULT_CONFIG  Single source of truth for every simulation setting (Member 4).
%
%   p = default_config()               -> project M2 test configuration
%   p = default_config(struct('R',16,'Pmax_dBm',10))   -> override any field(s)
%
%   The returned struct deliberately uses the SAME field names as
%   reciprocal/config.m (p.N, p.K, p.R, p.Pmax, p.N0, p.PL_BS_RIS, p.PL_RIS_user,
%   p.Kf_dB, p.Kf, p.eps_tol), so Member 2's and Member 3's functions accept it
%   unchanged.  Derived fields (linear power, noise, path loss, Rg list) are
%   recomputed AFTER the overrides, so you only ever set the "_dBm"/"_dB" inputs.
%
%   ---- inputs --------------------------------------------------------------
%   N, K, R        TX antennas, single-antenna users, RIS elements
%   G              number of groups for group-connected (GC); Rg = R/G
%   Pmax_dBm       total BS transmit power budget, ||V||_F^2 <= Pmax   [dBm]
%   N0_dBm         noise power per user                                  [dBm]
%   C0_dB, d0, rho path loss: PL = C0 * (d/d0)^(-rho)
%   d_BS_RIS, d_RIS_user  link distances                                 [m]
%   fading         'rayleigh' or 'rician'   (rician uses Kf_dB, default 2 dB)
%   seed_base      draw d uses rng(seed_base + d, 'twister')
%   num_draws      number of matched channel draws
%   nu             reciprocal symmetry-penalty weight
%   eps_tol        CGA stopping tolerance (abs. change of surrogate objective)
%   max_iter       CGA iteration cap for both reciprocal & general fixed-V (default 8000)
%   run_joint      also run Li's joint V/Theta design (slower)
    if nargin < 1, overrides = struct(); end

    % ---------------- system ----------------
    p.N = 2;   p.K = 2;   p.R = 32;   p.G = 8;
    % ---------------- power / noise ----------------
    p.Pmax_dBm = 20;
    p.N0_dBm   = -80;
    % ---------------- path loss ----------------
    p.C0_dB = -30;   p.d0 = 1.0;   p.rho = 2.2;
    p.d_BS_RIS = 50; p.d_RIS_user = 2.5;
    % ---------------- fading ----------------
    p.fading = 'rayleigh';
    p.Kf_dB  = -Inf;
    % ---------------- experiment ----------------
    p.seed_base = 0;
    p.num_draws = 5;
    p.nu        = 1.0;
    p.eps_tol   = 1e-8;
    p.max_iter  = 8000;
    p.run_joint = true;
    p.arch_names = {'SC', 'GC', 'FC'};

    % ---------------- apply overrides ----------------
    names = fieldnames(overrides);
    for i = 1:numel(names)
        p.(names{i}) = overrides.(names{i});
    end

    % ---------------- derived quantities ----------------
    has_fading = isfield(overrides, 'fading') && ~isempty(overrides.fading);
    has_Kf     = isfield(overrides, 'Kf_dB')  && ~isempty(overrides.Kf_dB);
    if has_Kf && ~has_fading
        if isinf(p.Kf_dB) && p.Kf_dB < 0
            p.fading = 'rayleigh';
        else
            p.fading = 'rician';
        end
    elseif has_fading && has_Kf
        is_ray_kf = isinf(p.Kf_dB) && p.Kf_dB < 0;
        if strcmpi(p.fading, 'rayleigh') && ~is_ray_kf
            error('default_config: fading=''rayleigh'' conflicts with finite Kf_dB=%g.', p.Kf_dB);
        elseif strcmpi(p.fading, 'rician') && is_ray_kf
            error('default_config: fading=''rician'' conflicts with Kf_dB=-Inf.');
        end
    end

    switch lower(p.fading)
        case 'rayleigh'
            p.fading = 'rayleigh';
            p.Kf_dB  = -Inf;
        case 'rician'
            p.fading = 'rician';
            if isinf(p.Kf_dB), p.Kf_dB = 2; end       % default Rician K-factor
        otherwise
            error('default_config: fading must be ''rayleigh'' or ''rician''.');
    end
    if isempty(p.max_iter)
        p.max_iter = 8000;
    end
    validateattributes(p.max_iter, {'numeric'}, {'scalar', 'integer', 'positive'});
    if mod(p.R, p.G) ~= 0
        error('default_config: R (%d) must be divisible by G (%d).', p.R, p.G);
    end
    p.Pmax = 10^(p.Pmax_dBm/10) * 1e-3;                 % W
    p.N0   = 10^(p.N0_dBm/10)   * 1e-3;                 % W
    p.C0   = 10^(p.C0_dB/10);
    p.PL_BS_RIS   = common_pathloss(p.C0_dB, p.d_BS_RIS,   p.d0, p.rho);
    p.PL_RIS_user = common_pathloss(p.C0_dB, p.d_RIS_user, p.d0, p.rho);
    p.Kf = 10^(p.Kf_dB/10);                             % 0 for Rayleigh

    % ---------------- architectures (block size Rg) ----------------
    if ~isfield(overrides, 'Rg_list') || isempty(overrides.Rg_list)
        p.Rg_list = zeros(1, numel(p.arch_names));
        for idx_a = 1:numel(p.arch_names)
            switch upper(p.arch_names{idx_a})
                case 'SC', p.Rg_list(idx_a) = 1;
                case 'GC', p.Rg_list(idx_a) = p.R / p.G;
                case 'FC', p.Rg_list(idx_a) = p.R;
                otherwise
                    error('default_config: unknown arch name "%s".', p.arch_names{idx_a});
            end
        end
    end
end
