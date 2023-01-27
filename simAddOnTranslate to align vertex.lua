function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nTranslate to align vertex'}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    sim.addLog(sim.verbosity_scriptinfos,"This tool translates a shape to bring first clicked vertex to the position of second clicked vertex.")
    sim.broadcastMsg{id='pointSampler.enable',data={key='translateToAlignVertex',vertex=true}}
end

function sysCall_cleanup()
    sim.broadcastMsg{id='pointSampler.disable',data={key='translateToAlignVertex'}}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key~='translateToAlignVertex' then return end
    if event.id=='pointSampler.click' and event.data.shape then
        if firstShape then
            setSecondVertex(event.data.handle,event.data.shape.vertexCoords)
        else
            setFirstVertex(event.data.handle,event.data.shape.vertexCoords)
        end
    end
end

function sysCall_nonSimulation()
    if firstShape and firstVertex and secondVertex then
        delta=Vector(secondVertex)-Vector(firstVertex)
        sim.setObjectPosition(firstShape,firstShape,delta:data())
        return {cmd='cleanup'}
    end
end

function sysCall_beforeSimulation()
    return {cmd='cleanup'}
end

function sysCall_afterSimulation()
    return {cmd='cleanup'}
end

function sysCall_beforeInstanceSwitch()
    return {cmd='cleanup'}
end

function setFirstVertex(h,vc)
    firstShape=h
    firstVertex=vc
end

function setSecondVertex(h,vc)
    secondShape=h
    secondVertex=vc
end
