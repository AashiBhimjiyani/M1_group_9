% run_power_convention_check.m  --  Member 3: "per-user power" hypothesis, no tuning
%
% Question: is the reciprocal FC rate (about 10.3 bps/Hz) below the paper's ~14 bps/Hz because
% the paper's Pmax is per user rather than total? For K = 2, 20 dBm per user is 23 dBm total,
% so this runs the anchor point at Pmax = 23 dBm and changes nothing else.
% This is a test of one hypothesis, not a fit: the answer is reported whatever it is.
%
% Usage (from M4_Group9/Code/src, after setup_paths):
%   Quick check (3 draws, scratch folder):   num_draws = 3;  run('experiments/run_power_convention_check.m')
%   Report run (50 draws, Results/):         run('experiments/run_power_convention_check.m')

here = fileparts(mfilename('fullpath'));
setup_paths();

if ~exist('num_draws', 'var'), num_draws = 50; end
if num_draws < 50
    results_root = fullfile(tempdir, 'm4_quick_check', 'power_convention');
    fprintf('QUICK CHECK (%d draws): output goes to %s\n', num_draws, results_root);
else
    results_root = fullfile(here, '..', '..', 'Results', 'diagnostics', 'power_convention');
end

p = default_config(struct('Pmax_dBm', 23, 'num_draws', num_draws, 'run_joint', false));
fprintf('\n=== Power convention check: Pmax = %g dBm (total), %d draws ===\n', p.Pmax_dBm, num_draws);

res = run_matched_experiment(p);

save_matched_results(res, fullfile(results_root, 'P23dBm'));
plot_matched_results(res, fullfile(results_root, 'P23dBm'));

fprintf('Failed (draw, arch) runs = %d\n', numel(res.errors));
if ~isempty(res.errors), disp(res.errors'); end
