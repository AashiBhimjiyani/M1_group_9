function [T, G] = analyze_gap(results_dir, varargin)
%ANALYZE_GAP  Paired reciprocity-gap statistics for one Results folder.
%
%   [T, G] = analyze_gap('../../Results/anchor_rayleigh_R32_50draws')
%
% Reads <results_dir>/per_draw.csv (long format: one row per draw and
% architecture, column 'arch' = SC / GC / FC) and writes gap_table.csv.
%
% Primary metric: the frozen-precoder matched comparison, gap = gen_fv - rec_fv
% (column gap_fv, bps/Hz; positive = reciprocity costs rate). The recomputed-
% precoder gap (gap_v2) is reported alongside.
%
% Columns written, one row per architecture:
%   arch, Rg, n_draws, mean_gap, se_gap, ci_lo, ci_hi (95% percentile bootstrap
%   of the paired mean, 4000 resamples, fixed seed), median_gap,
%   n_general_better, n_recip_better, n_tie (tolerance 1e-9),
%   mean_general_rate (gen_fv), mean_recip_rate (rec_fv),
%   pct_gap         = 100 * mean_gap / mean_general_rate   <-- definition used in M4
%   pct_gap_perdraw = mean of per-draw gap_fv_pct          <-- the M2 definition
%   mean_gap_v2, se_gap_v2,
%   mean_rec_iters, max_rec_iters, rec_cap_hits, gen_cap_hits (iters >= cap, default 8000),
%   mean_rec_time_s, mean_gen_time_s, mean_rec_sym_err, mean_rec_uni_err,
%   mean_gen_uni_err.
%
% Second output G: struct of per-draw gap_fv vectors, G.SC / G.GC / G.FC.
% Base MATLAB only (R2019b+ for readtable options). No toolboxes.

p = inputParser;
addParameter(p, 'n_boot', 4000);
addParameter(p, 'seed',   20261114);
addParameter(p, 'tie_tol', 1e-9);
addParameter(p, 'cap',    8000);
addParameter(p, 'write',  true);
addParameter(p, 'quiet',  false);
parse(p, varargin{:});
nb = p.Results.n_boot;  tol = p.Results.tie_tol;

csv = fullfile(results_dir, 'per_draw.csv');
if ~isfile(csv), error('analyze_gap:nofile', 'Not found: %s', csv); end
D = readtable(csv, 'VariableNamingRule', 'preserve');
need = {'arch','Rg','gen_fv','rec_fv','gap_fv','gap_v2','gap_fv_pct','rec_iters','gen_iters', ...
        'rec_time_s','gen_time_s','rec_sym_err','rec_uni_err','gen_uni_err'};
miss = setdiff(need, D.Properties.VariableNames);
if ~isempty(miss)
    error('analyze_gap:cols', 'Missing columns in %s: %s', csv, strjoin(miss, ', '));
end
arch = string(D.arch);

archs = ["SC", "GC", "FC"];
rows = cell(numel(archs), 1);
G = struct();
for a = 1:numel(archs)
    A = archs(a);
    S = D(arch == A, :);
    g = S.gap_fv;  n = numel(g);
    if n == 0, error('analyze_gap:arch', 'No rows for %s in %s', A, csv); end
    G.(A) = g;

    s0 = rng;  rng(p.Results.seed + a, 'twister');      % reproducible, state restored
    idx = randi(n, n, nb);
    bm  = sort(mean(g(idx), 1));
    rng(s0);

    r = struct();
    r.arch              = A;
    r.Rg                = S.Rg(1);
    r.n_draws           = n;
    r.mean_gap          = mean(g);
    r.se_gap            = std(g) / sqrt(n);
    r.ci_lo             = bm(max(1,  floor(0.025 * nb)));
    r.ci_hi             = bm(min(nb, ceil( 0.975 * nb)));
    r.median_gap        = median(g);
    r.n_general_better  = sum(g >  tol);
    r.n_recip_better    = sum(g < -tol);
    r.n_tie             = sum(abs(g) <= tol);
    r.mean_general_rate = mean(S.gen_fv);
    r.mean_recip_rate   = mean(S.rec_fv);
    r.pct_gap           = 100 * r.mean_gap / r.mean_general_rate;
    r.pct_gap_perdraw   = mean(S.gap_fv_pct);
    r.mean_gap_v2       = mean(S.gap_v2);
    r.se_gap_v2         = std(S.gap_v2) / sqrt(n);
    r.mean_rec_iters    = mean(S.rec_iters);
    r.max_rec_iters     = max(S.rec_iters);
    r.rec_cap_hits      = sum(S.rec_iters >= p.Results.cap);
    r.gen_cap_hits      = sum(S.gen_iters >= p.Results.cap);
    r.mean_rec_time_s   = mean(S.rec_time_s);
    r.mean_gen_time_s   = mean(S.gen_time_s);
    r.mean_rec_sym_err  = mean(S.rec_sym_err);
    r.mean_rec_uni_err  = mean(S.rec_uni_err);
    r.mean_gen_uni_err  = mean(S.gen_uni_err);
    rows{a} = struct2table(r);
end
T = vertcat(rows{:});
if p.Results.write, writetable(T, fullfile(results_dir, 'gap_table.csv')); end
if ~p.Results.quiet
    fprintf('\n%s\n', results_dir);
    disp(T(:, {'arch','n_draws','mean_gap','se_gap','ci_lo','ci_hi','median_gap', ...
               'n_general_better','n_recip_better','pct_gap','rec_cap_hits'}));
end
end
