function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nFind midpoint'}
end

function sysCall_init()
    if sim.getSimulationState()~=sim.simulation_stopped then
        return {cmd='cleanup'}
    end
    sim.addLog(sim.verbosity_scriptinfos,"This tool finds midpoint between first clicked vertex/dummy and second clicked vertex/dummy. Hold shift to create two evenly spaced midpoints. Use sim.setNamedInt32Param('findMidpoint.n',3) to change the number of midpoints created when shift is held to e.g. 3.")
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
            n=simUI.getKeyboardModifiers().shift and math.max(1,sim.getNamedInt32Param('findMidpoint.n') or 2) or 1
            for i=1,n do
                midPoint=firstPoint+(secondPoint-firstPoint)*i/(n+1)
                dummy=sim.createDummy(0.01)
                sim.setObjectAlias(dummy,'Midpoint')
                sim.setObjectPosition(dummy,sim.handle_world,midPoint:data())
            end
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
