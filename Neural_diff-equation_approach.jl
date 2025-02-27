 #=implimentation of a hybrid node model based on christopher rackaucas implimentation at: 
https://github.com/ChrisRackauckas/universal_differential_equations/blob/master/LotkaVolterra/hudson_bay.jl =#


import Pkg
# Install packages 
#=
Pkg.add("ModelingToolkit")
Pkg.add("DifferentialEquations")
Pkg.add("Plots")
Pkg.add("OrdinaryDiffEq")
Pkg.add("DataDrivenDiffEq")
Pkg.add("LinearAlgebra")
Pkg.add("Optim")
Pkg.add("Statistics")
Pkg.add("CSV")
Pkg.add("JLD2")
Pkg.add("FileIO")
Pkg.add("Random")
Pkg.add("DataFrames")
Pkg.add("Lux")
Pkg.add("SciMLBase")
Pkg.add("Zygote")
Pkg.add("ComponentArrays")
Pkg.add("Optimization")
Pkg.add("OptimizationOptimJL")
Pkg.add("DelimitedFiles")
Pkg.add("ForwardDiff")
Pkg.add("OptimizationOptimisers")
Pkg.add("Optimisers")
Pkg.add("SciMLSensitivity")=#

using OrdinaryDiffEq
using SciMLSensitivity
using ModelingToolkit
using ForwardDiff
using Zygote
using Optim
using DelimitedFiles
using DataDrivenDiffEq
using LinearAlgebra, ComponentArrays
using Optimisers
using Optimization, OptimizationOptimJL, OptimizationOptimisers
using Lux
using Plots
gr()
using JLD2, FileIO
using Statistics
using Random

# Set a random seed for reproducible behavior
Random.seed!(5443)

svname = "Chemostat"

# Data Preprocessing
chemostat_data = readdlm("/home/aksel/Institute/data/ProcessedData.dat", '\t', Float64, '\n')
Xₙ = Matrix(transpose(chemostat_data[:, 2:3]))
t = chemostat_data[:, 1] .- chemostat_data[1, 1]
xscale = maximum(Xₙ, dims = 2)
Xₙ .= 1f0 ./ xscale .* Xₙ
tspan = (t[1], t[end])

#testing integration of p_
u0 = Xₙ[:, 1]
p_ = [1.3, 0.9, 0.8, 1.8]

# Plot the data
scatter(t, transpose(Xₙ), xlabel = "t", ylabel = "x(t), y(t)")
plot!(t, transpose(Xₙ), xlabel = "t", ylabel = "x(t), y(t)")

# Gaussian RBF as activation
rbf(x) = exp.(-(x.^2))

# Define the network 2->5->5->5->2
Network = Lux.Chain(
    Lux.Dense(2, 5, rbf),
    Lux.Dense(5, 5, rbf),
    Lux.Dense(5, 5, tanh),
    Lux.Dense(5, 2)
)
# Initialize the parameters for the model
rng = Random.default_rng()
p, st = Lux.setup(rng, Network)

#

# Manually initialized parameters for linear birth/decay rates
#linear_params = rand(Float64, 2)
#p = ComponentArray(linear_params=linear_params, ps=ps)

#Define the hybrid model
function ude_dynamics!(du,u, p, t, p_true)
    û = Network(u, p, st)[1] # Network prediction
    du[1] = p_true[1]*u[1] + û[1]
    du[2] = -p_true[4]*u[2] + û[2]
end

# Closure with the known parameter
nn_dynamics!(du,u,p,t) = ude_dynamics!(du,u,p,t,p_)
# Define the problem
prob_nn = ODEProblem(nn_dynamics!,Xₙ[:, 1], tspan, p)

# Define a predictor
function predict(θ, X = Xₙ[:, 1], T = t)
    _prob = remake(prob_nn, u0 = X, tspan = (T[1], T[end]), p = θ)
    Array(solve(_prob, Vern7(), saveat = T,
                abstol=1e-6, reltol=1e-6,
                sensealg = ForwardDiffSensitivity()
                ))
end

#Simple L2 loss
function loss(θ)
    X̂ = predict(θ)
    sum(abs2, Xₙ .- X̂)
end

#Container to track the losses
losses = Float64[]

#callback function
callback = function (p, l)
    push!(losses, l)
    if length(losses)%50==0
        println("Current loss after $(length(losses)) iterations: $(losses[end])")
    end
    return false
  end

##Training

# Define the optimization function and problem
adtype = Optimization.AutoZygote()
optf = Optimization.OptimizationFunction((x, p) -> loss(x), adtype)
optprob = Optimization.OptimizationProblem(optf, ComponentVector{Float64}(p))

# Use Optimization.jl to solve the problem with Adam optimizer
res1 = Optimization.solve(optprob, Optimisers.Adam(0.1); callback = callback, maxiters = 200)
println("Training loss after $(length(losses)) iterations: $(losses[end])")
# Train with BFGS
optprob2 = Optimization.OptimizationProblem(optf, res1.minimizer)
res2 = Optimization.solve(optprob2, Optim.BFGS(initial_stepnorm=0.01), callback=callback, maxiters = 10000)
println("Final training loss after $(length(losses)) iterations: $(losses[end])")

# Plot the losses
pl_losses = plot(1:200, losses[1:200], yaxis = :log10, xaxis = :log10, xlabel = "Iterations", ylabel = "Loss", label = "ADAM", color = :blue)
plot!(201:length(losses), losses[201:end], yaxis = :log10, xaxis = :log10, xlabel = "Iterations", ylabel = "Loss", label = "BFGS", color = :red)
savefig(pl_losses, joinpath(pwd(), "plots", "$(svname)_losses.pdf"))

# Name the best candidate and retrieve the best candidate
p_trained = res2.minimizer

#should be good through this>>>

## Analysis of the trained network
# Plot the data and the approximation
ts = first(solution.t):mean(diff(solution.t))/2:last(solution.t)
X̂ = predict(p_trained, Xₙ[:,1], ts)
# Trained on noisy data vs real solution
pl_trajectory = plot(ts, transpose(X̂), xlabel = "t", ylabel ="x(t), y(t)", color = :red, label = ["UDE Approximation" nothing])
scatter!(solution.t, transpose(Xₙ), color = :black, label = ["Measurements" nothing])
savefig(pl_trajectory, joinpath(pwd(), "plots", "$(svname)_trajectory_reconstruction.pdf"))

# Ideal unknown interactions of the predictor
Ȳ = [-p_[2]*(X̂[1,:].*X̂[2,:])';p_[3]*(X̂[1,:].*X̂[2,:])']
# Neural network guess
Ŷ = U(X̂,p_trained,st)[1]

pl_reconstruction = plot(ts, transpose(Ŷ), xlabel = "t", ylabel ="U(x,y)", color = :red, label = ["UDE Approximation" nothing])
plot!(ts, transpose(Ȳ), color = :black, label = ["True Interaction" nothing])
savefig(pl_reconstruction, joinpath(pwd(), "plots", "$(svname)_missingterm_reconstruction.pdf"))

# Plot the error
pl_reconstruction_error = plot(ts, norm.(eachcol(Ȳ-Ŷ)), yaxis = :log, xlabel = "t", ylabel = "L2-Error", label = nothing, color = :red)
pl_missing = plot(pl_reconstruction, pl_reconstruction_error, layout = (2,1))
savefig(pl_missing, joinpath(pwd(), "plots", "$(svname)_missingterm_reconstruction_and_error.pdf"))
pl_overall = plot(pl_trajectory, pl_missing)
savefig(pl_overall, joinpath(pwd(), "plots", "$(svname)_reconstruction.pdf"))

