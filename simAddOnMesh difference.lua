require 'addOns.booleanMesh'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMesh difference'}
end

function op()
    local simIGL = require 'simIGL'
    return simIGL.boolean_op.difference
end
