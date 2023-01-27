function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nTranslate to align vertex'}
end

function sysCall_init()
    if sim.getSimulationState()~=sim.simulation_stopped then
        return {cmd='cleanup'}
    end
    sim.addLog(sim.verbosity_scriptinfos,"This tool translates a shape to bring first clicked vertex to the position of second clicked vertex.")
    sim.broadcastMsg{id='pointSampler.enable',data={key='translateToAlignVertex',vertex=true}}
end

function sysCall_cleanup()
    sim.broadcastMsg{id='pointSampler.disable',data={key='translateToAlignVertex'}}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key~='translateToAlignVertex' then return end
    if event.id=='pointSampler.click' and event.data.shape then
        if firstShape then
            delta=Vector(event.data.shape.vertexCoords)-Vector(firstVertex)
            sim.setObjectPosition(firstShape,firstShape,delta:data())
            return {cmd='cleanup'}
        else
            firstShape=event.data.handle
            firstVertex=event.data.shape.vertexCoords
        end
    end
end

function sysCall_beforeSimulation()
    return {cmd='cleanup'}
end

function sysCall_beforeInstanceSwitch()
    return {cmd='cleanup'}
end
