function sysCall_info()
    return {autoStart=true,menu='Misc\nPoint sampler service'}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    enabled=0
    flags={}
    flagsStack={}
end

function sysCall_nonSimulation()
    if enabled==0 then return end

    if sim.getBoolParam(sim.boolparam_rayvalid) then
        currentCameraPos=sim.getObjectPosition(sim.adjustView(0,-1,512),sim.handle_world)
        local orig=sim.getArrayParam(sim.arrayparam_rayorigin)
        local dir=sim.getArrayParam(sim.arrayparam_raydirection)
        local newClickCnt=sim.getInt32Param(sim.intparam_mouseclickcounterdown)
        local clicked=newClickCnt~=clickCnt and clickCnt~=nil
        clickCnt=newClickCnt
        local pt,n,o=rayCast(orig,dir)
        local ti,vi,tc,vc=nil,nil,nil,nil
        clearDrawingInfo()
        local event={key=flagsStack[1],ray={orig=orig,dir=dir}}
        if pt then
            event.handle=o
            event.point=pt
            event.normal=n
            event.pointNormalMatrix=pointNormalToMatrix(pt,n)
            displayPointInfo(pt,n,o)
            if sim.getObjectType(o)==sim.object_shape_type then
                ti,vi,tc,vc=getTriangleAndVertexInfo(pt,n,o)
            end
            if ti then
                event.shape={
                    triangleIndex=ti,
                    vertexIndex=vi,
                    triangleCoords=tc,
                    vertexCoords=vc,
                }
                displayTriangleInfo(o,ti,vi)
            end
        end
        if clicked or currentFlags().hover then
            sim.broadcastMsg{id='pointSampler.'..(clicked and 'click' or 'hover'),data=event}
        end
    end
end

function sysCall_msg(event)
    if event.id=='pointSampler.enable' then
        if not event.data.key then
            sim.addLog(sim.verbosity_errors,'missing required field data.key')
            return
        end
        if flags[event.data.key] then
            sim.addLog(sim.verbosity_warnings,'already enabled')
            return
        end
        flags[event.data.key]=event.data
        table.insert(flagsStack,1,event.data.key)
        enable()
    elseif event.id=='pointSampler.disable' then
        if not event.data.key then
            sim.addLog(sim.verbosity_errors,'missing required field data.key')
            return
        end
        flags[event.data.key]=nil
        table.remove(flagsStack,1)
        disable()
    end
end

function sysCall_beforeInstanceSwitch()
    if enabled==0 then return end
    removeDrawingObjects()
end

function sysCall_afterInstanceSwitch()
    if enabled==0 then return end
    createDrawingObjects()
end

function currentFlags()
    return flags[flagsStack[1]]
end

function createDrawingObjects()
    pts=sim.addDrawingObject(sim.drawing_spherepts|sim.drawing_itemsizes,0.01,0,-1,1,{0,1,0})
    lines=sim.addDrawingObject(sim.drawing_lines,2,0,-1,1,{0,1,0})
    triangles=sim.addDrawingObject(sim.drawing_linestrip,4,0,-1,4,{0,1,0})
    trianglesv=sim.addDrawingObject(sim.drawing_spherepts|sim.drawing_itemsizes,0.0025,0,-1,1,{0,1,0})
end

function removeDrawingObjects()
    sim.removeDrawingObject(pts)
    sim.removeDrawingObject(lines)
    sim.removeDrawingObject(triangles)
    sim.removeDrawingObject(trianglesv)
end

function enable()
    enabled=enabled+1
    if enabled==1 then
        createDrawingObjects()
        clickCnt=sim.getInt32Param(sim.intparam_mouseclickcounterdown)
    end
end

function disable()
    if enabled==0 then return end
    enabled=enabled-1
    if enabled==0 then
        removeDrawingObjects()
    end
end

function distanceToCamera(pt)
    return (Vector(pt)-Vector(currentCameraPos)):norm()
end

function rayCast(orig,dir)
    local sensor=sim.createProximitySensor(sim.proximitysensor_ray_subtype,16,1,{3,3,2,2,1,1,0,0},{0,2000,0.01,0.01,0.01,0.01,0,0,0,0,0,0,0.01,0,0})
    local m=pointNormalToMatrix(orig,dir)
    sim.setObjectMatrix(sensor,sim.handle_world,m)
    local coll=allVisibleObjectsColl()
    local r,d,pt,o,n=sim.checkProximitySensor(sensor,coll)
    sim.destroyCollection(coll)
    sim.removeObjects({sensor})
    if r>0 then
        pt,n=pointNormalToGlobal(pt,n,m)
        return pt,n,o
    end
