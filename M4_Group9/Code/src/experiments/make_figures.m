function make_figures(results_root)
%MAKE_FIGURES  Build every report figure from the Results/ folders only.
%
%   cd Code/src; setup_paths; addpath experiments; make_figures   (uses ../../Results)
%
% Runs analyze_gap on each folder (also rewrites its gap_table.csv).
% Folders that do not exist yet are skipped with a message, so you can run this
% after every push. Saves PNG + PDF into Results/figures/.
%
% Folder names expected (these are what the team prompts create):
%   anchor_rayleigh_R32_50draws                     R=32, Rg=4, N=K=2, 20 dBm, Rayleigh
%   sweep_power/P00dBm P05dBm P10dBm P15dBm         (anchor = 20 dBm)
%   sweep_ris_size/R16 R48 R64                      (anchor = R 32, Rg 4)
%   sweep_group_size/Rg02 Rg08 Rg16                 (anchor = Rg 4), R = 32
%   sweep_antennas/NK3 NK4 NK6                      (anchor = N=K=2)
%   rician_anchor
% Nothing here is invented: every plotted number is a column of a gap_table.csv.

if nargin < 1
    here = fileparts(fileparts(mfilename('fullpath')));      % Code/src
    results_root = fullfile(fileparts(fileparts(here)), 'Results');
end
figdir = fullfile(results_root, 'figures');
if ~isfolder(figdir), mkdir(figdir); end
addpath(fileparts(mfilename('fullpath')));

anchor = fullfile(results_root, 'anchor_rayleigh_R32_50draws');
TA = load_table(anchor);
if isempty(TA), error('make_figures:anchor', 'Anchor folder/table missing: %s', anchor); end

% ---- 1-4: gap vs sweep variable ---------------------------------------
sweeps = {
  'gap_vs_power',  'sweep_power',      '^P(\d+)dBm$', 20, 'P_{max} (dBm)',            'Gap vs transmit power'
  'gap_vs_R',      'sweep_ris_size',   '^R(\d+)$',    32, 'RIS ports R (block size 4)', 'Gap vs RIS size'
  'gap_vs_blocksize','sweep_group_size','^Rg(\d+)$',   4, 'Block size R_g (R = 32)',    'Gap vs group size'
  'gap_vs_NK',     'sweep_antennas',   '^NK(\d+)$',    2, 'N = K',                      'Gap vs antennas/users'};

S = struct();   % keep for the rate-vs-power figure
for s = 1:size(sweeps, 1)
    [name, sub, pat, anchor_x, xl, ttl] = sweeps{s, :};
    [x, Ts] = collect(fullfile(results_root, sub), pat, anchor_x, TA);
    if numel(x) < 2
        fprintf('skip %-18s (only %d point found)\n', name, numel(x)); continue;
    end
    S.(name) = struct('x', x, 'T', {Ts});
    f = figure('Color', 'w', 'Position', [100 100 560 400]); hold on; grid on;
    plot_gap(x, Ts, 'GC', 'o-'); plot_gap(x, Ts, 'FC', 's-'); plot_gap(x, Ts, 'SC', 'k^:');
    yline(0, 'k-', 'LineWidth', 0.8);
    xlabel(xl); ylabel('Rate gap, general - reciprocal (bps/Hz)');
    title([ttl ' (mean, 95% bootstrap CI)']);
    legend({'GC', 'FC', 'SC (zero control)'}, 'Location', 'best');
    save_fig(f, figdir, name); close(f);
end

% ---- 5: sum-rate vs power --------------------------------------------
if isfield(S, 'gap_vs_power')
    x = S.gap_vs_power.x; Ts = S.gap_vs_power.T;
    f = figure('Color', 'w', 'Position', [100 100 560 400]); hold on; grid on;
    cols = struct('SC', [0.4 0.4 0.4], 'GC', [0 0.45 0.74], 'FC', [0.85 0.33 0.1]);
    for A = {'SC', 'GC', 'FC'}
        a = A{1};
        plot(x, getv(Ts, a, 'mean_general_rate'), '-o', 'Color', cols.(a));
        plot(x, getv(Ts, a, 'mean_recip_rate'),   '--s', 'Color', cols.(a));
    end
    xlabel('P_{max} (dBm)'); ylabel('Mean sum-rate (bps/Hz)');
    title('Sum-rate vs power: general (solid) and reciprocal (dashed)');
    legend({'SC general','SC recip','GC general','GC recip','FC general','FC recip'}, ...
           'Location', 'northwest');
    save_fig(f, figdir, 'rate_vs_power'); close(f);
end

% ---- 6: rate retained vs real degrees of freedom (R = 32) -------------
if isfield(S, 'gap_vs_blocksize')
    Rg = S.gap_vs_blocksize.x; Ts = S.gap_vs_blocksize.T; R = 32;
    dof_ratio = (Rg + 1) ./ (2 * Rg);              % G*Rg(Rg+1)/2 over G*Rg^2
    ret = arrayfun(@(i) retained(Ts{i}, 'GC'), 1:numel(Rg));
    f = figure('Color', 'w', 'Position', [100 100 560 400]); hold on; grid on;
    plot(dof_ratio, ret, 'o-', 'DisplayName', 'GC, Rg = 2..16 (labelled)');
    for i = 1:numel(Rg), text(dof_ratio(i), ret(i), sprintf('  R_g=%d', Rg(i))); end
    plot((R + 1) / (2 * R), retained(TA, 'FC'), 's', 'MarkerFaceColor', 'r', 'DisplayName', 'FC');
    plot(1, retained(TA, 'SC'), '^', 'MarkerFaceColor', 'k', 'DisplayName', 'SC');
    xlabel('Reciprocal / general real degrees of freedom'); ylabel('Rate retained (reciprocal / general)');
    title('Rate retained vs degrees of freedom retained (R = 32)');
    legend('Location', 'best'); save_fig(f, figdir, 'retained_vs_dof'); close(f);
