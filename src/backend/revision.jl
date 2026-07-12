##### Revision Types #####
Base.@kwdef mutable struct SystemRevision
    topology::Int64 = 0
    type::Int64 = 0
    slack::Int64 = 0
    acModel::Int64 = 0
    acPattern::Int64 = 0
    dcModel::Int64 = 0
    dcPattern::Int64 = 0
    acOptimization::Int64 = 0
    dcOptimization::Int64 = 0
end

Base.@kwdef mutable struct MeasurementRevision
    measurement::Int64 = 0
end

##### Revision Counters #####
function bump!(revision::SystemRevision, field::Symbol)
    setfield!(revision, field, getfield(revision, field) + 1)

    return nothing
end

function bump!(revision::MeasurementRevision, field::Symbol = :measurement)
    setfield!(revision, field, getfield(revision, field) + 1)

    return nothing
end

function topologyChanged!(system)
    bump!(system.model.revision, :topology)

    return nothing
end

function typeChanged!(system)
    bump!(system.model.revision, :type)

    return nothing
end

function slackChanged!(system)
    bump!(system.model.revision, :slack)

    return nothing
end

function acModelChanged!(system)
    bump!(system.model.revision, :acModel)

    return nothing
end

function acPatternChanged!(system)
    acModelChanged!(system)
    bump!(system.model.revision, :acPattern)

    return nothing
end

function dcModelChanged!(system)
    bump!(system.model.revision, :dcModel)

    return nothing
end

function dcPatternChanged!(system)
    dcModelChanged!(system)
    bump!(system.model.revision, :dcPattern)

    return nothing
end

function acOptimizationChanged!(system)
    bump!(system.model.revision, :acOptimization)

    return nothing
end

function dcOptimizationChanged!(system)
    bump!(system.model.revision, :dcOptimization)

    return nothing
end

function optimizationChanged!(system)
    acOptimizationChanged!(system)
    dcOptimizationChanged!(system)

    return nothing
end
