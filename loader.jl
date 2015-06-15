#-------------------------------------------------------------
#-- Include everything
#--------------------------------------------------------------

include("definitions.jl")

include("Offline/offlineAssignment.jl")
include("Offline/randomDescent.jl")
include("Offline/localOpt.jl")
include("Offline/intervalBinOpt.jl")
include("Offline/fullOpt.jl")
include("Offline/simpleOpt.jl")

include("Cities/squareCity.jl")
include("Cities/metropolis.jl")
include("Cities/manhattan.jl")
