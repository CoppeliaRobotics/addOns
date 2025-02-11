sim = require 'sim'

function sysCall_info()
    return {autoStart = sim.getNamedBoolParam('propertyExplorer.autoStart') == true, menu = 'Developer tools\nProperty explorer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    simUI = require 'simUI'

    target = sim.handle_scene
    selectedProperty = ''
    filterMatching = '*'
    filterInvert = false

    uiPos = sim.getTableProperty(sim.handle_app, 'customData.propertyExplorer.uiPos', {noError=true})
    uiSize = sim.getTableProperty(sim.handle_app, 'customData.propertyExplorer.uiSize', {noError=true})
    uiPropsState = sim.getBufferProperty(sim.handle_app, 'customData.propertyExplorer.uiPropsState', {noError=true})
    uiCollapseProps = sim.getTableProperty(sim.handle_app, 'customData.propertyExplorer.uiCollapseProps', {noError=true}) or {}
    uiTargetRadio = sim.getIntProperty(sim.handle_app, 'customData.propertyExplorer.uiTargetRadio', {noError=true}) or 1

    if uiTargetRadio == 1 then target = sim.handle_app end

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
    if leaveNow then return {cmd = 'cleanup'} end
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

            if pcall(readTargetProperties) then
                if not table.eq(oldPropertiesNames, propertiesNames) then
                    -- some property was added or removed
                    onTargetChanged()
                else
                    for pname, pvalue in pairs(table.flatten(e.data)) do
                        local i = propertyNameToIndex[pname]
                        if i then updateTableRow(i, true) end
                    end
                end
            elseif target ~= sim.handle_app then
                -- readTargetProperties failed: maybe target was removed. switch to scene:
                target = sim.handle_scene
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

    local fpn = filteredPropertiesNames
    filteredPropertiesNames = {}
    local lastPClass = nil
    local prefix = ''
    for _, pname in ipairs(fpn) do
        -- insert header at class break:
        local pclass = propertiesInfos[pname].class
        if pclass ~= lastPClass then
            table.insert(filteredPropertiesNames, {'', '#' .. pclass, ''})
            lastPClass = pclass
        end

        -- check for prefix, add header & strip prefix from names:
        local pnamea = string.split(pname, '%.')
        if #pnamea > 1 then
            local newPrefix = table.join(table.slice(pnamea, 1, #pnamea - 1), '.') .. '.'
            if newPrefix ~= prefix then
                table.insert(filteredPropertiesNames, {newPrefix, '.'})
            end
            prefix = newPrefix
        else
            prefix = ''
        end

        if not uiCollapseProps[prefix] then
            table.insert(filteredPropertiesNames, {prefix, pname})
        end
    end

    -- optimization to avoid repopulation of whole table:
    propertyNameToIndex = {}
    for i, pn in ipairs(filteredPropertiesNames) do propertyNameToIndex[pn[2]] = i end
end

function updateTableRow(i, updateSingle)
    assert(filteredPropertiesNames[i])
    local prefix = filteredPropertiesNames[i][1]
    local pname = filteredPropertiesNames[i][2]

    if pname:sub(1, 1) == '#' then
        -- class group header
        tableRows.pname[i] = ''
        tableRows.ptype[i] = ''
        tableRows.pvalue[i] = ''
        tableRows.pflags[i] = -1
        tableRows.pdisplayk[i] = '[' .. pname:sub(2) .. ']'
        tableRows.pdisplayv[i] = ''
    elseif pname == '.' then
        -- prefix group header
        tableRows.pname[i] = ''
        tableRows.ptype[i] = '{...}'
        tableRows.pvalue[i] = ''
        tableRows.pflags[i] = -2
        tableRows.pdisplayk[i] = ' ' .. (uiCollapseProps[prefix] and '+' or '-') .. ' ' .. prefix .. ''
        tableRows.pdisplayv[i] = ''
    else
        -- normal row
        local flags = propertiesInfos[pname].flags
        tableRows.pname[i] = pname
        tableRows.ptype[i] = string.gsub(sim.getPropertyTypeString(propertiesInfos[pname].type), 'array$', '[]')
        tableRows.pvalue[i] = sim.convertPropertyValue(propertiesValues[pname], propertiesInfos[pname].type, sim.propertytype_string)
        if tableRows.pvalue[i] == nil then tableRows.pvalue[i] = '' end
        tableRows.pflags[i] = flags.value
        tableRows.pdisplayk[i] = '    ' .. (#prefix > 0 and '    ' or '') .. pname:sub(#prefix + 1)
        if flags.large then
            tableRows.pdisplayv[i] = '<big data>'
        elseif not flags.readable then
            tableRows.pdisplayv[i] = flags.writable and '<write-only>' or '<not readable>'
        else
            tableRows.pdisplayv[i] = _S.anyToString(propertiesValues[pname])
            if #tableRows.pdisplayv[i] > 30 then
                tableRows.pdisplayv[i] = tableRows.pdisplayv[i]:sub(1, 30) .. '...'
            end
        end
    end

    if updateSingle then
        simUI.setPropertiesRow(ui, ui_table, i - 1, tableRows.pname[i], tableRows.ptype[i], tableRows.pvalue[i], tableRows.pflags[i], tableRows.pdisplayk[i], tableRows.pdisplayv[i])
    end
end

function onTargetChanged()
    readTargetProperties()
    comboLabels, comboHandles = {}, {}
    local comboIdx = 0
    sim.setIntProperty(sim.handle_app, 'customData.propertyExplorer.uiTargetRadio', target == sim.handle_app and 1 or 2)
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
    tableRows = {pname = {}, ptype = {}, pvalue = {}, pflags = {}, pdisplayk = {}, pdisplayv = {}}
    for i, pprefixAndName in ipairs(filteredPropertiesNames) do
        local prefix, pname = table.unpack(pprefixAndName)
        if selectedProperty == pname and selectedPropertyPrefix == prefix then
            selectedRow = i
        end
        updateTableRow(i)
    end
    simUI.setProperties(ui, ui_table, tableRows.pname, tableRows.ptype, tableRows.pvalue, tableRows.pflags, tableRows.pdisplayk, tableRows.pdisplayv)
    if selectedRow ~= -1 then
        simUI.setPropertiesSelection(ui, ui_table, selectedRow - 1, false)
    end
    updateContextMenuForSelectedProperty()
end

function updateContextMenuForSelectedProperty()
    canAssign = false
    canEdit = false
    canRemove = false
    contextMenuKeys, contextMenuTitles = {}, {}
    local function addContextMenu(key, title)
        table.insert(contextMenuKeys, key)
        table.insert(contextMenuTitles, title)
    end
    if selectedProperty and propertiesInfos[selectedProperty] and selectedProperty:sub(1, 1) ~= '#' then
        local f = propertiesInfos[selectedProperty].flags
        canAssign = f.readable
        canEdit = f.readable and f.writable
        canRemove = f.removable
        if propertiesInfos[selectedProperty].label ~= '' then
            addContextMenu('#', propertiesInfos[selectedProperty].label)
            addContextMenu('--', '')
        end
        addContextMenu('#', 'Name:')
        addContextMenu('copy', 'Copy name to clipboard')
        if propertiesInfos[selectedProperty].descr ~= '' then
            addContextMenu('printDescr', 'Print description to console')
        end
        addContextMenu('--', '')
        addContextMenu('#', 'Value:')
        if canAssign then
            addContextMenu('copyValue', 'Copy value to clipboard')
            addContextMenu('copyGetter', 'Copy get code to clipboard')
            addContextMenu('copySetter', 'Copy set code to clipboard')
            addContextMenu('assign', 'Assign value to variable')
        end
        if canEdit then
            addContextMenu('editInCodeEditor', 'Edit in code editor...')
        end
        if canRemove then
            addContextMenu('--', '')
            addContextMenu('remove', 'Remove property')
        end
    elseif selectedProperty == '.' then
        addContextMenu('removeall', 'Remove all in this group')
    end
    simUI.setPropertiesContextMenu(ui, ui_table, contextMenuKeys, contextMenuTitles)
end

function onPropertyContextMenuTriggered(ui, id, key)
    _G['onContextMenu_' .. key]()
end

function onContextMenu_printDescr()
    print(propertiesInfos[selectedProperty].descr)
end

function onContextMenu_assign()
    assignValue()
end

function onContextMenu_print()
    print('not implemented yet')
end

function onContextMenu_copy()
    simUI.setClipboardText(selectedProperty)
end

function onContextMenu_copyValue()
    local pvalue = sim.getProperty(target, selectedProperty)
    pvalue = sim.convertPropertyValue(pvalue, propertiesInfos[selectedProperty].type, sim.propertytype_string)
    simUI.setClipboardText(pvalue)
end

function gen_getObject(handle)
    if sim.isHandle(target) then
        return 'sim.getObject \'' .. sim.getObjectAlias(target, 1) .. '\''
    elseif target == sim.handle_scene then
        return 'sim.handle_scene'
    elseif target == sim.handle_app then
        return 'sim.handle_app'
    else
        return tostring(target)
    end
end

function onContextMenu_copyGetter()
    local targetStr = gen_getObject(target)
    local code = 'sim.getProperty(' .. targetStr .. ', \'' .. selectedProperty .. '\')'
    simUI.setClipboardText(code)
end

function onContextMenu_copySetter()
    local targetStr = gen_getObject(target)
    local valueStr = _S.anyToString(sim.getProperty(target, selectedProperty))
    local code = 'sim.setProperty(' .. targetStr .. ', \'' .. selectedProperty .. '\', ' .. valueStr .. ')'
    simUI.setClipboardText(code)
end

function onContextMenu_editInCodeEditor()
    propertiesValues[selectedProperty] = sim.getProperty(target, selectedProperty)
    initialEditorContent = sim.convertPropertyValue(propertiesValues[selectedProperty], propertiesInfos[selectedProperty].type, sim.propertytype_string)
    local sz = 2 * math.min(500, #initialEditorContent)
    local w = math.max(200, math.min(800, 60 * math.log(sz) + 85.21))
    local h = math.max(40, math.min(1200, 50 * math.pow(sz, 0.353)))
    editorHandle = sim.textEditorOpen(initialEditorContent, '<editor title="' .. (propertiesInfos[selectedProperty].flags.writable and 'Edit' or 'View') .. ' &quot;' .. selectedProperty .. '&quot; value" editable="' .. _S.anyToString(propertiesInfos[selectedProperty].flags.writable) .. '" searchable="true" tab-width="4" toolbar="false" statusbar="false" resizable="true" modal="true" on-close="editValueFinished" closeable="true" size="' .. math.floor(w) .. ' ' .. math.floor(h) .. '" placement="center" activate="true" line-numbers="false"></editor>')
end

function editValueFinished()
    if editorHandle then
        local newValue, err = sim.textEditorGetInfo(editorHandle), nil
        if newValue ~= initialEditorContent then
            newValue, err = sim.convertPropertyValue(newValue, sim.propertytype_string, propertiesInfos[selectedProperty].type)
            if err then
                simUI.msgBox(simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Error', 'Failed to convert value: ' .. err)
            elseif propertiesInfos[selectedProperty].flags.writable then
                if propertiesInfos[selectedProperty].type == sim.propertytype_color then
                    sim.setColorProperty(target, selectedProperty, newValue)
                else
                    sim.setProperty(target, selectedProperty, newValue)
                end
            end
        end
        sim.textEditorClose(editorHandle)
        initialEditorContent = nil
        editorHandle = nil
    end
end

function onContextMenu_remove()
    removeSelected()
end

function onContextMenu_removeall()
    if selectedProperty == '.' then
        for pname, pvalue in pairs(sim.getProperties(target)) do
            if string.startswith(pname, selectedPropertyPrefix) and propertiesInfos[pname].flags.removable then
                sim.removeProperty(target, pname)
            end
        end
    end
end

function onRowSelected(ui, id, row)
    if row == -1 then
        selectedPropertyPrefix, selectedProperty = nil, nil
    else
        selectedPropertyPrefix, selectedProperty = table.unpack(filteredPropertiesNames[row + 1])
    end
    selectedRow = row
    updateContextMenuForSelectedProperty()
end

function onRowDoubleClicked(ui, id, row, col)
    if selectedProperty == '.' then -- it is a group
        -- toggle collapse
        if uiCollapseProps[selectedPropertyPrefix] then
            uiCollapseProps[selectedPropertyPrefix] = nil
        else
            uiCollapseProps[selectedPropertyPrefix] = true
        end
        sim.setTableProperty(sim.handle_app, 'customData.propertyExplorer.uiCollapseProps', uiCollapseProps)
        onTargetChanged()
        return
    end

    if canAssign then assignValue() end
end

function onPropertyEdit(ui, id, key, value)
    local newValue, err = sim.convertPropertyValue(value, sim.propertytype_string, propertiesInfos[key].type)
    if err then
        simUI.msgBox(simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Error', 'Failed to convert value: ' .. err)
    elseif propertiesInfos[selectedProperty].flags.writable then
        if propertiesInfos[selectedProperty].type == sim.propertytype_color then
            sim.setColorProperty(target, selectedProperty, newValue)
        else
            sim.setProperty(target, selectedProperty, newValue)
        end
    end
end

function onClose()
    if selectedRow >= 0 then
        simUI.setPropertiesSelection(ui, ui_table, -1, false)
    else
        leaveNow = true
    end
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
    local code = string.format('value = sim.getProperty(%d, \'%s\')', target, selectedProperty)
    print('> ' .. code)
    if pcall(sim.executeScriptString, code .. '@lua', sim.getScript(sim.scripttype_sandbox)) then
        if propertiesInfos[selectedProperty].flags.large then
            print('-- (large data)')
        else
            print(pvalue)
        end
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
        local pos, sz = 'position="-30,160" placement="relative"', ''
        if uiPos then
            pos = ' position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        if uiSize then
            sz = ' size="' .. uiSize[1] .. ',' .. uiSize[2] .. '"'
        end
        xml = '<ui title="Property Explorer" activate="false" closeable="true" on-close="onClose" resizable="true"' .. pos .. sz .. '>'
        xml = xml .. '<group flat="true" layout="hbox">'
        xml = xml .. '<radiobutton text="App" checked="' .. tostring(target == sim.handle_app) .. '" on-click="setTargetApp" />'
        xml = xml .. '<radiobutton text="Sel:" checked="' .. tostring(target ~= sim.handle_app) .. '" on-click="setTargetSel" />'
        xml = xml .. '<combobox id="${ui_combo_selection}" on-change="onSubTargetChanged">'
        xml = xml .. '</combobox>'
        xml = xml .. '</group>'
        xml = xml .. '<group flat="true" layout="hbox">'
        xml = xml .. '<label text="Filter:" />'
        xml = xml .. '<edit id="${ui_filter}" value="' .. filterMatching .. '" on-change="updateFilter" />'
        xml = xml .. '<checkbox id="${ui_filter_invert}" text="Invert" checked="' .. tostring(filterInvert) .. '" on-change="updateFilter" />'
        xml = xml .. '</group>'
        xml = xml .. '<properties id="${ui_table}" on-selection-change="onRowSelected" on-double-click="onRowDoubleClicked" on-property-edit="onPropertyEdit" on-context-menu-triggered="onPropertyContextMenuTriggered">'
        xml = xml .. '</properties>'
        xml = xml .. '</ui>'
        ui = simUI.create(xml)
        if uiPropsState then
            simUI.setPropertiesState(ui, ui_table, uiPropsState)
        end
    end
end

function destroyUi()
    if ui then
        uiPos = {simUI.getPosition(ui)}
        uiSize = {simUI.getSize(ui)}
        uiPropsState = simUI.getPropertiesState(ui, ui_table)
        sim.setTableProperty(sim.handle_app, 'customData.propertyExplorer.uiPos', uiPos)
        sim.setTableProperty(sim.handle_app, 'customData.propertyExplorer.uiSize', uiSize)
        sim.setBufferProperty(sim.handle_app, 'customData.propertyExplorer.uiPropsState', uiPropsState)
        simUI.destroy(ui)
        ui = nil
    end
end
