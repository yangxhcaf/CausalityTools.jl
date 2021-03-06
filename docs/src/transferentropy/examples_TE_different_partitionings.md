# Effect of dicretization scheme on transfer entropy estimates

## Different ways of partitioning

The `TransferOperatorGrid` and `VisitationFrequency` transfer entropy estimators
both operate on partitions on the delay reconstructions. Below, we demonstrate
the four different ways of discretizing the state space.

```@setup TE_partitioning_schemes
using CausalityTools, Plots, Statistics, TimeseriesSurrogates
```

First, let's load necessary packages and create some example time series.

```@example TE_partitioning_schemes
using CausalityTools, Plots, Statistics

x = rand(300)
y = sin.(cumsum(rand(300)))*0.3 .+ 0.05*x*rand([-1.0, 1.0])
```

Now, create a [generalised delay reconstruction](@ref custom_delay_reconstruction).
For computing the transfer entropy from ``x`` to ``y``, we will create the generalised 
embedding vectors ``\{(y_{t+η}, y_{t}, y_{t-τ}, x_{t}) \}``. In the 
opposite direction, we will have embedding vectors of the form 
``\{(x_{t+η}, x_{t}, x_{t-τ}, y_{t})\}``.

```@example TE_partitioning_schemes
τ = 1 # embedding lag
η = 1 # forward prediction lag
E_xtoy = customembed(Dataset(x, y), Positions([2, 2, 2, 1]), Lags([η, 0, -τ, 0]))
E_ytox = customembed(Dataset(y, x), Positions([2, 2, 2, 1]), Lags([η, 0, -τ, 0]));
```

Now `E_xtoy` and `E_ytox` stores the lagged time series as a `DynamicalSystems.Dataset`,
so that we can index the lagged variables by columns.

Okay, so we know which variables are in which columns and what lags they have. 
But the transfer entropy estimators don't have this information yet, so we need
to provide it using a [`TEVars`](@ref) instance. This is necessary to organize the 
computation of marginal probabilities.

```@example TE_partitioning_schemes
# Organize marginals
Tf = [1]     # future of target variable is in first column
Tpp = [2, 3] # present and past of target variable are in second and third columns
Spp = [4]    # the present of the source is in the fourth column.
v = TEVars(Tf, Tpp, Spp)
```

### Hyper-rectangles by subdivision of axes (`ϵ::Int`)

First, we use an integer number of subdivisions along each axis of the delay
embedding when partitioning.

```@example TE_partitioning_schemes
ϵs = 1:2:50 # integer number of subdivisions along each axis of the embedding
te_estimates_xtoy = zeros(length(ϵs))
te_estimates_ytox = zeros(length(ϵs))
vars = TEVars([1], [2, 3], [4])
estimator = VisitationFrequency(b = 2) # logarithm to base 2 gives units of bits

for (i, ϵ) in enumerate(ϵs)
    te_estimates_xtoy[i] = transferentropy(E_xtoy, vars, RectangularBinning(ϵ), estimator)
    te_estimates_ytox[i] = transferentropy(E_ytox, vars, RectangularBinning(ϵ), estimator)
end

p = plot()
plot!(p, ϵs, te_estimates_xtoy, label = "TE(x -> y)", lc = :black)
plot!(p, ϵs, te_estimates_ytox, label = "TE(y -> x)", lc = :red)
xlabel!(p, "# subdivisions along each axis")
ylabel!(p, "Transfer entropy (bits)")
```

### Hyper-cubes of fixed size (`ϵ::Float`)

We do precisely the same, but use fixed-width hyper-cube bins. The values of the
logistic map take values on `[0, 1]`, so using bins width edge lengths `0.1`
should give a covering corresponding to using `10` subdivisions along
each axis of the delay embedding. We let `ϵ` take values on `[0.05, 0.5]`.

