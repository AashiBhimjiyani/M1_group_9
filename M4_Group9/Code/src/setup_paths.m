function setup_paths()
% SETUP_PATHS  Put every M4 code folder on the MATLAB path (Member 4).
%   Call once at the top of any driver script:  setup_paths();
%   Works from any current folder because it locates itself with mfilename.
    here = fileparts(mfilename('fullpath'));          % .../M4_Group9/Code/src
    addpath(here);
    addpath(fullfile(here, 'configs'));               % default_config
    addpath(fullfile(here, 'common'));                % shared channel/metrics/runner
    addpath(fullfile(here, 'reciprocal'));            % Member 2
    addpath(fullfile(here, 'nonreciprocal'));         % Member 3
end
