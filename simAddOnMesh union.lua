require 'addOns.booleanMesh'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMesh union'}
end

function op()
    local simIGL = require 'simIGL'
    return simIGL.boolean_op.union
end

function acceptsMoreThan2()
    return true
end
