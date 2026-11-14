function [H_TX, H_RX] = generate_channels(p)
    % H_TX is R x N
    % H_RX is K x R
    
    % Rayleigh fading component
    H_TX_nlos = (randn(p.R, p.N) + 1i*randn(p.R, p.N))/sqrt(2);
    H_RX_nlos = (randn(p.K, p.R) + 1i*randn(p.K, p.R))/sqrt(2);
    
    % LoS component (random phase for simplicity)
    H_TX_los = exp(1i*2*pi*rand(p.R, p.N));
    H_RX_los = exp(1i*2*pi*rand(p.K, p.R));
    
    % Compute linear Rician K-factor from Kf_dB if present
    if isfield(p, 'Kf_dB')
        if p.Kf_dB == -Inf
            Kf = 0;
        else
            Kf = 10^(p.Kf_dB / 10);
        end
    elseif isfield(p, 'Kf')
        Kf = p.Kf;
    else
        Kf = 0;
    end

    if Kf == 0
        H_TX_small = H_TX_nlos;
        H_RX_small = H_RX_nlos;
    else
        H_TX_small = sqrt(Kf/(Kf+1))*H_TX_los + sqrt(1/(Kf+1))*H_TX_nlos;
        H_RX_small = sqrt(Kf/(Kf+1))*H_RX_los + sqrt(1/(Kf+1))*H_RX_nlos;
    end
    
    H_TX = sqrt(p.PL_BS_RIS) * H_TX_small;
    H_RX = sqrt(p.PL_RIS_user) * H_RX_small;
end
