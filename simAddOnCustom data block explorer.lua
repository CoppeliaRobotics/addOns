function sysCall_info()
    return {autoStart=false}
end

function sysCall_init()
    sim.addLog(sim.verbosity_scriptinfos,"This tool will display the custom data blocks attached to the selected object, or the custom data blocks attached to the scene, if no object is selected. Custom data blocks can be written and read with simWriteCustomDataBlock and simReadCustomDataBlock.")
    object=-1
    selectedDecoder=100
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

decoders={
    {
        id=100,
        name='binary',
        f=function(tag,data)
            return '<tt>'..data:gsub('(.)',function(y)
                return string.format('%02X ',string.byte(y))
            end)..'</tt>'
        end,
    },
    {
        id=108,
        name='string',
        f=function(tag,data)
            return data
        end,
    },
    {
        id=101,
        name='table',
        f=function(tag,data)
            local status,data=pcall(function() return sim.unpackTable(data) end)
            if status then
                return getAsString(data):gsub('[\n ]',{['\n']='<br/>',[' ']='&nbsp;'})
            end
        end,
    },
    {
        id=102,
        name='float[]',
        f=function(tag,data)
            return getAsString(sim.unpackFloatTable(data))
        end,
    },
    {
        id=103,
        name='double[]',
        f=function(tag,data)
            return getAsString(sim.unpackDoubleTable(data))
        end,
    },
    {
        id=104,
        name='int32[]',
        f=function(tag,data)
            return getAsString(sim.unpackInt32Table(data))
        end,
    },
    {
        id=105,
        name='uint8[]',
        f=function(tag,data)
            return getAsString(sim.unpackUInt8Table(data))
        end,
    },
    {
        id=106,
        name='uint16[]',
        f=function(tag,data)
            return getAsString(sim.unpackUInt16Table(data))
        end,
    },
    {
        id=107,
        name='uint32[]',
        f=function(tag,data)
            return getAsString(sim.unpackUInt32Table(data))
        end,
    },
    {
        id=199,
        name='auto',
        f=function(tag,data)
            local hint=tag:match("^.+(%..+)$")
            for i,decoder in ipairs(decoders) do
                if decoder.name~='auto' then
                    local h='.'..decoder.name
                    if h==hint then
                        return decoder.f(tag,data)
                    end
                end
            end
            return '<font color=#b75501>For automatic selection of decoder, the tag name must end with a dot followed by the decoder name, e.g.: myTagName.table</font>'
        end,
    },
}

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function onDecoderChanged()
    for _,decoder in ipairs(decoders) do
        if selectedTag and simUI.getRadiobuttonValue(ui,decoder.id)>0 then
            selectedDecoder=decoder.id
            local html=decoder.f(selectedTag,content[selectedTag])
            if html then
                simUI.setText(ui,800,html)
            else
                simUI.setText(ui,800,string.format('<font color=red>Not %s data</font>',decoder.name))
            end
        end
    end
end

function onSelectionChange(ui,id,row,column)
    if row==-1 then
        selectedTag=nil
    else
        selectedTag=simUI.getItem(ui,id,row,0)
    end
    local e=selectedTag and true or false
    simUI.setEnabled(ui,20,e)
    for _,decoder in ipairs(decoders) do
        simUI.setEnabled(ui,decoder.id,e)
    end
    onDecoderChanged()
end

function onClearClicked(ui,id)
    if selectedTag then
        sim.writeCustomDataBlock(object,selectedTag,'')
        hideDlg()
    end
end

function onCloseClicked()
    leaveNow=true
end

function showDlg()
    if not ui then
        local pos='position="-30,160" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local title="Custom data blocks in scene:"
        if object>=0 then
            title="Custom data blocks in object '<b>"..sim.getObjectName(object).."</b>':"
        end
        if not ui then
            xml='<ui title="Custom Data Block Explorer" closeable="true" on-close="onCloseClicked" resizable="false" '..pos..'>'
            xml=xml..'<group flat="true"><label text="'..title..'" /></group>'
            xml=xml..'<table id="600" selection-mode="row" editable="false" on-selection-change="onSelectionChange">'
            xml=xml..'<header><item>Tag name</item><item>Size (bytes)</item></header>'
            local selectedIndex,i=-1,0
            for tag,data in pairs(content) do
                if tag==selectedTag then selectedIndex=i end
                xml=xml..'<row><item>'..tag..'</item><item>'..#data..'</item></row>'
                i=i+1
            end
            xml=xml..'</table>'
            xml=xml..'<group flat="true" layout="grid">'
            xml=xml..'<label text="Decode as:" />'
            for i,decoder in ipairs(decoders) do
                if i>1 and (i-1)%3==0 then xml=xml..'<br/><label text="" />' end
                xml=xml..'<radiobutton id="'..decoder.id..'" enabled="false" text="'..decoder.name..'" checked="'..(selectedDecoder==decoder.id and 'true' or 'false')..'" on-click="onDecoderChanged" />'
            end
            xml=xml..'</group>'
            xml=xml..'<text-browser id="800" read-only="true" />'
            xml=xml..'<button id="20" enabled="false" text="Clear selected tag" on-click="onClearClicked" />'
            xml=xml..'</ui>'
            ui=simUI.create(xml)
            if selectedIndex~=-1 then
                simUI.setTableSelection(ui,600,selectedIndex,0,false)
            end
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
    local previousObject,previousContent=object,content
    content=nil
    object=-1
    local tags={}
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
        content={}
        for i,tag in ipairs(tags) do
            content[tag]=sim.readCustomDataBlock(object,tag)
        end
        local _=function(x) return x~=nil and sim.packTable(x) or nil end
        if _(content)~=_(previousContent) then
            hideDlg()
        end
        showDlg()
    else
        hideDlg()
    end
end
