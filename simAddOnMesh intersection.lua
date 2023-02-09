require'addOns.booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh intersection'}
end

function op()
    return simIGL.boolean_op.intersection
end
