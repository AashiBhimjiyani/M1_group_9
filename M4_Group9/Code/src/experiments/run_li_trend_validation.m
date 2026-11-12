% run_li_trend_validation.m  --  Member 3: Li, Shen & Clerckx Fig. 9/10 qualitative check
%
% Runs nonreciprocal/validate_li_trends.m with nd = 20 channel draws, in the output folder.
% That script writes to ./results relative to the current folder, so this driver changes into
% the output folder first. Outputs end up in Results/diagnostics/li_trends/results/.
%
% What it checks (and nothing more): rate increases with Pmax, and FC >= GC >= SC, for
% reflective-mode Rayleigh with N = K = 4, R = 32, G = 8. Absolute numbers are NOT comparable
% to the paper, which plots hybrid mode.
%
% Usage (from M4_Group9/Code/src, after setup_paths):
%   run('experiments/run_li_trend_validation.m')

here = fileparts(mfilename('fullpath'));
setup_paths();

nd = 20;                                  % channel draws per power point (validate_li_trends reads nd)
outdir = fullfile(here, '..', '..', '..', 'Results', 'diagnostics', 'li_trends');
if ~exist(outdir, 'dir'), mkdir(outdir); end

old_dir = pwd;
cd(outdir);
cleanup = onCleanup(@() cd(old_dir));     % always return to the original folder
run(fullfile(here, '..', 'nonreciprocal', 'validate_li_trends.m'));
