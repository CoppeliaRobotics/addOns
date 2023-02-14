function sysCall_info()
    return {autoStart=false,menu='Exporters\nScript capture'}
end

function sysCall_init()
    sim.test('sim.enableEvents',true)
    sim.test('sim.mergeEvents',true)
    sim.test('sim.cborEvents',true)
    cbor=require'org.conman.cbor'
    ui=simUI.create[[<ui
        title="Script capture"
        resizable="true"
        closeable="true"
        activate="false"
        size="400,500"
        position="-10,-90"
        placement="relative"
        on-close="editorClosed"
    >
        <group flat="true" content-margins="1,1,1,1" layout="hbox">
            <label text="Capture:" />
            <checkbox id="101" text="Pose" checked="true" />
            <checkbox id="102" text="Parent" checked="true" />
            <checkbox id="103" text="Alias" />
        </group>
        <group flat="true" content-margins="1,1,1,1" layout="hbox">
            <edit id="2" />
            <button text="Insert comment" on-click="insertComment" />
        </group>
        <text-browser id="1" text="" html="false" />
    </ui>]]
    trackedHandles={}
    log={}
    updateCode()
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
end

function sysCall_cleanup()
end

function sysCall_event(es)
    es=cbor.decode(es)
    for _,e in ipairs(es) do
        if e.event=='objectAdded' then
            onObjectAdded(e.handle)
        elseif e.event=='objectChanged' then
            onObjectChanged(e.handle)
        elseif e.event=='objectRemoved' then
            onObjectRemoved(e.handle)
        end
    end
end

function insertComment()
    table.insert(log,{code='-- '..simUI.getEditValue(ui,2)})
    simUI.setEditValue(ui,2,'')
    updateCode()
end

function editorClosed()
    leaveNow=true
end

function onObjectAdded(handle)
    trackedHandles[handle]={}
    local code=''
    local objType=sim.getObjectType(handle)
    local id=objectId(handle)
    if objType==sim.object_shape_type then
        result,pureType,dims=sim.getShapeGeomInfo(handle)
        if result&2>0 then
            code=string.format('%s=sim.createPrimitiveShape(%s,%s,%d)',
                id,
                getConstantName(pureType,'primitiveshape_'),
                table.tostring(dims,','),
                1*sim.getObjectInt32Param(handle,sim.shapeintparam_culling)+
                2*sim.getObjectInt32Param(handle,sim.shapeintparam_edge_visibility)
            )
        else
            code=string.format('%s=sim.createMeshShape(...)',id)
        end
    elseif objType==sim.object_joint_type then
        local jointType=sim.getJointType(handle)
        local jointMode=sim.getJointMode(handle)
        code=string.format('%s=sim.createJoint(%s,%s,0)',
            id,
            getConstantName(jointType,'joint_','_subtype'),
            getConstantName(jointMode,'jointmode_')
        )
    elseif objType==sim.object_dummy_type then
        code=string.format('%s=sim.createDummy(0.01)',id)
    else
        code=id..'=nil -- not implemented type (type='..getConstantName(objType,'object_','_type')..', handle='..handle..')'
        trackedHandles[handle]=nil
    end
    table.insert(log,{
        type='create',
        handles={handle},
        code=code,
    })
    onObjectChanged(handle)
end

function onObjectChanged(handle)
    if not trackedHandles[handle] then return end
    
    if simUI.getCheckboxValue(ui,102)>0 then
        local parent=sim.getObjectParent(handle)
        if parent~=sim.handle_world and parent~=trackedHandles[handle].parent then
            trackedHandles[handle].parent=parent
            table.insert(log,{
                type='set-parent',
                handles={handle,parent},
                code=string.format('sim.setObjectParent(%s,%s)',objectId(handle),objectId(parent)),
            })
        end
    end
    
    if simUI.getCheckboxValue(ui,103)>0 then
        local alias=sim.getObjectAlias(handle)
        if alias~=trackedHandles[handle].alias then
            trackedHandles[handle].alias=alias
            table.insert(log,{
                type='set-alias',
                handles={handle},
                code=string.format('sim.setObjectAlias(%s,"%s")',objectId(handle),alias),
            })
        end
    end

    if simUI.getCheckboxValue(ui,101)>0 then
        local pose=sim.getObjectPose(handle,sim.handle_parent)
        if not table.eq(pose,trackedHandles[handle].pose) then
            trackedHandles[handle].pose=pose
            table.insert(log,{
                type='set-pose',
                handles={handle},
                code=string.format('sim.setObjectPose(%s,sim.handle_parent,%s)',objectId(handle),table.tostring(pose,',')),
            })
        end
    end
    
    updateCode()
end

function onObjectRemoved(handle)
    if not trackedHandles[handle] then return end

    table.insert(log,{
        type='remove',
        handles={handle},
        code=string.format('sim.removeObjects{%s}',objectId(handle)),
    })
    trackedHandles[handle]=nil
    
    updateCode()
end

function updateCode()
    consolidateLog()
    code='-- Script capture is running. Close this window to stop.\n\n'
    for i,entry in ipairs(log) do
        if i==#log or entry.type~=log[i+1].type or entry.handle~=log[i+1].handle then
            code=code..entry.code..'\n'
        end
    end
    simUI.setText(ui,1,code)
end

function getConstantName(v,prefix,suffix)
    for k,v_ in pairs(sim) do
        if (prefix==nil or string.startswith(k,prefix)) and (suffix==nil or string.endswith(k,suffix)) and v==v_ then
            return 'sim.'..k
        end
    end
end

function objectId(handle)
    return string.format('obj%d',handle)
end

function consolidateLog()
    local newLog={}
    local i=1
    while i<=#log do
        if log[i].type=='remove' then
            local r=table.slice(log[i].handles)
            while i<#log and log[i+1].type=='remove' do
                i=i+1
                for _,x in ipairs(log[i].handles) do table.insert(r,x) end
            end
            table.insert(newLog,{
                type='remove',
                handles=r,
                code=string.format('sim.removeObjects%s',table.tostring(map(objectId,r),',')),
            })
        elseif i==#log or log[i].type~=log[i+1].type or log[i].handle~=log[i+1].handle then
            table.insert(newLog,log[i])
        end
        i=i+1
    end
    log=newLog
end
