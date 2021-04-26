function sysCall_info()
    return {autoStart=false}
end

function sysCall_init()
    sim.addLog(sim.verbosity_scriptinfos,"This tool will display the custom data blocks attached to the selected object, or the custom data blocks attached to the scene, if no object is selected. Custom data blocks can be written and read with simWriteCustomDataBlock and simReadCustomDataBlock.")
    object=-1
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function clearClick_callback(ui,id,newVal)
    sim.writeCustomDataBlock(object,tags[id],'')
    hideDlg()
end

function onCloseClicked()
    leaveNow=true
end

function showDlg()
    if not ui then
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local title="Custom data blocks in scene:"
        if object>=0 then
            title="Custom data blocks in object '"..sim.getObjectName(object).."':"
        end
        if not ui then
            xml = '<ui title="Custom Data Block Reader" closeable="true" on-close="onCloseClicked" resizable="false" '..pos..'>'
            xml=xml..'<label text="'..title..'" style="* {margin-right: 100px;}"/>'
            xml=xml..'<group layout="form" flat="true">'
            for i=1,#sizes,1 do
                xml=xml..'<label text="'..tags[i]..'  ('..sizes[i]..' bytes)"/>'
                xml=xml..'<button text="Clear" checked="false" on-click="clearClick_callback" id="'..i..'" />'
            end
            xml=xml..'</group>'
            if #sizes<#tags then
                xml=xml..'<label text="('..(#tags-#sizes)..' more)" />'
            end
            xml=xml..'</ui>'

            ui=simUI.create(xml)
        end
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

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
    local s=sim.getObjectSelection()
    local previousObject,previousTags,previousSizes=object,tags,sizes
    tags=nil
    sizes=nil
    object=-1
    if s then
        if #s>=1 then
            if s[#s]>=0 then
                object=s[#s]
                tags=sim.readCustomDataBlockTags(object)
            end
        end
    else
        tags=sim.readCustomDataBlockTags(sim.handle_scene)
    end
    if previousObject~=object then
        hideDlg()
    end
    if tags then
        sizes={}
        for i=1,math.min(#tags,10),1 do
            sizes[i]=#sim.readCustomDataBlock(object,tags[i])
        end
        local _=function(x) return x~=nil and sim.packTable(x) or nil end
        if _(tags)~=_(previousTags) or _(sizes)~=_(previousSizes) then
            hideDlg()
        end
        showDlg()
    else
        hideDlg()
    end
end
