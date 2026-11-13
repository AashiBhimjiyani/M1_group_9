% run_power_sweep.m  --  Member 3: power sweep at N = K = 2, R = 32, G = 8, Rayleigh
%
% The 20 dBm point is the anchor (Results/anchor_rayleigh_R32_50draws), not re-run here.
%
% Usage (from M4_Group9/Code/src, after setup_paths):
%   Quick check (3 draws, written to a scratch folder, never to Results/):
%       num_draws = 3;  run('experiments/run_power_sweep.m')
%   Report run (50 draws, written to Results/sweep_power/):
%       run('experiments/run_power_sweep.m')

here = fileparts(mfilename('fullpath'));
setup_paths();

if ~exist('num_draws', 'var'), num_draws = 50; end
if num_draws < 50
    results_root = fullfile(tempdir, 'm4_quick_check', 'sweep_power');   % keep quick checks out of Results/
    fprintf('QUICK CHECK (%d draws): output goes to %s\n', num_draws, results_root);
else
    results_root = fullfile(here, '..', '..', '..', 'Results', 'sweep_power');
end

P_list_dBm = [0 5 10 15];                 % 20 dBm is the anchor

for P = P_list_dBm
    p = default_config(struct('Pmax_dBm', P, 'num_draws', num_draws, 'run_joint', false));
    fprintf('\n=== Power sweep: Pmax = %g dBm, %d draws ===\n', P, num_draws);

    res = run_matched_experiment(p);

    outdir = fullfile(results_root, sprintf('P%02ddBm', P));
    save_matched_results(res, outdir);
    plot_matched_results(res, outdir);

    fprintf('Pmax = %g dBm done: failed (draw, arch) runs = %d\n', P, numel(res.errors));
    if ~isempty(res.errors), disp(res.errors'); end
end
