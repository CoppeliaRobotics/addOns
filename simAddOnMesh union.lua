require'addon_booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Mesh tools\nUnion'}
end

function op()
    return simIGL.boolean_op.union
end