end

function clearDrawingInfo()
    sim.addDrawingObjectItem(pts,nil)
    sim.addDrawingObjectItem(lines,nil)
    sim.addDrawingObjectItem(triangles,nil)
    sim.addDrawingObjectItem(trianglesv,nil)
end

function displayPointInfo(pt,n,o)
    local d=distanceToCamera(pt)
    if currentFlags().surfacePoint then
        sim.addDrawingObjectItem(pts,{pt[1],pt[2],pt[3],0.005*d})
    end
    if currentFlags().surfaceNormal then
        local off=Vector(n)*0.1*d
        sim.addDrawingObjectItem(lines,{pt[1],pt[2],pt[3],pt[1]+off[1],pt[2]+off[2],pt[3]+off[3]})
    end
end

function poseHash(p)
    return table.join(map(function(x) return math.floor(x*1000000) end,p),'-')
end

function getTriangleAndVertexInfo(pt,n,o)
    pt=Matrix(1,3,pt)
    if not simIGL then return end
    if not meshInfo then meshInfo={} end
    local hash=poseHash(sim.getObjectPose(o,sim.handle_world))
    if not meshInfo[o] or meshInfo[o].hash~=hash then
        meshInfo[o]={}
        meshInfo[o].hash=hash
        meshInfo[o].mesh=simIGL.getMesh(o)
        meshInfo[o].f=Matrix(-1,3,meshInfo[o].mesh.indices)
        meshInfo[o].v=Matrix(-1,3,meshInfo[o].mesh.vertices)
        meshInfo[o].e,meshInfo[o].ue,meshInfo[o].emap,meshInfo[o].uec,meshInfo[o].uee=simIGL.uniqueEdgeMap(meshInfo[o].f:totable{})
    end
    local r,s=nil,nil
    local succ,errMsg=pcall(function()
        r,s=simIGL.closestFacet(meshInfo[o].mesh,pt:totable{},meshInfo[o].emap,meshInfo[o].uec,meshInfo[o].uee)
    end)
    if not succ then
        sim.addLog(sim.verbosity_errors,'IGL: '..errMsg)
        return
    end
    local triangleIndex,vertexIndex=r[1],nil
    local tri=meshInfo[o].f[1+triangleIndex]
    local v={
        meshInfo[o].v[1+tri[1]],
        meshInfo[o].v[1+tri[2]],
        meshInfo[o].v[1+tri[3]],
    }
    local dist={
        (v[1]-pt):t():norm(),
        (v[2]-pt):t():norm(),
        (v[3]-pt):t():norm(),
    }
    if currentFlags().triangle and currentFlags().vertex then
        table.insert(dist,((v[1]+v[2]+v[3])/3-pt):t():norm())
    end
    local closest,d=nil,nil
    for i=1,#dist do
        if not d or dist[i]<d then
            closest,d=i,dist[i]
        end
    end
    local triangleCoords=Matrix:vertcat(unpack(v)):data()
    local vertexCoords=nil
    if closest~=4 then
        vertexIndex=tri[closest]
        vertexCoords=meshInfo[o].v[1+vertexIndex]:data()
    end
    return triangleIndex,vertexIndex,triangleCoords,vertexCoords
end

function displayTriangleInfo(o,triangleIndex,vertexIndex)
    if vertexIndex and currentFlags().vertex then
        local vertexPos=meshInfo[o].v[1+vertexIndex]:data()
        local k=currentFlags().surfacePoint and 0.5 or 1
        table.insert(vertexPos,k*0.005*distanceToCamera(vertexPos))
        sim.addDrawingObjectItem(trianglesv,vertexPos)
    end
    if triangleIndex and currentFlags().triangle then
        local tri=meshInfo[o].f[1+triangleIndex]
        for _,i in ipairs{1,2,3,1} do
            sim.addDrawingObjectItem(triangles,meshInfo[o].v[1+tri[i]]:data())
        end
    end
end

function allVisibleObjectsColl()
    local coll=sim.createCollection(1)
    for i,obj in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        local t=sim.getObjectType(obj)
        if t==sim.object_shape_type or t==sim.object_octree_type then
            if sim.getObjectInt32Param(obj,sim.objintparam_visible)~=0 then
                sim.addItemToCollection(coll,sim.handle_single,obj,0)
            end
        end
    end
    return coll
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

function pointNormalToGlobal(pt,n,m)
    pt=sim.multiplyVector(m,pt)
    n=sim.multiplyVector({m[1],m[2],m[3],0,m[5],m[6],m[7],0,m[9],m[10],m[11],0},n)
    return pt,n
end
