sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nProperty explorer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    simUI = require 'simUI'

    target = sim.handle_app
    selectedProperty = ''
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
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

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end

    if target ~= oldTarget then
        onTargetChanged()
        oldTarget = target
    end
end

function sysCall_selChange(inData)
    if target == sim.handle_app or target == sim.handle_appstorage then
        -- if app/appstorage selected, object selection won't switch target
        return
    else
        -- otherwise currently selected object or scene if empty selection
        target = inData.sel[#inData.sel] or sim.handle_scene
    end
end

function sysCall_event(events)
    for _, e in ipairs(cbor.decode(tostring(events))) do
        if e.handle == target and e.event == 'objectChanged' then
            if ui then onTargetChanged() end
        end
    end
end

function getProperty(h, n, ts)
    return 
end

function setTargetApp()
    target = sim.handle_app
end

function setTargetAppStorage()
    target = sim.handle_appstorage
end

function setTargetSel()
    local sel = sim.getObjectSel()
    target = sel[#sel] or sim.handle_scene
end

function onTargetChanged()
    properties = {}
    propertiesNames = {}
    if not typeStr then
        typeStr = {}
        for k, v in pairs(sim) do
            local m = string.match(k, 'propertytype_(.*)')
            if m then typeStr[v] = m end
        end
    end
    local i = -1
    while true do
        i = i + 1
        local pname = sim.getPropertyName(target, i)
        if not pname then break end
        table.insert(propertiesNames, pname)
        local ptype, pflags, psize = sim.getPropertyInfo(target, pname)
        local ts = typeStr[ptype]
        local pvalue = sim['get' .. string.capitalize(ts) .. 'Property'](target, pname)
        local vs = _S.anyToString(pvalue)
        properties[pname] = {type = ts, value = vs}
    end
    table.sort(propertiesNames)

    if not ui then showDlg() end
    if target == sim.handle_app then
        simUI.setLabelText(ui, ui_label_selection, 'sim.handle_app')
    elseif target == sim.handle_appstorage then
        simUI.setLabelText(ui, ui_label_selection, 'sim.handle_appstorage')
    elseif target == sim.handle_scene then
        simUI.setLabelText(ui, ui_label_selection, 'sim.handle_scene')
    else
        simUI.setLabelText(ui, ui_label_selection, sim.getObjectAlias(target, 1))
    end

    simUI.clearTable(ui, ui_table)
    simUI.setColumnCount(ui, ui_table, 3)
    simUI.setColumnHeaderText(ui, ui_table, 0, 'Name')
    simUI.setColumnHeaderText(ui, ui_table, 1, 'Type')
    simUI.setColumnHeaderText(ui, ui_table, 2, 'Value')
    simUI.setRowCount(ui, ui_table, #propertiesNames)
    selectedRow = -1
    for i, pname in ipairs(propertiesNames) do
        if selectedProperty == pname then selectedRow = i end
        local pinfo = properties[pname]
        simUI.setItem(ui, ui_table, i - 1, 0, pname)
        simUI.setItem(ui, ui_table, i - 1, 1, pinfo.type)
        simUI.setItem(ui, ui_table, i - 1, 2, pinfo.value)
    end
    if selectedRow ~= -1 then
        simUI.setTableSelection(ui, ui_table, selectedRow - 1, 0, false)
    end
end

function onRowSelected(ui, id, row, col)
    selectedProperty = propertiesNames[row + 1]
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
        if not ui then
            xml = '<ui title="Property Explorer" activate="false" closeable="true" on-close="onCloseClicked" resizable="true" ' .. pos .. '>'
            xml = xml .. '<group flat="true" layout="hbox">'
            xml = xml .. '<label text="Target:" />'
            xml = xml .. '<group flat="true">'
            xml = xml .. '<radiobutton text="App (session)" checked="' .. tostring(target == sim.handle_app) .. '" on-click="setTargetApp" />'
            xml = xml .. '<radiobutton text="App (storage)" checked="' .. tostring(target == sim.handle_appstorage) .. '" on-click="setTargetAppStorage" />'
            xml = xml .. '<radiobutton text="Selection (obj/scene)" checked="' .. tostring(target ~= sim.handle_app and target ~= sim.handle_appstorage) .. '" on-click="setTargetSel" />'
            xml = xml .. '</group>'
            xml = xml .. '</group>'
            xml = xml .. '<group flat="true" layout="hbox">'
            xml = xml .. '<label text="Selected target:" />'
            xml = xml .. '<label id="${ui_label_selection}" />'
            xml = xml .. '</group>'
            xml = xml .. '<table id="${ui_table}" selection-mode="row" editable="false" on-selection-change="onRowSelected">'
            xml = xml .. '<header><item>Name</item><item>Type</item><item>Value</item></header>'
            xml = xml .. '</table>'
            xml = xml .. '</ui>'
            ui = simUI.create(xml)
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
