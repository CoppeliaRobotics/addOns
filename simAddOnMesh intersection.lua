require 'addOns.booleanMesh'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMesh intersection'}
end

function op()
    local simIGL = require 'simIGL'
    return simIGL.boolean_op.intersection
end

function acceptsMoreThan2()
    return true
end
