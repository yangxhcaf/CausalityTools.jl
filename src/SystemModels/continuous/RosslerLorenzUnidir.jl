"""
    RosslerLorenzUnidir{T, 6} <: ContinuousSystemModel{T, N}

Create a 6D Rössler-Lorenz model consisting of two independent 3D subsystems:
one Rössler system and one Lorenz system (from [^1]). They are coupled such that the
second component (`x₂`) of the Rössler system unidirectionally forces the
second component (`y₂`) of the Lorenz system. 

The parameter `c_xy` controls the coupling strength. The implementation here also 
allows for tuning the parameters of each subsystem by introducing the constants 
`a₁`, `a₂`, `a₃`, `b₁`, `b₂`, `b₃`. Default values for these parameters are 
as in [^1].

## Equations of motion 

The dynamics is generated by the following vector field

```math
\\begin{aligned}
\\dot x_1 &= a_1(x_2 + x_3) \\\\
\\dot x_2 &= a_2(x_1 + 0.2x_2) \\\\
\\dot x_3 &= a_2(0.2 + x_3(x_1 - a_3)) \\\\
\\dot y_1 &= b_1(y_2 - y_1) \\\\
\\dot y_2 &= y_1(b_2 - y_3) - y_2 +c_{xy}(x_2)^2 \\\\
\\dot y_3 &= y_1 y_2 - b_3y_3
\\end{aligned}
```

with the coupling constant ``c_{xy} \\geq 0``.

## Fields

- **`ui::SVector{6, T}`**: The initial condition.
- **`dt::T`**: The time step.
- **`c_xy::T`**: The coupling strength between the systems.
- **`a₁::T`**: The parameter `a₁` controlling the Rössler subsystem.
- **`a₂::T`**: The parameter `a₂` controlling the Rössler subsystem.
- **`a₃::T`**: The parameter `a₃` controlling the Rössler subsystem.
- **`b₁::T`**: The parameter `b₁` controlling the Lorenz subsystem.
- **`b₂::T`**: The parameter `b₂` controlling the Lorenz subsystem.
- **`b₃::T`**: The parameter `b₃` controlling the Lorenz subsystem.
- **`observational_noise_level`**: The magnitude of observational noise to add after sampling 
    orbits of the system (given as percentage of empirical standard deviation). If 
    `observational_noise_level = 30`, then noise equivalent to 0.3 times the empirical standard 
    deviation will be added to each variable of the system (taking the standard deviation for 
    that variable only).

## Implements 

- [`rand(::Type{RosslerLorenzUnidir})`](@ref). This method creates an instance of `RosslerLorenzUnidir`
    with randomised parameters.

    ## References

[^1]:
    Krakovská, Anna, et al. "Comparison of six methods for the detection of causality in a 
    bivariate time series." Physical Review E 97.4 (2018):042207. 
    [https://journals.aps.org/pre/abstract/10.1103/PhysRevE.97.042207](https://journals.aps.org/pre/abstract/10.1103/PhysRevE.97.042207)
    
"""
struct RosslerLorenzUnidir{T, N} <: ContinuousSystemModel{T, N}
    ui::SVector{N, T}
    dt::T
    c_xy::T
    a₁::T
    a₂::T
    a₃::T
    b₁::T
    b₂::T
    b₃::T
    observational_noise_level::T # how much observational noise to add?
end

function RosslerLorenzUnidir(; ui::AbstractVector{T} = rand(6), c_xy = 1.0, 
        a₁ = 6, a₂ = 0.2, a₃ = 5.7, b₁ = 10, b₂ = 28, b₃ = 8/3, 
        observational_noise_level = 0.5,
        dt = 0.05) where T <: AbstractFloat
    
    if length(ui) != 6
        error("Number of elements in initial condition must match 6")
    end
    ps = T.([dt, c_xy, a₁, a₂, a₃, b₁, b₂, b₃, observational_noise_level])
    RosslerLorenzUnidir(SVector{6, T}(ui), ps...)
end

@inline @inbounds function eom_RosslerLorenzUnidir(u, p::RosslerLorenzUnidir, t)
    
    x1, x2, x3, y1, y2, y3 = u[1], u[2], u[3], u[4], u[5], u[6] 
    
    dx1 = -p.a₁*(x2 + x3)
    dx2 = p.a₁*(x1 + p.a₂*x2)
    dx3 = p.a₁*(p.a₂ + x3*(x1 - p.a₃))
    dy1 = p.b₁*(-y1 + y2)
    dy2 = p.b₂*y1 - y2 - y1*y3 + p.c_xy*(x2^2)
    dy3 = y1*y2 - p.b₃*y3
    
    return SVector{6}(dx1, dx2, dx3, dy1, dy2, dy3)
