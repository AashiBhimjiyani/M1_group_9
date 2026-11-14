# Problem and System Model

We study a downlink MU-MISO system with N base-station transmit antennas, K single-antenna users, and an R-port lossless beyond-diagonal RIS. The direct BS–user link is blocked. The channel matrices use the convention H_TX ∈ C^(R×N) and H_RX ∈ C^(K×R).

The general lossless scattering matrix satisfies Θ_gᴴΘ_g=I. The reciprocal design additionally satisfies Θ_r=Θ_rᵀ. Architectures are single-connected (SC, diagonal), group-connected (GC, block diagonal, with G groups and block size Rg=R/G), and fully-connected (FC, one R×R block).

The sum-rate is R_sum=Σ_k log₂(1+SINR_k). The primary comparison freezes a common initial MMSE precoder V0 and uses matched channels and initial scattering matrices. The primary reciprocity gap is ΔR=R_general,fixedV−R_reciprocal,fixedV. Positive values mean the general design attains a higher rate. SC is the zero-gap control because a diagonal scattering matrix is symmetric. Joint V/Θ results are a separate benchmark and are not the primary reciprocity gap.
