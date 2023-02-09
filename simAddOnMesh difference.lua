require'addOns.booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh difference'}
end

function op()
    return simIGL.boolean_op.difference
end
