function sysCall_info()
    return {autoStart=false}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    createDummies=false
    parent=-1
    sim.addLog(sim.verbosity_scriptinfos,"This tool allows to sample points in the scene, and optionally create dummies from them")
    showDlg()
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end

    if sim.getBoolParam(sim.boolparam_rayvalid) then
        currentCameraPos=sim.getObjectPosition(sim.adjustView(0,-1,512),sim.handle_world)
        local orig=sim.getArrayParam(sim.arrayparam_rayorigin)
        local dir=sim.getArrayParam(sim.arrayparam_raydirection)
        local newClickCnt=sim.getInt32Param(sim.intparam_mouseclickcounterdown)
        local clicked=newClickCnt~=clickCnt and clickCnt~=nil
        clickCnt=newClickCnt
        local pt,n,o=rayCast(orig,dir)
        clearDrawingInfo()
        if pt then
            local event={
                ray={
                    orig=orig,
                    dir=dir,
                },
                handle=o,
                point=pt,
                normal=n,
            }
            displayPointInfo(pt,n,o)
            if showTriangleInfo and sim.getObjectType(o)==sim.object_shape_type then
                local fi,vi=displayTriangleInfo(pt,n,o)
                event.shape={
                    face=fi,
                    vertex=vi,
                }
            end
            if clicked then
                sim.broadcastMsg{id='click',data=event}
                if createDummies then
                    createDummy(pt,n)
                end
            end
        else
            clearTextInfo()
        end
    end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_afterSimulation()
    showDlg()
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function sysCall_afterInstanceSwitch()
    showDlg()
end

function distanceToCamera(pt)
    return (Vector(pt)-Vector(currentCameraPos)):norm()
end

function rayCast(orig,dir)
    local coll=sim.createCollection(1)
    local objs=sim.getObjectsInTree(sim.handle_scene)
    for i=1,#objs,1 do
        local t=sim.getObjectType(objs[i])
        if t==sim.object_shape_type or t==sim.object_octree_type then
            if sim.getObjectInt32Param(objs[i],sim.objintparam_visible)~=0 then
                sim.addItemToCollection(coll,sim.handle_single,objs[i],0)
            end
        end
    end
    local m=sim.buildIdentityMatrix()
    m[4]=orig[1]
    m[8]=orig[2]
    m[12]=orig[3]
    local z=Vector3(dir)
    local up=Vector3({0,0,1})
    local x=up:cross(z):normalized()
    local y=z:cross(x)
    m[1]=x[1]  m[5]=x[2]  m[9]=x[3]
    m[2]=y[1]  m[6]=y[2]  m[10]=y[3]
    m[3]=z[1]  m[7]=z[2]  m[11]=z[3]
    local sensor=sim.createProximitySensor(sim.proximitysensor_ray_subtype,16,1,{3,3,2,2,1,1,0,0},{0,2000,0.01,0.01,0.01,0.01,0,0,0,0,0,0,0.01,0,0})
    sim.setObjectMatrix(sensor,sim.handle_world,m)
    local r,d,pt,o,n=sim.checkProximitySensor(sensor,coll)
    sim.removeObjects({sensor})
    sim.destroyCollection(coll)
    if r>0 then
        pt=sim.multiplyVector(m,pt)
        m[4]=0
        m[8]=0
        m[12]=0
        n=sim.multiplyVector(m,n)
        return pt,n,o
    end
end

function clearDrawingInfo()
    sim.addDrawingObjectItem(pts,nil)
    sim.addDrawingObjectItem(lines,nil)
    sim.addDrawingObjectItem(triangles,nil)
    sim.addDrawingObjectItem(trianglesv,nil)
end

function clearTextInfo()
    simUI.setLabelText(ui,11,'N/A')
    simUI.setLabelText(ui,13,'N/A')
    simUI.setLabelText(ui,15,'N/A')
    simUI.setLabelText(ui,31,'N/A')
    simUI.setLabelText(ui,33,'N/A')
end

function displayPointInfo(pt,n,o)
    local d=distanceToCamera(pt)
    sim.addDrawingObjectItem(pts,{pt[1],pt[2],pt[3],0.005*d})
    sim.addDrawingObjectItem(lines,{pt[1],pt[2],pt[3],pt[1]+n[1]*0.1*d,pt[2]+n[2]*0.1*d,pt[3]+n[3]*0.1*d})
    simUI.setLabelText(ui,11,string.format('(%.3f, %.3f, %.3f)',unpack(pt)))
    simUI.setLabelText(ui,13,string.format('(%.3f, %.3f, %.3f)',unpack(n)))
    simUI.setLabelText(ui,15,string.format('%s',sim.getObjectAlias(o,9)))
end

