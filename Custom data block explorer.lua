sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nCustom data block explorer'}
end

function sysCall_init()
    simUI = require 'simUI'
    cbor = require 'org.conman.cbor'
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool will display the custom data blocks attached to the selected object, or the custom data blocks attached to the scene, if no object is selected. Custom data blocks can be written and read with simWriteCustomDataBlock and simReadCustomDataBlock."
    )
    object = -1
    selectedDecoder = 1
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

decoders = {
    {
        name = 'auto',
        f = function(tag, data, type)
            if type then
                local d = getDecoderForType(type)
                if d then
                    return d.f(tag, data, type)
                else
                    error('unknown type: ' .. type)
                end
            end
            return '<font color=#b75501>For automatic selection of decoder, there must be an \'__info__\' block with type information, e.g.: {blocks={myTagName={type=\'table\'}}}, which is normally written by sim.writeCustomTableData or sim.writeCustomDataBlockEx.</font>'
        end,
    },
    {
        name = 'binary',
        f = function(tag, data, type)
            return '<tt>' .. data:gsub('(.)', function(y) return string.format('%02X ', string.byte(y)) end) .. '</tt>'
        end,
    },
    {
        name = 'string',
        f = function(tag, data, type)
            return data
        end,
    },
    {
        name = 'table',
        f = function(tag, data, type)
            local status, data = pcall(function() return sim.unpackTable(data) end)
            if status then
                return _S.tableToString(data, {indent = true}):gsub('[\n ]', {['\n'] = '<br/>', [' '] = '&nbsp;'})
            end
        end,
    },
    {
        name = 'cbor',
        f = function(tag, data, type)
            local status, data = pcall(function() return cbor.decode(data) end)
            if status then
                return _S.tableToString(data, {indent = true}):gsub('[\n ]', {['\n'] = '<br/>', [' '] = '&nbsp;'})
            end
        end,
    },
    {
        name = 'float[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackFloatTable(data))
        end,
    },
    {
        name = 'double[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackDoubleTable(data))
        end,
    },
    {
        name = 'int32[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackInt32Table(data))
        end,
    },
    {
        name = 'uint8[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackUInt8Table(data))
        end,
    },
    {
        name = 'uint16[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackUInt16Table(data))
        end,
    },
    {
        name = 'uint32[]',
        f = function(tag, data, type)
            return getAsString(sim.unpackUInt32Table(data))
        end,
    },
}

function getDecoderForType(t)
    for i, decoder in ipairs(decoders) do
        if decoder.name ~= 'auto' and decoder.name == t then return decoder end
    end
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

function onDecoderChanged()
    local index = simUI.getComboboxSelectedIndex(ui, 700)
    selectedDecoder = index + 1
    if selectedDecoder > 0 then
        local decoder = decoders[selectedDecoder]
        if selectedTag then
            local html = decoder.f(selectedTag, content[selectedTag][1], content[selectedTag][2])
            if html then
                simUI.setText(ui, 800, html)
            else
                simUI.setText(
                    ui, 800, string.format('<font color=red>Not %s data</font>', decoder.name)
                )
            end
        end
    else
        simUI.setText(ui, 800, '')
    end
end

function onSelectedBlockChanged(ui, id, row, column)
    if row == -1 then
        selectedTag = nil
    else
        selectedTag = simUI.getItem(ui, id, row, 0)
    end
    local e = selectedTag and true or false
    simUI.setEnabled(ui, 20, e)
    simUI.setEnabled(ui, 700, e)
    onDecoderChanged()
end

function onClearClicked(ui, id)
    if selectedTag then
        sim.writeCustomDataBlock(object, selectedTag, '')
        sim.announceSceneContentChange()
        hideDlg()
    end
end

function onCloseClicked()
    leaveNow = true
end

function showDlg()
    if not ui then
        local pos = 'position="-30,160" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local title = "Custom data blocks in scene:"
        if object ~= sim.handle_scene then
            title = "Custom data blocks in object '<b>" .. sim.getObjectAlias(object, 0) .. "</b>':"
        end
        if not ui then
            xml =
                '<ui title="Custom Data Block Explorer" activate="false" closeable="true" on-close="onCloseClicked" resizable="true" ' ..
                    pos .. '>'
            xml = xml .. '<group flat="true"><label text="' .. title .. '" /></group>'
            xml = xml ..
                      '<table id="600" selection-mode="row" editable="false" on-selection-change="onSelectedBlockChanged">'
            xml = xml ..
                      '<header><item>Tag name</item><item>Size (bytes)</item><item>Type</item></header>'
            local selectedIndex, i = -1, 0
            for tag, data in pairs(content) do
                if tag == selectedTag then selectedIndex = i end
                xml = xml .. '<row>'
                xml = xml .. '<item>' .. tag .. '</item>'
                xml = xml .. '<item>' .. #data[1] .. '</item>'
                if data[2] then xml = xml .. '<item>' .. data[2] .. '</item>' end
                xml = xml .. '</row>'
                i = i + 1
            end
            xml = xml .. '</table>'
            xml = xml .. '<group flat="true" layout="grid">'
            xml = xml .. '<label text="Decode as:" />'
            xml = xml .. '<combobox id="700" on-change="onDecoderChanged">'
            for i, decoder in ipairs(decoders) do
                xml = xml .. '<item>' .. decoder.name .. '</item>'
            end
            xml = xml .. '</combobox>'
            xml = xml .. '</group>'
            xml = xml .. '<text-browser id="800" read-only="true" />'
            xml = xml ..
                      '<button id="20" enabled="false" text="Clear selected tag" on-click="onClearClicked" />'
            xml = xml .. '</ui>'
            ui = simUI.create(xml)
            if selectedIndex ~= -1 then
                simUI.setTableSelection(ui, 600, selectedIndex, 0, false)
            end
            simUI.setComboboxSelectedIndex(ui, 700, selectedDecoder - 1)
        end
    end
end

function hideDlg()
    if ui then
        uiPos = {}
        uiPos[1], uiPos[2] = simUI.getPosition(ui)
        simUI.destroy(ui)
        ui = nil
    end
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_selChange(inData)
    local s = inData.sel
    local previousObject, previousContent = object, content
    content = nil
    object = -1
    info = nil
    local tags = nil
    if #s == 1 then
        object = s[#s]
    elseif #s == 0 then
        object = sim.handle_scene
    end
    if object ~= -1 then
        tags = sim.readCustomDataBlockTags(object)
        info = sim.readCustomTableData(object, '__info__')
    end
    if previousObject ~= object then hideDlg() end
    if tags then
        content = {}
        for i, tag in ipairs(tags) do content[tag] = {sim.readCustomDataBlockEx(object, tag)} end
        local _ = function(x)
            return x ~= nil and sim.packTable(x) or nil
        end
        if _(content) ~= _(previousContent) then hideDlg() end
        showDlg()
    else
        hideDlg()
    end
end
