function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh convex hull'}
end

function sysCall_init()
    if sim.isPluginLoaded('QHull') then
        local sel=sim.getObjectSelection()
        local numShapesFound=0
        local vert={}
        for _,h in ipairs(sel) do
            local t=sim.getObjectType(h)
            if t==sim.object_shape_type then
                local v,i,n=sim.getShapeMesh(h)
                local m=sim.getObjectMatrix(h,-1)
                v=sim.multiplyVector(m,v)
                for _,x in ipairs(v) do table.insert(vert,x) end
                numShapesFound=numShapesFound+1
            elseif t==sim.object_dummy_type then
                local p=sim.getObjectPosition(h,-1)
                for _,x in ipairs(p) do table.insert(vert,x) end
                numShapesFound=numShapesFound+1
            end
        end
        if numShapesFound==0 then
            simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','Select at least one shape.')
        else
            local v,i=simQHull.compute(vert,true)
            local h=sim.createMeshShape(3,math.pi/8,v,i)
            sim.announceSceneContentChange()
        end
    else
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','This tool requires the QHull plugin.')
    end
    return {cmd='cleanup'}
end