function displayTriangleInfo(pt,n,o)
    pt=Matrix(1,3,pt)
    if not simIGL then return end
    if not meshInfo then meshInfo={} end
    if not meshInfo[o] then
        meshInfo[o]={}
        meshInfo[o].mesh=simIGL.getMesh(o)
        meshInfo[o].f=Matrix(-1,3,meshInfo[o].mesh.indices)
        meshInfo[o].v=Matrix(-1,3,meshInfo[o].mesh.vertices)
        meshInfo[o].e,meshInfo[o].ue,meshInfo[o].emap,meshInfo[o].uec,meshInfo[o].uee=simIGL.uniqueEdgeMap(meshInfo[o].f:totable{})
    end
    local r,s=simIGL.closestFacet(meshInfo[o].mesh,pt:totable{},meshInfo[o].emap,meshInfo[o].uec,meshInfo[o].uee)
    local tri=meshInfo[o].f[1+r[1]]
    local v={
        meshInfo[o].v[1+tri[1]],
        meshInfo[o].v[1+tri[2]],
        meshInfo[o].v[1+tri[3]],
    }
    local dist={
        (v[1]-pt):t():norm(),
        (v[2]-pt):t():norm(),
        (v[3]-pt):t():norm(),
        ((v[1]+v[2]+v[3])/3-pt):t():norm(),
    }
    local closest,d=nil,nil
    for i=1,4 do if not d or dist[i]<d then closest,d=i,dist[i] end end
    simUI.setWidgetVisibility(ui,18,true)
    local faceIndex,vertexIndex=r[1],-1
    simUI.setLabelText(ui,31,string.format('%d',faceIndex))
    if closest~=4 then
        vertexIndex=tri[closest]
        simUI.setLabelText(ui,33,string.format('%d (%.3f, %.3f, %.3f)',vertexIndex,unpack(v[closest]:data())))
        local itemData=v[closest]:data()
        table.insert(itemData,0.0025*distanceToCamera(v[closest]))
        sim.addDrawingObjectItem(trianglesv,itemData)
    end
    for _,i in ipairs{1,2,3,1} do
        sim.addDrawingObjectItem(triangles,v[i]:data())
    end
    return faceIndex,vertexIndex
end

function createDummy(pt,n)
    local h=sim.createDummy(0.02)
    sim.setObjectColor(h,0,sim.colorcomponent_ambient_diffuse,{0,1,0})
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
    sim.setObjectMatrix(h,sim.handle_world,m)
    sim.setObjectParent(h,parent or -1)
    local zOffset=simUI.getSpinboxValue(ui,8)
    sim.setObjectPose(h,h,{0,0,zOffset,0,0,0,1})
end

function showDlg()
    if not ui then
        pts=sim.addDrawingObject(sim.drawing_spherepts|sim.drawing_itemsizes,0.01,0,-1,1,{0,1,0})
        lines=sim.addDrawingObject(sim.drawing_lines,2,0,-1,1,{0,1,0})
        triangles=sim.addDrawingObject(sim.drawing_linestrip,4,0,-1,4,{0,1,0})
        trianglesv=sim.addDrawingObject(sim.drawing_spherepts|sim.drawing_itemsizes,0.0025,0,-1,1,{0,1,0})
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local xml='<ui title="Point sampler" activate="false" closeable="true" on-close="close_callback" '..pos..[[>
            <group layout="form" flat="true" content-margins="0,0,0,0">
                <label id="10" text="Position:"/>
                <label id="11" text="N/A"/>
                <label id="12" text="Normal:"/>
                <label id="13" text="N/A"/>
                <label id="14" text="Object:"/>
                <label id="15" text="N/A"/>
            </group>
            <group id="19" layout="vbox" flat="true" content-margins="0,0,0,0">
                <checkbox checked="false" text="Display triangle/vertex info (only for shapes)" on-change="showTriangleInfo_callback" id="20" />
                <group id="18" visible="false" layout="form" flat="true" content-margins="20,0,0,0">
                    <label id="30" text="Triangle:"/>
                    <label id="31" text="N/A"/>
                    <label id="32" text="Vertex:"/>
                    <label id="33" text="N/A"/>
                </group>
            </group>
            <group layout="vbox" flat="true" content-margins="0,0,0,0">
                <checkbox checked="false" text="Create a dummy with each click" on-change="createDummy_callback" id="1" />
                <group id="5" visible="false" layout="form" flat="true" content-margins="20,0,0,0">
                    <label id="6" text="Parent:"/>
                    <combobox id="4" on-change="parentChange_callback"/>
                    <label id="7" text="Offset: [m]"/>
                    <spinbox id="8" value="0.0" step="0.01"/>
                </group>
            </group>
        </ui>]]
        ui=simUI.create(xml)
        populateParentCombobox()
        simUI.setCheckboxValue(ui,1,createDummies and 2 or 0)
        if not simIGL then
            simUI.setWidgetVisibility(ui,19,false)
            simUI.adjustSize(ui)
        end
    end
end

function hideDlg()
    if ui then
        uiPos={}
        uiPos[1],uiPos[2]=simUI.getPosition(ui)
        simUI.destroy(ui)
        ui=nil
        sim.removeDrawingObject(pts)
        sim.removeDrawingObject(lines)
        sim.removeDrawingObject(triangles)
        sim.removeDrawingObject(trianglesv)
    end
end

function showTriangleInfo_callback(ui,id,v)
    showTriangleInfo=v>0
    simUI.setWidgetVisibility(ui,18,showTriangleInfo)
    simUI.adjustSize(ui)
end

function createDummy_callback(ui,id,v)
    createDummies=v>0
    simUI.setWidgetVisibility(ui,5,createDummies)
    simUI.adjustSize(ui)
    if createDummies then populateParentCombobox() end
end

function populateParentCombobox()
    local items,sel={},simUI.getComboboxSelectedIndex(ui,4)
    local seln=simUI.getComboboxItemText(ui,4,sel)
    for i,h in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        local n=sim.getObjectAlias(h,1)
        table.insert(items,n)
        if n==seln then sel=i-1 end
    end
    simUI.setComboboxItems(ui,4,items,sel)
end

function parentChange_callback(ui,id,v)
    if v<0 then parent=-1; return end
    local txt=simUI.getComboboxItemText(ui,id,v)
    local h=sim.getObject(txt)
    parent=h
end

function close_callback()
    leaveNow=true
end

