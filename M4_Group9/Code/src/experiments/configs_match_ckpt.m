function [ok, reason] = configs_match_ckpt(p1, p2, opts1, opts2)
% CONFIGS_MATCH_CKPT  Verify all key experiment/config fields match a saved checkpoint.
    ok = true;
    reason = '';

    req_fields = { ...
        'R', 'G', 'Rg_list', 'arch_names', ...
        'num_draws', 'max_iter', 'nu', 'seed_base', ...
        'Pmax_dBm', 'N0_dBm', 'N', 'K', ...
        'fading', 'Kf_dB', 'C0_dB', 'd0', 'rho', 'd_BS_RIS', 'd_RIS_user', ...
        'eps_tol', 'run_joint'};

    for k = 1:numel(req_fields)
        fn = req_fields{k};
        has1 = isfield(p1, fn);
        has2 = isfield(p2, fn);
        if has1 ~= has2
            ok = false;
            reason = sprintf('field "%s" presence mismatch (%d vs %d)', fn, has1, has2);
            return;
        end
        if has1 && ~isequaln(p1.(fn), p2.(fn))
            ok = false;
            reason = sprintf('parameter "%s" changed', fn);
            return;
        end
    end

    if nargin >= 4
        if ~isequaln(opts1, opts2)
            ok = false;
            reason = 'optimizer options struct changed';
            return;
        end
    end
end

