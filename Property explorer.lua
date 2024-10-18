sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nProperty explorer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    simUI = require 'simUI'

    target = sim.handle_scene
    selectedProperty = ''
    filterMatching = '*'
    filterInvert = false

    createUi()
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    destroyUi()
end

function sysCall_afterInstanceSwitch()
    sysCall_selChange {sel = sim.getObjectSel()}
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
    checkTargetChanged()
end

function sysCall_sensing()
    checkTargetChanged()
end

function sysCall_selChange(inData)
    if target == sim.handle_app then
        -- if app selected, object selection won't switch target
        return
    else
        -- otherwise currently selected object or scene if empty selection
        target = inData.sel[#inData.sel] or sim.handle_scene
    end
end

function sysCall_event(events)
    for _, e in ipairs(cbor.decode(tostring(events))) do
        if e.handle == target and e.event == 'objectChanged' then
            local oldPropertiesNames = propertiesNames
            readTargetProperties()

            if not table.eq(oldPropertiesNames, propertiesNames) then
                -- some property was added or removed
                onTargetChanged()
            else
                for pname, pvalue in pairs(table.flatten(e.data)) do
                    local i = propertyNameToIndex[pname]
                    if i then updateTableRow(i, true) end
                end
            end
        end
    end
end

function checkTargetChanged()
    if target ~= oldTarget then
        onTargetChanged()
        oldTarget = target
    end
end

function setTargetApp()
    target = sim.handle_app
end

function setTargetSel()
    local sel = sim.getObjectSel()
    target = sel[#sel] or sim.handle_scene
end

function onSubTargetChanged(ui, id, i)
    target = comboHandles[i + 1]
end

function getFilteringPattern()
    local pat = filterMatching
    pat = string.gsub(pat, '%.', '%%.')
    pat = string.gsub(pat, '%*', '.*')
    pat = '^' .. pat .. '$'
    return pat
end

function propertyOrder(a, b)
    local ca = propertiesInfos[a].class
    local cb = propertiesInfos[b].class
    return ca < cb or (ca == cb and a < b)
end

function readTargetProperties()
    propertiesValues = sim.getProperties(target, {skipLarge = true})
    propertiesInfos = sim.getPropertiesInfos(target)
    propertiesNames = {}
    filteredPropertiesNames = {}
    local pat = getFilteringPattern()
    for pname, _ in pairs(propertiesInfos) do
        table.insert(propertiesNames, pname)
        local m = string.find(pname, pat)
        if (m and not filterInvert) or (not m and filterInvert) then
            table.insert(filteredPropertiesNames, pname)
        end
    end
    table.sort(propertiesNames, propertyOrder)
    table.sort(filteredPropertiesNames, propertyOrder)

    -- insert header at class break:
    local fpn = filteredPropertiesNames
    filteredPropertiesNames = {}
    local lastPClass = nil
    for _, pname in ipairs(fpn) do
        local pclass = propertiesInfos[pname].class
        if pclass ~= lastPClass then
            table.insert(filteredPropertiesNames, '#' .. pclass)
            lastPClass = pclass
        end
        table.insert(filteredPropertiesNames, pname)
    end

    -- optimization to avoid repopulation of whole table:
    propertyNameToIndex = {}
    for i, pname in ipairs(filteredPropertiesNames) do propertyNameToIndex[pname] = i end
end

function updateTableRow(i, updateSingle)
    local pname = filteredPropertiesNames[i]
    assert(pname)

    if pname:sub(1, 1) == '#' then
        -- class group header
        tableRows.pname[i] = '[' .. pname:sub(2) .. ']'
        tableRows.ptype[i] = ''
        tableRows.pvalue[i] = ''
    else
        -- normal row
        local f = propertiesInfos[pname].flags
        local ptype = propertiesInfos[pname].type
        local pvalue = f.large and '<big data>' or _S.anyToString(propertiesValues[pname])
        if not f.readable then pvalue = f.writable and '<write-only>' or '<not readable>' end
        ptype = sim.getPropertyTypeString(ptype)
        ptype = string.gsub(ptype, 'array$', '[]')
        if #pvalue > 30 then
            pvalue = pvalue:sub(1, 30) .. '...'
        end
        tableRows.pname[i] = '    ' .. pname
        tableRows.ptype[i] = ptype
        tableRows.pvalue[i] = pvalue
    end

    if updateSingle then
        simUI.setPropertiesRow(ui, ui_table, i - 1, tableRows.pname[i], tableRows.ptype[i], tableRows.pvalue[i])
    end
end

function onTargetChanged()
    readTargetProperties()
    comboLabels, comboHandles = {}, {}
    local comboIdx = 0
    if target == sim.handle_app then
        table.insert(comboLabels, 'sim.handle_app')
        table.insert(comboHandles, sim.handle_app)
    elseif target == sim.handle_scene then
        table.insert(comboLabels, 'sim.handle_scene')
        table.insert(comboHandles, sim.handle_scene)
    else
        local superTarget = target
        local objectType = sim.getStringProperty(target, 'objectType')
        if objectType == 'mesh' then
            superTarget = sim.getIntProperty(target, 'shapeUid')
            superTarget = sim.getObjectFromUid(superTarget)
        end
        table.insert(comboLabels, sim.getObjectAlias(superTarget, 1))
        table.insert(comboHandles, superTarget)
        if objectType == 'shape' or objectType == 'mesh' then
            local meshes = sim.getIntArrayProperty(superTarget, 'meshes')
            for i, mesh in ipairs(meshes) do
                table.insert(comboLabels, '    Mesh ' .. i)
                table.insert(comboHandles, mesh)
                if mesh == target then comboIdx = i end
            end
        end
    end
    simUI.setComboboxItems(ui, ui_combo_selection, comboLabels, comboIdx)
    selectedRow = -1
    tableRows = {pname = {}, ptype = {}, pvalue = {}}
    for i, pname in ipairs(filteredPropertiesNames) do
        if selectedProperty == pname then selectedRow = i end
        updateTableRow(i)
    end
    simUI.setProperties(ui, ui_table, tableRows.pname, tableRows.ptype, tableRows.pvalue)
    if selectedRow ~= -1 then
        simUI.setPropertiesSelection(ui, ui_table, selectedRow - 1, false)
    end
    updateButtonsForSelectedProperty()
end

function updateButtonsForSelectedProperty()
    canAssign = false
    canEdit = false
    canRemove = false
    if propertiesInfos[selectedProperty] and selectedProperty:sub(1, 1) ~= '#' then
        local f = propertiesInfos[selectedProperty].flags
        canAssign = f.readable
        canEdit = f.readable and f.writable
        canRemove = f.removable
    end
    simUI.setEnabled(ui, ui_assign, canAssign)
    simUI.setWidgetVisibility(ui, ui_edit, canEdit)
    simUI.setWidgetVisibility(ui, ui_remove, canRemove)
end

function onRowSelected(ui, id, row)
    selectedProperty = filteredPropertiesNames[row + 1]
    updateButtonsForSelectedProperty()
end

function onRowDoubleClicked(ui, id, row, col)
    if col == 2 then
        if canEdit then editValue() end
    else
        if canAssign then assignValue() end
    end
end

function onKeyPress(ui, id, key, text)
    key = key & 0x00FFFFFF
    if key == 3 or key == 7 then
        removeSelected()
    elseif text == '*' then
        setFilter('*', false)
    elseif text == 'c' or text == 'C' then
        setFilter('customData.*', text == 'C')
    end
end

function onCloseClicked()
    leaveNow = true
end

function setFilter(flt, inv)
    simUI.setEditValue(ui, ui_filter, flt)
    simUI.setCheckboxValue(ui, ui_filter_invert, inv and 2 or 0)
    updateFilter()
end

function updateFilter()
    filterMatching = simUI.getEditValue(ui, ui_filter)
    filterInvert = simUI.getCheckboxValue(ui, ui_filter_invert) > 0
    onTargetChanged()
end

function assignValue()
    local pvalue = sim.getProperty(target, selectedProperty)
    pvalue = _S.anyToString(pvalue)
    local targetStr = 'SEL1'
    if target == sim.handle_app then
        targetStr = 'sim.handle_app'
    elseif target == sim.handle_scene then
        targetStr = 'sim.handle_scene'
    end
    sim.executeScriptString(string.format('value = sim.getProperty(%d, \'%s\')@lua', target, selectedProperty), sim.getScript(sim.scripttype_sandbox))
    print(string.format('> value = sim.getProperty(%s, \'%s\')', targetStr, selectedProperty))
    if propertiesInfos[selectedProperty].flags.large then
        print('-- (large data)')
    else
        print(pvalue)
    end
end

function editValue()
    propertiesValues[selectedProperty] = sim.getProperty(target, selectedProperty)
    initialEditorContent = sim.convertPropertyValue(propertiesValues[selectedProperty], propertiesInfos[selectedProperty].type, sim.propertytype_string)
    editorHandle = sim.textEditorOpen(initialEditorContent, '<editor title="' .. (propertiesInfos[selectedProperty].flags.writable and 'Edit' or 'View') .. ' &quot;' .. selectedProperty .. '&quot; value" editable="' .. _S.anyToString(propertiesInfos[selectedProperty].flags.writable) .. '" searchable="true" tab-width="4" toolbar="false" statusbar="false" resizable="true" modal="true" on-close="editValueFinished" closeable="true" position="-20 400" size="400 300" placement="relative" activate="true" line-numbers="false"></editor>')
end

function editValueFinished()
    if editorHandle then
        local newValue, err = sim.textEditorGetInfo(editorHandle), nil
        if newValue ~= initialEditorContent then
            newValue, err = sim.convertPropertyValue(newValue, sim.propertytype_string, propertiesInfos[selectedProperty].type)
            if err then
                simUI.msgBox(simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Error', 'Failed to convert value: ' .. err)
            elseif propertiesInfos[selectedProperty].flags.writable then
                sim.setProperty(target, selectedProperty, newValue)
            end
        end
        sim.textEditorClose(editorHandle)
        initialEditorContent = nil
        editorHandle = nil
    end
end

function removeSelected()
    if not selectedProperty then return end
    if not propertiesInfos[selectedProperty] then return end
    if propertiesInfos[selectedProperty].flags.removable then
        sim.removeProperty(target, selectedProperty)
    end
end

function createUi()
    if not ui then
        local pos = 'position="-30,160" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        xml = '<ui title="Property Explorer" activate="false" closeable="true" on-close="onCloseClicked" resizable="true" ' .. pos .. '>'
        xml = xml .. '<group flat="true" layout="hbox">'
        xml = xml .. '<label text="Target:" />'
        xml = xml .. '<group flat="true">'
        xml = xml .. '<radiobutton text="App" checked="' .. tostring(target == sim.handle_app) .. '" on-click="setTargetApp" />'
        xml = xml .. '<radiobutton text="Selection (obj/scene)" checked="' .. tostring(target ~= sim.handle_app) .. '" on-click="setTargetSel" />'
        xml = xml .. '</group>'
        xml = xml .. '</group>'
        xml = xml .. '<group flat="true" layout="hbox">'
        xml = xml .. '<label text="Selected target:" />'
        xml = xml .. '<combobox id="${ui_combo_selection}" on-change="onSubTargetChanged">'
        xml = xml .. '</combobox>'
        xml = xml .. '</group>'
        xml = xml .. '<group flat="true" layout="hbox">'
        xml = xml .. '<label text="Filter:" />'
        xml = xml .. '<edit id="${ui_filter}" value="' .. filterMatching .. '" on-change="updateFilter" />'
        xml = xml .. '<checkbox id="${ui_filter_invert}" text="Invert" checked="' .. tostring(filterInvert) .. '" on-change="updateFilter" />'
        xml = xml .. '</group>'
        xml = xml .. '<properties id="${ui_table}" on-selection-change="onRowSelected" on-double-click="onRowDoubleClicked" on-key-press="onKeyPress">'
        xml = xml .. '</properties>'
        xml = xml .. '<group flat="true" layout="hbox" content-margins="0,0,0,0">'
        xml = xml .. '<button id="${ui_assign}" enabled="false" text="Assign" on-click="assignValue" />'
        xml = xml .. '<button id="${ui_edit}" visible="false" text="Edit..." on-click="editValue" />'
        xml = xml .. '<button id="${ui_remove}" visible="false" text="Remove" on-click="removeSelected" />'
        xml = xml .. '</group>'
        xml = xml .. '</ui>'
        ui = simUI.create(xml)
    end
end

function destroyUi()
    if ui then
        uiPos = {}
        uiPos[1], uiPos[2] = simUI.getPosition(ui)
        simUI.destroy(ui)
        ui = nil
    end
end
