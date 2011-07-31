libarpack = dlopen("libarpack")

macro jl_arpack_aupd_macro(T, saupd, naupd)
    quote

        # call dsaupd
        #  ( IDO, BMAT, N, WHICH, NEV, TOL, RESID, NCV, V, LDV, IPARAM,
        #    IPNTR, WORKD, WORKL, LWORKL, INFO )
        function jl_arpack_saupd(ido, bmat, n, which, nev, 
                                 tol, resid, ncv, v::Array{$T}, ldv, 
                                 iparam, ipntr, workd, workl, lworkl)
            info = [int32(0)]
            ccall(dlsym(libarpack, $saupd),
                  Void,
                  (Ptr{Int32}, Ptr{Uint8}, Ptr{Int32}, Ptr{Uint8}, Ptr{Int32},
                   Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{$T}, Ptr{Int32}, 
                   Ptr{Int32}, Ptr{Int32}, Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{Int32}),
                  ido, bmat, n, which, nev, tol, resid, ncv, v, ldv, 
                  iparam, ipntr, workd, workl, lworkl, info)
            return info[1]
        end

        #  call dnaupd
        #     ( IDO, BMAT, N, WHICH, NEV, TOL, RESID, NCV, V, LDV, IPARAM,
        #       IPNTR, WORKD, WORKL, LWORKL, INFO )
        function jl_arpack_naupd(ido, bmat, n, which, nev, 
                                 tol, resid, ncv, v::Array{$T}, ldv, 
                                 iparam, ipntr, workd, workl, lworkl)
            info = [int32(0)]
            ccall(dlsym(libarpack, $saupd),
                  Void,
                  (Ptr{Int32}, Ptr{Uint8}, Ptr{Int32}, Ptr{Uint8}, Ptr{Int32},
                   Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{$T}, Ptr{Int32}, 
                   Ptr{Int32}, Ptr{Int32}, Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{Int32}),
                  ido, bmat, n, which, nev, tol, resid, ncv, v, ldv, 
                  iparam, ipntr, workd, workl, lworkl, info)
            return info[1]
        end

    end
end

@jl_arpack_aupd_macro Float32 "ssaupd_" "snaupd_"
@jl_arpack_aupd_macro Float64 "dsaupd_" "dnaupd_"

macro jl_arpack_eupd_macro(T, seupd, neupd)
    quote

        #  call dseupd  
        #     ( RVEC, HOWMNY, SELECT, D, Z, LDZ, SIGMA, BMAT, N, WHICH, NEV, TOL,
        #       RESID, NCV, V, LDV, IPARAM, IPNTR, WORKD, WORKL, LWORKL, INFO )
        function jl_arpack_seupd(rvec, all, select, d, v, ldv, sigma, bmat, n, which, nev,
                                 tol, resid, ncv, v::Array{$T}, ldv, iparam,
                                 ipntr, workd, workl, lworkl)
            info = [int32(0)]
            ccall(dlsym(libarpack, $seupd),
                  Void,
                  (Ptr{Bool}, Ptr{Uint8}, Ptr{Bool}, Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{$T},
                   Ptr{Uint8}, Ptr{Int32}, Ptr{Uint8}, Ptr{Int32},
                   Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{$T}, Ptr{Int32}, Ptr{Int32},
                   Ptr{Int32}, Ptr{$T}, Ptr{$T}, Ptr{Int32}, Ptr{Int32}, ),
                  rvec, all, select, d, v, ldv, sigma, 
                  bmat, n, which, nev, tol, resid, ncv, v, ldv, 
                  iparam, ipntr, workd, workl, lworkl, info)
            return info[1]
        end

        #  call dneupd  
        #     ( RVEC, HOWMNY, SELECT, DR, DI, Z, LDZ, SIGMAR, SIGMAI, WORKEV, BMAT, 
        #       N, WHICH, NEV, TOL, RESID, NCV, V, LDV, IPARAM, IPNTR, WORKD, WORKL, 
        #       LWORKL, INFO )
        function jl_arpack_neupd()
            info = [int32(0)]

            return info[1]
        end

    end
end