end


function ContinuousDynamicalSystem(x::RosslerLorenzUnidir{T, N}) where {T, N}
    ContinuousDynamicalSystem(eom_RosslerLorenzUnidir, x.ui, x)
end

function trajectory(x::RosslerLorenzUnidir, npts::Int; sample_dt::Int = 1, Ttr = 1000, 
        alg = SimpleDiffEq.SimpleATsit5())
    
    sys = ContinuousDynamicalSystem(x)
    T = npts*x.dt*sample_dt
    
    o = trajectory(sys, T, dt = x.dt, Ttr = Ttr*x.dt, alg = alg)[1:sample_dt:end-1, :]
    
    percent_noise = x.observational_noise_level
    if x.observational_noise_level > 0
        o = add_observational_noise!(o, percent_noise)
    end

    return o
end


"""
    rand(::Type{RosslerLorenzUnidir};
        dt::PT = 0.05,
        ui::Union{PT, AbstractVector{PT} = rand(6),
        a₁::PT = UncertainValue([Uniform(5.7, 5.95), Uniform(5.7, 5.95)], [70, 30])
        a₂::PT = Uniform(0.18, 0.22),
        a₃::PT = Uniform(5.5, 5.9),
        b₁::PT = Uniform(9.5, 10.5), 
        b₂::PT = Uniform(27, 29),
        b₃::PT = Uniform(7.5/3, 8.5/3),
        observational_noise_level::PT = 20,
        n_maxtries::Int = 500) where {PT <: Union{Number, Distribution, AbstractUncertainValue}}

Generate `RosslerLorenzUnidir` model with randomised parameters, time step, initial condition and 
observational noise level. 

!!! note
    
    Any of the parameters be scalar values, uncertain values specified 
    by either distributions, or more complex uncertain values defined as in the 
    [UncertainData](https://github.com/kahaaga/UncertainData.jl) package.

## Keyword arguments 

Let `const PT = Union{Number, Distribution, AbstractUncertainValue}`. Then 

- **`dt::PT = 0.05`**: The time step.
- **`ui::Union{PT, AbstractVector{PT} = rand(6))`**: The initial condition.
- **`a₁::PT = UncertainValue([Uniform(5.7, 5.95), Uniform(5.7, 5.95)], [70, 30])`**: The parameter `a₁`.
- **`a₂::PT = Uniform(0.18, 0.22)`**: The parameter `a₂`.
- **`a₃::PT = Uniform(5.5, 5.9)`**: The parameter `a₃`.
- **`b₁::PT = Uniform(9.5, 10.5)`**: The parameter `b₁`.
- **`b₂::PT = Uniform(27, 29)`**: The parameter `b₂`.
- **`b₃::PT = Uniform(7.5/3, 8.5/3)`**: The parameter `b₃`.
- **`observational_noise_level`** = 20: The magnitude of observational noise to add after sampling 
    orbits of the system (given as percentage of empirical standard deviation). If 
    `observational_noise_level = 30`, then noise equivalent to 0.3 times the empirical standard 
    deviation will be added to each variable of the system (taking the standard deviation for 
    that variable only).
- **`n_maxtries`**: The number of draws to try until the quest of finding a system yielding 
    a good orbit comes to an end.


## Examples 

We'll use some handy constructs from the `UncertainData` package to 
sample the parameter space and create [`RosslerLorenzUnidir`](@ref) models
with randomised parameters. This model is defined by 

- its time step `dt` (which we'll keep fixed), 
- its initial condition `ui` (we'll sample it randomly according to the default, 
    which is to draw each marginal point from a uniform distribution on `[0, 1]`)
- its parameters `c_xy`, `a₁`, `a₂`, `a₃`, `b₁`, `b₂`, `b₃`, We'll 
    randomise the four first parameters, keeping the remaining parameters fixed.

```julia
using CausalityTools, UncertainData, Distributions

# Sample `a₁` from the intervals [5.7, 5.95] ∪ [6.05, 6.3], with a 70 % 
# sampling probability first subinterval and a 30 % sampling probability
# of sampling from the second interval. We'll make sampling probabilities 
# within each interval uniform. This information is 
# represented by a population of uncertain values, which is provided to 
# the `UncertainValue` constructor as a vector of uncertain values along 
# with their probability weights.
a₁ = UncertainValue([Uniform(5.7, 5.95), Uniform(5.7, 5.95)], [70, 30])

# Sample `a₂` and `a₃` uniformly from [0.18, 0.22] and [5.5, 5.9]
a₂ = Uniform(0.18, 0.22)
a₃ = Uniform(5.5, 5.9)

# Let the coupling strength be drawn from a normal distribution `N(μ, σ)`
# with `μ = 1.0`, `σ = 0.5`. Truncate at 0 and 2, to ensure valid coupling 
# strengts are drawn.

# Create 100 different models with parameters randomised as above.
n = 100
models = Vector{RosslerLorenzUnidir}(undef, n)

for i = 1:n
    models[n] = rand(RosslerLorenzUnidir, c_xy = 0.05, dt = 0.05, 
        a₁ = a₁, a₂ = a₂, a₃ = a₃,
        b₁ = 10, b₂ = 28, b₃ = 8.5/3)
end
```
"""
function rand(::Type{RosslerLorenzUnidir};
        c_xy = 0.5,
        a₁ = UncertainValue([Uniform(5.7, 5.95), Uniform(5.7, 5.95)], [70, 30]),
        a₂ = Uniform(0.18, 0.22),
        a₃ = Uniform(5.5, 5.9),
        b₁ = Uniform(9.5, 10.5), 
        b₂ = Uniform(27, 29),
        b₃ = Uniform(7.5/3, 8.5/3),
        ui = Uniform(0, 1),
        observational_noise_level = 20,
        dt = 0.05,
        n_maxtries::Int = 500)

    a₁ = UncertainValue(a₁)
    a₂ = UncertainValue(a₂)
    a₃ = UncertainValue(a₃)
    b₁ = UncertainValue(b₁)
    b₂ = UncertainValue(b₂)
    b₃ = UncertainValue(b₃)

    c_xy = UncertainValue(c_xy)
    dt = UncertainValue(dt)
    observational_noise_level = UncertainValue(observational_noise_level)

    n_tries = 0

    npts = 1000

    while n_tries <= n_maxtries
        # Randomly sample parameters. If not uncertain, simple use the parameters.
        sa₁ = rand(a₁)
        sa₂ = rand(a₂)
        sa₃ = rand(a₃)
        sb₁ = rand(b₁)
        sb₂ = rand(b₂)
        sb₃ = rand(b₃)
        sdt = rand(dt)
        sc_xy = rand(c_xy)
        sobservational_noise_level = rand(observational_noise_level)
        c_xy = rand(c_xy)
        sdt = rand(dt)

        if ui isa Vector{<:AbstractUncertainValue} 
            rui = rand.(ui)
        elseif ui isa Distribution
            rui = rand(ui, 6)
        elseif ui isa Number
            rui = repeat([ui], 6)
        elseif ui isa Vector && length(ui) == 6
            rui = ui
        else 
            error("Initial condition `ui` not specified correctly.")
        end
        
        # Without noise while finding good orbit.
        sys = RosslerLorenzUnidir(ui = rui, c_xy = sc_xy, 
            a₁ = sa₁, a₂ = sa₂, a₃ = sa₃, 
            b₁ = sb₁, b₂ = sb₂, b₃ = sb₃, dt = sdt, 
            observational_noise_level = 0.0)
        
        # Try to sample a trajectory
        pts = trajectory(sys, npts, sample_dt = 1, Ttr = 1000)
        
        M = Matrix(pts) 
        
        if all(isfinite.(M)) && all(M .< 1e10) && count(M .≈ 0) < npts*0.1 && count(abs.(M) .< 1e-10) < npts*0.1 && 
            (count(abs.(M) .< 1e-12) < npts*0.1) 
            return RosslerLorenzUnidir(ui = rui, 
                c_xy = sc_xy, 
                a₁ = sa₁, a₂ = sa₂, a₃ = sa₃, 
                b₁ = sb₁, b₂ = sb₂, b₃ = sb₃, dt = sdt, 
                observational_noise_level = sobservational_noise_level)
        end
        println("no attractor found. trying with new initial condition and parameters")
        n_tries += 1
    end
    println("could not find attractor!")
end