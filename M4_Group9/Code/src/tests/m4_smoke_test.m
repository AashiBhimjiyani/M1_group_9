function m4_smoke_test()
%M4_SMOKE_TEST  Fresh-clone check.  Run:  cd M4_Group9/Code/src; m4_smoke_test
% 1) code folders present   2) setup_paths   3) test_common_framework (no FAIL lines)
% 4) analyze_gap reproduces the M3 anchor numbers.
% Copy the printed output into a log file.
srcdir = fileparts(fileparts(mfilename('fullpath')));      % Code/src
cd(srcdir);

need = {'configs','common','reciprocal','nonreciprocal','tests','experiments'};
miss = need(~cellfun(@(d) isfolder(fullfile(srcdir, d)), need));
tag('code folders present', isempty(miss), strjoin(miss, ', '));

try, setup_paths; tag('setup_paths', true, '');
catch e, tag('setup_paths', false, e.message); end

try
    [out, nfail] = run_framework_test(srcdir);
    fprintf('%s', out);
    tag('test_common_framework (no FAIL lines)', nfail == 0, sprintf('%d FAIL lines', nfail));
catch e, tag('test_common_framework', false, e.message); end

try
    addpath(fullfile(srcdir, 'experiments'), fullfile(srcdir, 'tests'));
    test_analyze_gap_anchor;
catch e, tag('test_analyze_gap_anchor', false, e.message); end

fprintf('\nMATLAB %s | %s\nNext: a 3-draw run, e.g.  num_draws = 3; run(''experiments/run_power_sweep.m'')\n', version, datestr(now));
end

function [out, nfail] = run_framework_test(srcdir)
% isolated workspace: the test script overwrites variables such as 'here' and 'p'
out = evalc('run(fullfile(srcdir, ''tests'', ''test_common_framework.m''))');
nfail = numel(regexp(out, '(^|\n)FAIL', 'match'));
end

function tag(name, ok, msg)
if ok, t = 'PASS'; else, t = 'FAIL'; end
fprintf('[%s] %s %s\n', t, name, msg);
end
