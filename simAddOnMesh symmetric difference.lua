require 'addOns.booleanMesh'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMesh symmetric difference'}
end

function op()
    local simIGL = require 'simIGL'
    return simIGL.boolean_op.symmetric_difference
end
