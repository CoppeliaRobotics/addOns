function sysCall_info()
    return {autoStart=false}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    createDummies=false
    sim.addLog(sim.verbosity_scriptinfos,"This tool allows to sample points in the scene, and optionally create dummies from them")
    showDlg()
    sim.broadcastMsg{id='pointSampler.enable',data={hover=true,surfacePoint=true,surfaceNormal=true,triangle=true,vertex=true}}
end

function sysCall_msg(event)
    if event.id=='pointSampler.click' then
        if createDummies then
            createDummy(event.data.point,event.data.normal)
        end
    elseif event.id=='pointSampler.hover' then
        if event.data.point then
            simUI.setLabelText(ui,11,string.format('(%.3f, %.3f, %.3f)',unpack(event.data.point)))
        else
            simUI.setLabelText(ui,11,'N/A')
        end
        if event.data.normal then
            simUI.setLabelText(ui,13,string.format('(%.3f, %.3f, %.3f)',unpack(event.data.normal)))
        else
            simUI.setLabelText(ui,13,'N/A')
        end
        if event.data.handle then
            simUI.setLabelText(ui,15,string.format('%s',sim.getObjectAlias(event.data.handle,9)))
        else
            simUI.setLabelText(ui,15,'N/A')
        end
        if event.data.shape then
            simUI.setLabelText(ui,31,string.format('%d',event.data.shape.triangleIndex))
            simUI.setLabelText(ui,33,string.format('%d',event.data.shape.vertexIndex))
        else
            simUI.setLabelText(ui,31,'N/A')
            simUI.setLabelText(ui,33,'N/A')
        end
    end
end

function sysCall_nonSimulation()
    if leaveNow then
        sim.broadcastMsg{id='pointSampler.disable'}
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

function createDummy(pt,n)
    local h=sim.createDummy(0.02)
    sim.setObjectColor(h,0,sim.colorcomponent_ambient_diffuse,{0,1,0})
    sim.setObjectMatrix(h,sim.handle_world,pointNormalToMatrix(pt,n))
    local zOffset=simUI.getSpinboxValue(ui,8)
    sim.setObjectPose(h,h,{0,0,zOffset,0,0,0,1})
end

function showDlg()
    if not ui then
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local xml='<ui title="Point sampler" style="min-width: 9em;" activate="false" closeable="true" resizable="true" on-close="close_callback" '..pos..[[>
            <group layout="form" flat="true" content-margins="0,0,0,0">
                <label id="10" text="Position:"/>
                <label id="11" text="N/A"/>
                <label id="12" text="Normal:"/>
                <label id="13" text="N/A"/>
                <label id="14" text="Object:"/>
                <label id="15" text="N/A"/>
                <label id="30" text="Triangle:"/>
                <label id="31" text="N/A"/>
                <label id="32" text="Vertex:"/>
                <label id="33" text="N/A"/>
            </group>
            <group layout="vbox" flat="true" content-margins="0,0,0,0">
                <checkbox checked="false" text="Create a dummy with each click" on-change="createDummy_callback" id="1" />
                <group id="5" enabled="false" layout="form" flat="true" content-margins="20,0,0,0">
                    <label id="7" text="Offset: [m]"/>
                    <spinbox id="8" value="0.0" step="0.01"/>
                </group>
            </group>
        </ui>]]
        ui=simUI.create(xml)
        simUI.setCheckboxValue(ui,1,createDummies and 2 or 0)
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

function createDummy_callback(ui,id,v)
    createDummies=v>0
    simUI.setEnabled(ui,5,createDummies)
end

function close_callback()
    leaveNow=true
end

