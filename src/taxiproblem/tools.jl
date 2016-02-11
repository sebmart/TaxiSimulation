###################################################
## taxiproblem/tools.jl
## various tools (not exported)
###################################################

"""
    `minutesSeconds`, returns current minute and second
"""
function minutesSeconds(t::Float64)
    minutes = floor(Int,t/60)
	return minutes, floor(Int, t-60*minutes)
end