@jl_arpack_eupd_macro Float32 "sseupd_" "sneupd_"
@jl_arpack_eupd_macro Float64 "dseupd_" "dneupd_"


jlArray(T, n::Int) = Array(T, int64(n))
jlArray(T, m::Int, n::Int) = Array(T, int64(m), int64(n))

function eigs{T}(A::AbstractMatrix{T}, k::Int)
    (m, n) = size(A)

    if m != n; error("Input should be square"); end
    if !issymmetric(A); error("Input should be symmetric"); end

    n = int32(n)
    ldv = int32(n)
    nev = int32(k)
    ncv = int32(min(max(nev*2, 20), n))
    bmat = "I"
    which = "LM"
    zero_T = zeros(T, 1)
    lworkl = int32(ncv*(ncv+8))

    v = jlArray(T, n, ncv)
    workd = jlArray(T, 3*n)
    workl = jlArray(T, lworkl)
    d = jlArray(T, nev)
    resid = jlArray(T, n)
    select = jlArray(Bool, ncv)
    iparam = jlArray(Int32, 11)
    ipntr = jlArray(Int32, 11)

    tol = [zero_T]
    sigma = [zero_T]
    ido = [int32(0)]

    iparam[1] = int32(1)    # ishifts
    iparam[3] = int32(1000) # maxitr
    iparam[7] = int32(1)    # mode 1

    while (true)

        info = jl_arpack_saupd(ido, bmat, n, which, nev, tol, resid, 
                               ncv, v, ldv, 
                               iparam, ipntr, workd, workl, lworkl)

        if (info < 0); print(info); error("Error in ARPACK aupd"); end

        if (ido[1] == -1 || ido[1] == 1)
            workd[ipntr[2]:ipntr[2]+n-1] = A * workd[ipntr[1]:ipntr[1]+n-1]
        else
            break
        end

    end

    rvec = true
    all = "A"

    info = jl_arpack_seupd(rvec, all, select, d, v, ldv, sigma, 
                           bmat, n, which, nev, tol, resid, ncv, v, ldv, 
                           iparam, ipntr, workd, workl, lworkl)

    if (info != 0); error("Error in ARPACK eupd"); end

    return (diagm(d), v[1:n, 1:nev])

end

function svds{T}(A::AbstractMatrix{T}, k::Int)
    
    (m, n) = size(A)
    if m < n; error("Only the m>n case is implemented"); end
    
    n = int32(n)
    ldv = int32(n)
    nev = int32(k)
    ncv = int32(min(max(nev*2, 20), n))
    bmat = "I"
    which = "LM"
    zero_T = zeros(T, 1)
    lworkl = int32(ncv*(ncv+8))

    v = jlArray(T, n, ncv)
    workd = jlArray(T, 3*n)
    workl = jlArray(T, lworkl)
    d = jlArray(T, nev)
    resid = jlArray(T, n)
    select = jlArray(Bool, ncv)
    iparam = jlArray(Int32, 11)
    ipntr = jlArray(Int32, 11)

    tol = [zero_T]
    sigma = [zero_T]
    ido = [int32(0)]

    iparam[1] = int32(1)    # ishifts
    iparam[3] = int32(1000) # maxitr
    iparam[7] = int32(1)    # mode 1

    At = A.'

    while (true)

        info = jl_arpack_saupd(ido, bmat, n, which, nev, tol, resid, 
                               ncv, v, ldv, 
                               iparam, ipntr, workd, workl, lworkl)

        if (info < 0); print(info); error("Error in ARPACK aupd"); end

        if (ido[1] == -1 || ido[1] == 1)
            workd[ipntr[2]:(ipntr[2]+n-1)] = At*(A*workd[ipntr[1]:(ipntr[1]+n-1)])
        else
            break
        end
        
    end

    rvec = true
    all = "A"

    info = jl_arpack_seupd(rvec, all, select, d, v, ldv, sigma, 
                           bmat, n, which, nev, tol, resid, ncv, v, ldv, 
                           iparam, ipntr, workd, workl, lworkl)

    if (info != 0); error("Error in ARPACK eupd"); end

    v = v[1:n, 1:nev]
    u = A*v*diagm(1./d)

    return (u, diagm(d), v.')

end