else
    fprintf('skip retained_vs_dof (group-size sweep missing)\n');
end

% ---- 7: Rayleigh vs Rician -------------------------------------------
TR = load_table(fullfile(results_root, 'rician_anchor'));
if ~isempty(TR)
    f = figure('Color', 'w', 'Position', [100 100 560 400]); hold on; grid on;
    A3 = {'SC', 'GC', 'FC'};
    m = [getv({TA}, 'SC', 'mean_gap') getv({TR}, 'SC', 'mean_gap'); ...
         getv({TA}, 'GC', 'mean_gap') getv({TR}, 'GC', 'mean_gap'); ...
         getv({TA}, 'FC', 'mean_gap') getv({TR}, 'FC', 'mean_gap')];
    lo = [getv({TA}, 'SC', 'ci_lo') getv({TR}, 'SC', 'ci_lo'); ...
          getv({TA}, 'GC', 'ci_lo') getv({TR}, 'GC', 'ci_lo'); ...
          getv({TA}, 'FC', 'ci_lo') getv({TR}, 'FC', 'ci_lo')];
    hi = [getv({TA}, 'SC', 'ci_hi') getv({TR}, 'SC', 'ci_hi'); ...
          getv({TA}, 'GC', 'ci_hi') getv({TR}, 'GC', 'ci_hi'); ...
          getv({TA}, 'FC', 'ci_hi') getv({TR}, 'FC', 'ci_hi')];
    b = bar(m);
    set(gca, 'XTick', 1:3, 'XTickLabel', A3);
    for k = 1:2
        errorbar(b(k).XEndPoints, m(:, k), m(:, k) - lo(:, k), hi(:, k) - m(:, k), 'k.', 'LineWidth', 1);
    end
    legend(b, {'Rayleigh', 'Rician'}, 'Location', 'best');
    ylabel('Rate gap (bps/Hz)'); title('Rayleigh vs Rician gap (mean, 95% CI)');
    save_fig(f, figdir, 'rayleigh_vs_rician'); close(f);
else
    fprintf('skip rayleigh_vs_rician (rician_anchor missing)\n');
end

% ---- 8: per-draw FC and GC gap distribution (anchor) ------------------
[~, GA] = analyze_gap(anchor, 'write', false, 'quiet', true);
f = figure('Color', 'w', 'Position', [100 100 760 330]);
subplot(1, 2, 1); histogram(GA.GC, 20); grid on; xline(0, 'k-');
xlabel('GC per-draw gap (bps/Hz)'); ylabel('draws'); title('GC');
subplot(1, 2, 2); histogram(GA.FC, 20); grid on; xline(0, 'k-');
xlabel('FC per-draw gap (bps/Hz)'); ylabel('draws'); title('FC (heavy tail?)');
sgtitle('Distribution of per-draw gaps, anchor point');
save_fig(f, figdir, 'gap_distribution_anchor'); close(f);

fprintf('Figures written to %s\n', figdir);
end

% ------------------------------------------------------------------------
function T = load_table(dirp)
T = [];
if ~isfolder(dirp), return; end
if ~isfile(fullfile(dirp, 'per_draw.csv')), return; end
T = analyze_gap(dirp, 'quiet', true);      % always recompute: never plot a stale gap_table.csv
end

function [x, Ts] = collect(sweepdir, pat, anchor_x, TA)
x = anchor_x; Ts = {TA};
if isfolder(sweepdir)
    d = dir(sweepdir);
    for i = 1:numel(d)
        if ~d(i).isdir, continue; end
        tok = regexp(d(i).name, pat, 'tokens', 'once');
        if isempty(tok), continue; end
        T = load_table(fullfile(sweepdir, d(i).name));
        if isempty(T), fprintf('  %s: no per_draw.csv yet\n', d(i).name); continue; end
        x(end + 1) = str2double(tok{1}); Ts{end + 1} = T; %#ok<AGROW>
    end
end
[x, o] = sort(x); Ts = Ts(o);
end

function v = getv(Ts, arch, field)
v = nan(numel(Ts), 1);
for i = 1:numel(Ts)
    r = Ts{i}(string(Ts{i}.arch) == arch, :);
    if ~isempty(r), v(i) = r.(field)(1); end
end
end

function plot_gap(x, Ts, arch, style)
m = getv(Ts, arch, 'mean_gap'); lo = getv(Ts, arch, 'ci_lo'); hi = getv(Ts, arch, 'ci_hi');
errorbar(x(:), m, m - lo, hi - m, style, 'LineWidth', 1.2, 'CapSize', 5);
end

function r = retained(T, arch)
rr = T(string(T.arch) == arch, :);
r = rr.mean_recip_rate / rr.mean_general_rate;
end

function save_fig(f, figdir, name)
print(f, fullfile(figdir, [name '.png']), '-dpng', '-r200');
try
    exportgraphics(f, fullfile(figdir, [name '.pdf']), 'ContentType', 'vector');
catch
    print(f, fullfile(figdir, [name '.pdf']), '-dpdf');
end
end
