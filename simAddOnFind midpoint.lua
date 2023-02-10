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
            sim.broadcastMsg{id='pointSampler.setFlags',data={key='findMidpoint',segmentSource=point}}
        else
            secondPoint=Vector(point)
            d=secondPoint-firstPoint
            n=simUI.getKeyboardModifiers().shift and math.max(1,sim.getNamedInt32Param('findMidpoint.n') or 2) or 1
            for i=1,n do
                midPoint=firstPoint+d*i/(n+1)
                dummy=sim.createDummy(0.01)
                sim.setObjectAlias(dummy,'Midpoint')
                m=pointNormalToMatrix(midPoint,d:normalized())
                sim.setObjectMatrix(dummy,sim.handle_world,m)
            end
            sim.announceSceneContentChange()
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

function pointNormalToMatrix(pt,n)
    local m=sim.buildIdentityMatrix()
    m[4]=pt[1]
    m[8]=pt[2]
    m[12]=pt[3]
    if n[1]<0.99 then
        local z=Vector3(n)
        local x=Vector3({1,0,0})
        local y=z:cross(x):normalized()
        local x=y:cross(z)
        m[1]=x[1]  m[5]=x[2]  m[9]=x[3]
        m[2]=y[1]  m[6]=y[2]  m[10]=y[3]
        m[3]=z[1]  m[7]=z[2]  m[11]=z[3]
    else
        m[1]=0  m[5]=1  m[9]=0
        m[2]=0  m[6]=0  m[10]=1
        m[3]=1  m[7]=0  m[11]=0
    end
    return m
end
