require'addon_booleanMesh'

function sysCall_info()
    return {autoStart=false,menu='Mesh tools\nDifference'}
end

function op()
    return simIGL.boolean_op.difference
end
