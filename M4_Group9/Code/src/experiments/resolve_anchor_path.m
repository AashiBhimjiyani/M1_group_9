function [fpath, source_tag] = resolve_anchor_path(filename)
% RESOLVE_ANCHOR_PATH  Locate an R=32 M2 anchor file with M4 priority order.
%   Priority:
%     1. M4_Group9/Results/anchor_rayleigh_R32_50draws/<filename>
%     2. <repo_root>/Results/matched_rayleigh_R32_50draws/<filename> (read-only M2)
%   Throws a clear error naming all checked locations if neither exists.
    if nargin < 1 || isempty(filename)
        filename = 'per_draw.csv';
    end

    exp_dir   = fileparts(mfilename('fullpath'));     % .../Code/src/experiments
    src_dir   = fileparts(exp_dir);                   % .../Code/src
    code_dir  = fileparts(src_dir);                   % .../Code
    m4_root   = fileparts(code_dir);                  % .../M4_Group9
    repo_root = fileparts(m4_root);                   % workspace root

    cand_m4 = fullfile(m4_root,   'Results', 'anchor_rayleigh_R32_50draws', filename);
    cand_m2 = fullfile(repo_root, 'Results', 'matched_rayleigh_R32_50draws', filename);

    if exist(cand_m4, 'file') == 2
        fpath = cand_m4;
        source_tag = 'M4_anchor_copy';
        return;
    elseif exist(cand_m2, 'file') == 2
        fpath = cand_m2;
        source_tag = 'M2_read_only';
        return;
    else
        error('resolve_anchor_path:MissingAnchor', ...
            ['Required anchor file "%s" not found.\nChecked:\n' ...
             '  1. %s\n  2. %s'], filename, cand_m4, cand_m2);
    end
end

