function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nFind midpoint'}
end

function sysCall_init()
    if sim.getSimulationState()~=sim.simulation_stopped then
        return {cmd='cleanup'}
    end
    sim.addLog(sim.verbosity_scriptinfos,"This tool finds midpoint between first clicked vertex/dummy and second clicked vertex/dummy.")
    sim.broadcastMsg{id='pointSampler.enable',data={key='findMidpoint',vertex=true,dummy=true,snapToClosest=true}}
end

function sysCall_cleanup()
    sim.broadcastMsg{id='pointSampler.disable',data={key='findMidpoint'}}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key~='findMidpoint' then return end
    if event.id=='pointSampler.click' then
        if event.data.dummy then
            point=sim.getObjectPosition(event.data.dummy,sim.handle_world)
        else
            point=event.data.vertexCoords
        end
        if not firstPoint then
            firstPoint=Vector(point)
        else
            secondPoint=Vector(point)
            midPoint=(firstPoint+secondPoint)/2
            dummy=sim.createDummy(0.01)
            sim.setObjectPosition(dummy,sim.handle_world,midPoint:data())
            return {cmd='cleanup'}
        end
    end
end

function sysCall_beforeSimulation()
    return {cmd='cleanup'}
end

function sysCall_beforeInstanceSwitch()
    return {cmd='cleanup'}
end
