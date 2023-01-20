function sysCall_init()
    if sim.isPluginLoaded('IGL') then
        local sel=sim.getObjectSelection()
        if #sel~=1 or sim.getObjectType(sel[1])~=sim.object_shape_type then
            sim.addLog(sim.verbosity_scripterrors,'This tool requires exactly one shape to be selected.')
        else
            local m=simIGL.upsample(simIGL.getMesh(sel[1]))
            local h=sim.createMeshShape(3,math.pi/8,m.vertices,m.indices)
        end
    else
        sim.addLog(sim.verbosity_scripterrors,'This tool requires the IGL plugin.')
    end
    return {cmd='cleanup'}
end

function sysCall_info()
    return {autoStart=false,menu='Mesh tools\nSubdivide'}
end
