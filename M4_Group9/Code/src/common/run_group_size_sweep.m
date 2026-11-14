
%% Group-size sweep: R=32, block sizes Rg=2, 8, 16

this_file = mfilename('fullpath');

if isempty(this_file)
    error('Save this code as run_group_size_sweep.m before running it.');
end

experiments_dir = fileparts(this_file);
src_dir = fileparts(experiments_dir);
m4root = fileparts(fileparts(src_dir));

addpath(src_dir);
setup_paths();

% Number of channel draws
num_draws = 50;

% [G, Rg] configurations
spec = [
    16  2
    4  8
    2 16
    ];

results_root = fullfile(m4root,'Results','sweep_group_size');

if ~exist(results_root,'dir')
    mkdir(results_root);
end

for i = 1:size(spec,1)

    G = spec(i,1);
    Rg = spec(i,2);

    fprintf('\n====================================\n');
    fprintf('Group-size experiment %d of %d\n',i,size(spec,1));
    fprintf('R = 32 | G = %d | Rg = %d\n',G,Rg);
    fprintf('Draws = %d\n',num_draws);
    fprintf('====================================\n');

    p = default_config(struct( ...
        'N',2, ...
        'K',2, ...
        'R',32, ...
        'G',G, ...
        'Pmax_dBm',20, ...
        'fading','rayleigh', ...
        'num_draws',num_draws, ...
        'run_joint',false));

    outdir = fullfile(results_root,sprintf('Rg%02d',Rg));

    if ~exist(outdir,'dir')
        mkdir(outdir);
    end

    res = run_matched_experiment(p);

    save_matched_results(res,outdir);
    plot_matched_results(res,outdir);

    fprintf('\nCompleted Rg = %d\n',Rg);
    fprintf('Failed runs: %d\n',numel(res.errors));

    if ~isempty(res.errors)
        disp(res.errors');
    end

end

fprintf('\nALL GROUP-SIZE SWEEPS FINISHED.\n');