```@example TE_partitioning_schemes
ϵs = 0.02:0.02:0.5
te_estimates_xtoy = zeros(length(ϵs))
te_estimates_ytox = zeros(length(ϵs))
vars = TEVars([1], [2, 3], [4])
estimator = VisitationFrequency(b = 2)

for (i, ϵ) in enumerate(ϵs)
    te_estimates_xtoy[i] = transferentropy(E_xtoy, vars, RectangularBinning(ϵ), estimator)
    te_estimates_ytox[i] = transferentropy(E_ytox, vars, RectangularBinning(ϵ), estimator)
end

plot(ϵs, te_estimates_xtoy, label = "TE(x -> y)", lc = :black)
plot!(ϵs, te_estimates_ytox, label = "TE(y -> x)", lc = :red)
xlabel!("Hypercube edge length")
ylabel!("Transfer entropy (bits)")
xflip!()
```

### Hyper-rectangles of fixed size (`ϵ::Vector{Float}`)

It is also possible to use hyper-rectangles, by specifying the edge lengths
along each coordinate axis of the delay embedding. In our case, we use a
four-dimensional, embedding, so we must provide a 4-element vector of edge
lengths

```@example TE_partitioning_schemes
# Define slightly different edge lengths along each axis
ϵs_x1 = LinRange(0.05, 0.5, 10)
ϵs_x2 = LinRange(0.02, 0.4, 10)
ϵs_x3 = LinRange(0.08, 0.6, 10)
ϵs_x4 = LinRange(0.10, 0.3, 10)

te_estimates_xtoy = zeros(length(ϵs_x1))
te_estimates_ytox = zeros(length(ϵs_x1))
vars = TEVars([1], [2, 3], [4])
estimator = VisitationFrequency(b = 2)

mean_ϵs = zeros(10)

for i ∈ 1:10
    ϵ = [ϵs_x1[i], ϵs_x2[i], ϵs_x3[i], ϵs_x4[i]]
    te_estimates_xtoy[i] = transferentropy(E_xtoy, vars, RectangularBinning(ϵ), estimator)
    te_estimates_ytox[i] = transferentropy(E_ytox, vars, RectangularBinning(ϵ), estimator)

    # Store average edge length (for plotting)
    mean_ϵs[i] = mean(ϵ)
end

plot(mean_ϵs, te_estimates_xtoy, label = "TE(x -> y)", lc = :black)
plot!(mean_ϵs, te_estimates_ytox, label = "TE(y -> x)", lc = :red)
xlabel!("Average hypercube edge length")
ylabel!("Transfer entropy (bits)")
xflip!()
```

### Hyper-rectangles by variable-width subdivision of axes (`ϵ::Vector{Int}`)

Another way to construct hyper-rectangles is to subdivide each
coordinate axis into segments of equal length. In our case, we use a
four-dimensional, embedding, so we must provide a 4-element vector providing
the number of subdivisions we want along each axis.

```@example TE_partitioning_schemes
# Define different number of subdivisions along each axis.
ϵs = 3:50
mean_ϵs = zeros(length(ϵs))
estimator = VisitationFrequency(b = 2)

te_estimates_xtoy = zeros(length(ϵs))
te_estimates_ytox = zeros(length(ϵs))
vars = TEVars([1], [2, 3], [4])

for (i, ϵᵢ) ∈ enumerate(ϵs)
    ϵ = [ϵᵢ - 1, ϵᵢ, ϵᵢ, ϵᵢ + 1]
    te_estimates_xtoy[i] = transferentropy(E_xtoy, vars, RectangularBinning(ϵ), estimator)
    te_estimates_ytox[i] = transferentropy(E_ytox, vars, RectangularBinning(ϵ), estimator)

    # Store average number of subdivisions for plotting
    mean_ϵs[i] = mean(ϵ)
end

plot(mean_ϵs, te_estimates_xtoy, label = "TE(x -> y)", lc = :black)
plot!(mean_ϵs, te_estimates_ytox, label = "TE(y -> x)", lc = :red)
xlabel!("Average number of subdivisions along the embedding axes")
ylabel!("Transfer entropy (bits)")
```
