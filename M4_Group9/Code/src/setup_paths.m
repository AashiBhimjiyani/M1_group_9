function setup_paths()
% SETUP_PATHS  Put every M4 code folder on the MATLAB path (based on Member 4 M2 framework).
%   Call once at the top of any driver script:  setup_paths();
%   Works from any current folder because it locates itself with mfilename.
    src_dir = fileparts(mfilename('fullpath'));     % .../M4_Group9/Code/src
    addpath(src_dir);
    addpath(fullfile(src_dir, 'configs'));          % default_config
    addpath(fullfile(src_dir, 'tests'));            % test_common_framework
    addpath(fullfile(src_dir, 'common'));           % Member 4 shared channel/metrics
    addpath(fullfile(src_dir, 'reciprocal'));       % Member 2 reciprocal optimizer
    addpath(fullfile(src_dir, 'nonreciprocal'));    % Member 3 nonreciprocal baseline
    addpath(fullfile(src_dir, 'experiments'));      % matched runner & M4 experiments
end
