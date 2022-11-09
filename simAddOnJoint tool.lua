function sysCall_info()
    return {autoStart=false}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    sim.addLog(sim.verbosity_scriptinfos,"Select an object to use the Joint tool.")
    sel={}
    idToJointMap={}
end

function setJointPos(ui,id,val)
    local h=idToJointMap[id]
    local p=val*math.pi/180
    sim.setJointPosition(h,p)
end

function closeUi()
    if not ui then return end
    uiPos=table.pack(simUI.getPosition(ui))
    simUI.destroy(ui)
    ui=nil
end

function onSelectionChanged()
    idToJointMap={}
    local nid=1
    closeUi()
    for i,sh in ipairs(sel) do
        for j,h in ipairs(sim.getObjectsInTree(sh,sim.object_joint_type)) do
            local mh,a,b=sim.getJointDependency(h)
            if mh==-1 then
                idToJointMap[nid]=h
                nid=nid+1
            end
        end
    end
    if nid==1 then return end
    local uiPosStr=uiPos and string.format('placement="absolute" position="%d,%d"' ,table.unpack(uiPos)) or 'placement="relative" position="280,500" '
    xml='<ui closeable="true" '..uiPosStr..'resizable="false" on-close="closeUi" title="Joint tool" layout="form">\n'
    for id,h in pairs(idToJointMap) do
        local v=sim.getJointPosition(h)*180/math.pi
        local cyclic,i=sim.getJointInterval(h)
        local vmin,vmax=i[1]*180/math.pi,(i[1]+i[2])*180/math.pi
        xml=xml..string.format('    <label text="%s" />\n',sim.getObjectAlias(h))
        xml=xml..string.format('    <group flat="true" content-margins="0,0,0,0" layout="hbox"><spinbox id="%s" value="%f" minimum="%f" maximum="%f" step="0.5" on-change="setJointPos" /><label text="%.1f~%.1f [deg]" enabled="false" /></group>\n',id,v,vmin,vmax,vmin,vmax)
    end
    xml=xml..'</ui>'
    ui=simUI.create(xml)
end

function checkSelectionChanged()
    local newsel=sim.getObjectSelection()
    table.sort(newsel)
    if sim.packInt32Table(sel)~=sim.packInt32Table(newsel) then
        sel=newsel
        onSelectionChanged()
        return
    end
end

function sysCall_nonSimulation()
    checkSelectionChanged()
end

function sysCall_sensing()
    checkSelectionChanged()
end

function sysCall_cleanup()
    if ui then simUI.destroy(ui) end
end
