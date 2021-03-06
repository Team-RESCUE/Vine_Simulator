include("dynamics.jl")

function Φ!(Φ, q)
    x = q[end-2]
    y = q[end-1]
    Θ = q[end]
    d = vine.d
    dist, _, _ = distToPoly(vine.env.objects[1].polygon,[x+d*cos(Θ);y+d*sin(Θ)])
    Φ[1] = dist - vine.diam/2
end

function con!(c,z)
    # unpack decision variables
    q = [z[q_idx[t]] for t = 1:T]
    v = [z[v_idx[t]] for t = 1:T]
    r = [z[r_idx[t]] for t = 1:T-1]
    s = [z[s_idx[t]] for t = 1:T-1]

    stiffness = 1000*z[end-1]
    damping = z[end]

    M = vine.M
    MInv = vine.MInv

    shift = 0 # shift index used for convenience

    # for dual constraints
    cq = zeros(eltype(z), vine.nc)
    g = zeros(eltype(z), vine.nu)
    Φ = zeros(eltype(z), 1)

    for t = 1:T
        # pin constraint
        c!(cq, q[t])
        c[shift .+ (1:vine.nc)] = cq
        shift += vine.nc

        # growth constraint
        g!(g, [q[t];v[t]])
        c[shift .+ (1:vine.nu)] = g - U[:,t]
        shift += vine.nu

        # contact constraint
        Φ!(Φ, q[t])
        c[shift + 1] = Φ[1]
        shift += 1

        t==T && continue
        # velocity
        impulses = compute_impulses(vine, [q[t];v[t]], U[:,t], stiffness, damping, n_opt[t], M, MInv)
        c[shift .+ (1:vine.nq)] = M*(v[t+1]-v[t]) - impulses - r[t]
        shift += vine.nq

        # position
        c[shift .+ (1:vine.nq)] = q[t+1] - (q[t] + v[t+1]*vine.Δt) - s[t]
        shift += vine.nq
    end

    return c
end
