require'addon_booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Mesh tools\nSymmetric difference'}
end

function op()
    return simIGL.boolean_op.symmetric_difference
end
