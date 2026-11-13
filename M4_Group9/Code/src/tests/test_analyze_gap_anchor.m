function test_analyze_gap_anchor()
%TEST_ANALYZE_GAP_ANCHOR  Does analyze_gap reproduce the M3 report numbers?
%   Run from Code/src after setup_paths:   test_analyze_gap_anchor
% M3 values (anchor, 50 draws): GC 0.103, CI 0.057-0.159, general better 48/50;
% FC 0.021, CI 0.001-0.046, median 0. SC gap exactly 0.
% If a line says FAIL, find out why BEFORE using analyze_gap anywhere else.
% Do not adjust tolerances to make it pass.

here = fileparts(fileparts(mfilename('fullpath')));      % Code/src
root = fileparts(fileparts(here));                       % M4_Group9
dirA = fullfile(root, 'Results', 'anchor_rayleigh_R32_50draws');
addpath(fullfile(here, 'experiments'));
T = analyze_gap(dirA, 'quiet', true);

gc = T(T.arch == "GC", :);  fc = T(T.arch == "FC", :);  sc = T(T.arch == "SC", :);
chk = @(name, ok) fprintf('%-34s %s\n', name, ternary(ok, 'PASS', 'FAIL'));

chk('SC mean gap == 0 (1e-9)',        abs(sc.mean_gap) < 1e-9);
chk('GC mean gap ~ 0.103 (+-0.0015)', abs(gc.mean_gap - 0.103) < 0.0015);
chk('GC CI lo ~ 0.057 (+-0.006)',     abs(gc.ci_lo - 0.057) < 0.006);
chk('GC CI hi ~ 0.159 (+-0.006)',     abs(gc.ci_hi - 0.159) < 0.006);
chk('GC general better = 48',         gc.n_general_better == 48);
chk('GC recip better   = 2',          gc.n_recip_better == 2);
chk('FC mean gap ~ 0.021 (+-0.0015)', abs(fc.mean_gap - 0.021) < 0.0015);
chk('FC CI lo ~ 0.001 (+-0.006)',     abs(fc.ci_lo - 0.001) < 0.006);
chk('FC CI hi ~ 0.046 (+-0.006)',     abs(fc.ci_hi - 0.046) < 0.006);
chk('FC median ~ 0 (1e-6)',           abs(fc.median_gap) < 1e-6);
fprintf(['\nCI endpoints depend on the bootstrap seed/method used for M3, so a small\n' ...
         'CI mismatch (bootstrap noise ~0.003) is not an error in the data; a mean/win-count mismatch is.\n' ...
         'Report whatever you observe.\n']);
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
