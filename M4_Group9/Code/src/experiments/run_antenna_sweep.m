% run_antenna_sweep.m  --  Member 3: N = K sweep at R = 32, Pmax = 20 dBm, G = 8, Rayleigh
%
% The N = K = 2 point is the anchor (Results/anchor_rayleigh_R32_50draws).
% Note: GC block size Rg = 4 is smaller than N + K for N = K = 3 and N = K = 4.
% It is kept on purpose so every point uses the same architecture; see Results/sweep_antennas/README.md.
%
% Usage (from M4_Group9/Code/src, after setup_paths):
%   Quick check (3 draws, scratch folder):   num_draws = 3;  run('experiments/run_antenna_sweep.m')
%   Report run (50 draws, Results/):         run('experiments/run_antenna_sweep.m')

here = fileparts(mfilename('fullpath'));
setup_paths();

if ~exist('num_draws', 'var'), num_draws = 50; end
if num_draws < 50
    results_root = fullfile(tempdir, 'm4_quick_check', 'sweep_antennas');
    fprintf('QUICK CHECK (%d draws): output goes to %s\n', num_draws, results_root);
else
    results_root = fullfile(here, '..', '..', '..', 'Results', 'sweep_antennas');
end

NK_list = [3 4 6];                        % N = K = 2 is the anchor

for n = NK_list
    p = default_config(struct('N', n, 'K', n, 'num_draws', num_draws, 'run_joint', false));
    fprintf('\n=== N = K = %d, R = %d, Pmax = %g dBm, %d draws ===\n', n, p.R, p.Pmax_dBm, num_draws);
    if p.Rg_list(2) < n + n
        fprintf('NOTE: GC block size Rg = %d < N + K = %d (kept on purpose).\n', p.Rg_list(2), 2*n);
    end

    res = run_matched_experiment(p);

    outdir = fullfile(results_root, sprintf('NK%d', n));
    save_matched_results(res, outdir);
    plot_matched_results(res, outdir);

    fprintf('N = K = %d done: failed (draw, arch) runs = %d\n', n, numel(res.errors));
    if ~isempty(res.errors), disp(res.errors'); end
end
