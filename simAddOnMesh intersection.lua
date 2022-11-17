require'addon_booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Mesh tools\nIntersection'}
end

function op()
    return simIGL.boolean_op.intersection
end
