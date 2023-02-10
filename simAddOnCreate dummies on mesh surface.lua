function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nCreate dummies on mesh surface'}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    sim.addLog(sim.verbosity_scriptinfos,"This tool allows to create dummies from points sampled on mesh surfaces")
    showDlg()
    sim.broadcastMsg{id='pointSampler.enable',data={key='createDummiesOnMeshSurf',surfacePoint=true,surfaceNormal=true}}
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key~='createDummiesOnMeshSurf' then return end
    if event.id=='pointSampler.click' then
        if event.data.pointNormalMatrix then
            createDummy(event.data.pointNormalMatrix)
            sim.announceSceneContentChange()
        end
    end
end

function sysCall_nonSimulation()
    if leaveNow then
        sim.broadcastMsg{id='pointSampler.disable',data={key='createDummiesOnMeshSurf'}}
        return {cmd='cleanup'}
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

function clearTextInfo()
end

function createDummy(m)
    local h=sim.createDummy(0.02)
    sim.setObjectColor(h,0,sim.colorcomponent_ambient_diffuse,{0,1,0})
    sim.setObjectMatrix(h,sim.handle_world,m)
    local zOffset=simUI.getSpinboxValue(ui,8)
    sim.setObjectPose(h,h,{0,0,zOffset,0,0,0,1})
    local alias=simUI.getEditValue(ui,6)
    sim.setObjectAlias(h,alias)
end

function showDlg()
    if not ui then
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local xml='<ui title="Create dummies on mesh surface" style="min-width: 9em;" activate="false" closeable="true" resizable="true" on-close="close_callback" '..pos..[[>
            <label id="5" text="Alias:"/>
            <edit id="6" value="Dummy"/>
            <label id="7" text="Offset: [m]"/>
            <spinbox id="8" value="0.0" step="0.01"/>
        </ui>]]
        ui=simUI.create(xml)
    end
end

function hideDlg()
    if ui then
        uiPos={}
        uiPos[1],uiPos[2]=simUI.getPosition(ui)
        simUI.destroy(ui)
        ui=nil
    end
end

function close_callback()
    leaveNow=true
end
