%% Rician anchor: N=K=2, R=32, G=8, Pmax=20 dBm
% K-factor defaults to 2 dB in default_config when fading='rician'.
here=fileparts(mfilename('fullpath')); src=fileparts(here);
m4root=fullfile(src,'..','..');
setup_paths();
if ~exist('num_draws','var'), num_draws=50; end
if num_draws<50
    outdir=fullfile(tempdir,'m4_quick_check','rician_anchor');
else
    outdir=fullfile(m4root,'Results','rician_anchor');
end
p=default_config(struct('N',2,'K',2,'R',32,'G',8, ...
    'Pmax_dBm',20,'fading','rician','num_draws',num_draws,'run_joint',false));
fprintf('Rician K-factor = %.2f dB\n',p.Kf_dB);
res=run_matched_experiment(p);
save_matched_results(res,outdir);
plot_matched_results(res,outdir);
fprintf('Failed (draw,architecture) entries: %d\n',numel(res.errors));
if ~isempty(res.errors), disp(res.errors'); end
