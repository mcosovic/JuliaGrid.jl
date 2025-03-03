module JuliaGrid

using JuMP

import LinearAlgebra: lu, lu!, ldlt, ldlt!, qr, ldiv, ldiv!, I, Factorization
import SparseArrays: SparseMatrixCSC, sparse, spzeros, spdiagm, dropzeros!, nzrange, nnz, UMFPACK, SPQR, CHOLMOD

import HDF5: File, Group, Dataset, h5open, h5read, readmmap, attrs, attributes
import OrderedCollections: OrderedDict
import Printf: Format, format, @printf
import Random: randperm, shuffle, shuffle!

######### Types and Constants ##########
include("definition/internal.jl")
include("definition/system.jl")
include("definition/analysis.jl")

######### Utility ##########
include("backend/utility.jl")
include("backend/internal.jl")
include("backend/equations.jl")
include("backend/expressions.jl")
export @base, @power, @voltage, @current, @parameter, @default, @labels

######### Print ##########
include("print/utility.jl")
include("print/powerSystem.jl")
include("print/constraint.jl")
include("print/measurement.jl")
export printBusData, printBranchData, printGeneratorData
export printBusSummary, printBranchSummary, printGeneratorSummary
export printBusConstraint, printBranchConstraint, printGeneratorConstraint
export printVoltmeterData, printAmmeterData, printWattmeterData, printVarmeterData, printPmuData

########## Power System ##########
include("powerSystem/load.jl")
include("powerSystem/save.jl")
include("powerSystem/model.jl")
export powerSystem, savePowerSystem
export acModel!, dcModel!, dropZeros!

########## Power System Components ##########
include("powerSystem/bus.jl")
include("powerSystem/branch.jl")
include("powerSystem/generator.jl")
export addBus!, updateBus!, @bus
export addBranch!, updateBranch!, @branch
export addGenerator!, updateGenerator!, cost!, @generator

########## Power Flow ##########
include("powerFlow/acPowerFlow.jl")
include("powerFlow/dcPowerFlow.jl")
export newtonRaphson, fastNewtonRaphsonBX, fastNewtonRaphsonXB, gaussSeidel
export mismatch!, solve!, acPowerFlow!
export reactiveLimit!, adjustAngle!, setInitialPoint!
export dcPowerFlow

######### Optimal Power Flow ##########
include("optimalPowerFlow/acOptimalPowerFlow.jl")
include("optimalPowerFlow/dcOptimalPowerFlow.jl")
export acOptimalPowerFlow
export dcOptimalPowerFlow

######### Measurement ##########
include("measurement/load.jl")
include("measurement/save.jl")
export measurement, saveMeasurement

########## Measurement Devices ##########
include("measurement/utility.jl")
include("measurement/voltmeter.jl")
include("measurement/ammeter.jl")
include("measurement/powermeter.jl")
include("measurement/pmu.jl")
include("measurement/configuration.jl")
export addVoltmeter!, updateVoltmeter!, statusVoltmeter!, @voltmeter
export addAmmeter!, updateAmmeter!, statusAmmeter!, @ammeter
export addWattmeter!, updateWattmeter!, statusWattmeter!, @wattmeter
export addVarmeter!, updateVarmeter!, statusVarmeter!, @varmeter
export addPmu!, updatePmu!, statusPmu!, @pmu
export status!

######### State Estimation ##########
include("stateEstimation/acStateEstimation.jl")
include("stateEstimation/pmuStateEstimation.jl")
include("stateEstimation/dcStateEstimation.jl")
include("stateEstimation/badData.jl")
include("stateEstimation/observability.jl")
export gaussNewton, acLavStateEstimation
export pmuStateEstimation, pmuLavStateEstimation
export dcStateEstimation, dcLavStateEstimation, residualTest!
export islandTopologicalFlow, islandTopological, restorationGram!, pmuPlacement, pmuPlacement!

########## Postprocessing ##########
include("postprocessing/acAnalysis.jl")
include("postprocessing/dcAnalysis.jl")
export power!, current!
export injectionPower, supplyPower, shuntPower, fromPower, toPower, chargingPower, seriesPower, generatorPower
export injectionCurrent, fromCurrent, toCurrent, seriesCurrent

########## Precompile ##########
include("backend/precompile.jl")

end