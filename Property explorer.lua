local sim = require 'sim-2'
local simUI
local cbor

function sysCall_info()
    return {menu = 'Developer tools\nProperty explorer'}
end

function sysCall_init()
    cbor = require 'simCBOR'
    cbor.NULL_VALUE = setmetatable({}, {__tostring = function() return 'null' end})
    cbor.SIMPLE[22] = function(pos) return cbor.NULL_VALUE, pos, 'null' end

    simUI = require 'simUI'

    disableDuringSim = sim.app.customData['propertyExplorer.disableDuringSim']
    if disableDuringSim == nil then
        disableDuringSim = false
        sim.app.customData['propertyExplorer.disableDuringSim'] = disableDuringSim
    end

    target = sim.scene
    selectedProperty = ''
    filterMatching = '*'
    filterInvert = false

    uiPos = sim.app.customData['propertyExplorer.uiPos']
    uiSize = sim.app.customData['propertyExplorer.uiSize']
    uiPropsState = sim.app.customData['propertyExplorer.uiPropsState']
    uiCollapseProps = sim.app.customData['propertyExplorer.uiCollapseProps'] or {}
    uiTargetRadio = sim.app.customData['propertyExplorer.uiTargetRadio'] or 1

    if uiTargetRadio == 1 then target = sim.app end

    createUi()
end

function sysCall_beforeSimulation()
    disableDuringSim = sim.app.customData['propertyExplorer.disableDuringSim'] == true
    if disableDuringSim then
        restoreAfterSimulation = {target = target}
        destroyUi()
    end
end

function sysCall_afterSimulation()
    if restoreAfterSimulation then
        target = restoreAfterSimulation.target
        createUi()
        onTargetChanged()
        restoreAfterSimulation = nil
    end
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    destroyUi()
end

function sysCall_afterInstanceSwitch()
    sysCall_selChange {sel = sim.scene.selection}

    -- force a target change event, otherwise switching scene where the same
    -- handle is selected won't trigger a target change:
    onTargetChanged()
    oldTarget = target
end

function sysCall_suspended()
    if leaveNow then return {cmd = 'cleanup'} end
    checkTargetChanged()
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
    if target == sim.app then
        -- if app selected, object selection won't switch target
        return
    elseif #inData.sel == 0 then
        -- scene if empty selection
        target = sim.scene
    else
        -- otherwise currently selected object
        target = sim.Object:toobject(inData.sel[#inData.sel])
    end
end

function sysCall_event(events)
    if not ui then return end
    if target == nil or propertiesInfos == nil then return end

    if target ~= sim.app and target ~= sim.scene and not sim.isHandle(target.handle) then
        -- target was removed. switch to scene:
        if target ~= sim.app then
            target = sim.scene
            onTargetChanged()
        end
        return
    end

    events = cbor.decode(events)

    local b, plistChanged = false, false
    for _, e in ipairs(events) do
        if e.handle == target.handle and e.event == 'objectChanged' then
            b = true
            for k, v in pairs(e.data) do
                if propertiesInfos[k] == nil and v ~= cbor.NULL_VALUE then
                    plistChanged = true
                elseif propertiesInfos[k] ~= nil and v == cbor.NULL_VALUE then
                    plistChanged = true
                end
            end
        end
    end
    if not b then return end
    if plistChanged then
        -- some property was added or removed
        onTargetChanged()
        return
    end

    local changedRows = {}
    for _, e in ipairs(events) do
        if e.handle == target.handle and e.event == 'objectChanged' then
            for pname, pvalue in pairs(e.data) do
                local i = propertyNameToIndex[pname]
                if i then
                    updateTableRow(i)
                    changedRows[i - 1] = {
                        pname = tableRows.pname[i],
                        ptype = tableRows.ptype[i],
                        pvalue = tableRows.pvalue[i],
                        pflag = tableRows.pflags[i],
                        pdisplayk = tableRows.pdisplayk[i],
                        pdisplayv = tableRows.pdisplayv[i],
                        icon = tableRows.icon[i],
                        description = tableRows.description[i],
                    }
                end
            end
        end
    end

    local changedIndexes = {}
    local pnames = {}
    local ptypes = {}
    local pvalues = {}
    local pflags = {}
    local pdisplayk = {}
    local pdisplayv = {}
    local icons = {}
    local descriptions = {}
    for i, chg in pairs(changedRows) do
        table.insert(changedIndexes, i)
        table.insert(pnames, chg.pname)
        table.insert(ptypes, chg.ptype)
        table.insert(pvalues, chg.pvalue)
        table.insert(pflags, chg.pflag)
        table.insert(pdisplayk, chg.pdisplayk)
        table.insert(pdisplayv, chg.pdisplayv)
        table.insert(icons, chg.icon)
        table.insert(descriptions, chg.description)
    end
    if #changedIndexes > 0 then
        simUI.setPropertiesRows(ui, ui_table, changedIndexes, pnames, ptypes, pvalues, pflags, pdisplayk, pdisplayv, icons, descriptions)
    end
end

function getSubObjects(obj)
    if obj.objectType == 'shape' then
        return obj.meshes
    elseif obj.objectType == 'script' then
        return {obj.detachedScript}
    end
end

function getSuperObject(obj)
    if obj.objectType == 'mesh' then
        return obj.shape
    elseif obj.objectType == 'detachedScript' then
        for _, obj1 in ipairs(sim.scene.objects) do
            if obj1.objectType == 'script' and obj1.detachedScript == obj then
                return obj1
            end
        end
    else
        return nil
    end
end

function checkTargetChanged()
    if target ~= oldTarget then
        onTargetChanged()
        oldTarget = target
    end
end

function setTargetApp()
    target = sim.app
end

function setTargetSel()
    local sel = sim.scene.selection
    if #sel == 0 then
        target = sim.scene
    else
        target = sim.Object:toobject(sel[#sel])
    end
end

function onSubTargetChanged(ui, id, i)
    target = sim.Object:toobject(comboHandles[i + 1])
end

function getFilteringPattern()
    local pat = filterMatching
    pat = string.gsub(pat, '%.', '%%.')
    pat = string.gsub(pat, '%*', '.*')
    pat = '^' .. pat .. '$'
    return pat
end

local CLASS_PRIORITY = {
    object = 1,
    sceneObject = 2,
}

local function classOrder(ca, cb)
    local pa = CLASS_PRIORITY[ca] or 100
    local pb = CLASS_PRIORITY[cb] or 100

    if pa ~= pb then
        return pa < pb
    else
        return ca < cb
    end
end

function propertyOrder(a, b)
    local ca = propertiesInfos[a].class
    local cb = propertiesInfos[b].class

    if ca ~= cb then
        return classOrder(ca, cb)
    else
        return a < b
    end
end

function generateTree(pnames)
    -- 1) insert nodes
    -- 2) generate propertyNameToIndex table

    tableRows = {type = {}, icon = {}, pname = {}, ptype = {}, pvalue = {}, pflags = {}, pdisplayk = {}, pdisplayv = {}, description = {}}

    propertyNameToIndex = {} -- index for single row update

    local function isCollapsed(pa)
        for i = 1, #pa do
            local p = table.join(table.slice(pa, 1, i), '.')
            if uiCollapseProps[p .. '.'] then return true end
        end
    end

    local function indent(i)
        return string.rep('    ', i - 1)
    end

    local lastPClass = nil
    local prefix, prefixa = '', {}
    local newPrefix, newPrefixa
    for _, pname in ipairs(matchingPropertiesNames) do
        local pnamea = string.split(pname, '%.')

        -- insert header at class break:
        local pclass = propertiesInfos[pname].class
        if pclass ~= lastPClass then
            table.insert(tableRows.type, 'classHeader')
            table.insert(tableRows.icon, 0)
            table.insert(tableRows.pname, pclass)
            table.insert(tableRows.pdisplayk, '[' .. pclass .. ']')
            lastPClass = pclass
            propertyNameToIndex[pclass] = #tableRows.pname
        end

        -- check for prefix, add header & strip prefix from names:
        newPrefixa = table.slice(pnamea, 1, #pnamea - 1)
        newPrefix = table.join(newPrefixa, '.') .. '.'
        if newPrefix ~= prefix then
            local m = 0
            while prefixa[m+1] == newPrefixa[m+1] and (prefixa[m+1] or newPrefixa[m+1]) do m = m + 1 end
            for i = m + 1, #newPrefixa do
                local px = table.join(table.slice(newPrefixa, 1, i), '.') .. '.'
                if i <= 1 or not isCollapsed(table.slice(newPrefixa, 1, i - 1)) then
                    table.insert(tableRows.type, 'treeNode')
                    table.insert(tableRows.icon, uiCollapseProps[px] and 2 or 1)
                    table.insert(tableRows.pname, px)
                    table.insert(tableRows.pdisplayk, indent(i) .. newPrefixa[i])
                    propertyNameToIndex[px] = #tableRows.pname
                end
            end
        end
        prefix, prefixa = newPrefix, newPrefixa

        if not isCollapsed(prefixa) then
            table.insert(tableRows.type, 'property')
            table.insert(tableRows.icon, 0)
            table.insert(tableRows.pname, pname)
            table.insert(tableRows.pdisplayk, indent(#pnamea) .. pnamea[#pnamea])
            propertyNameToIndex[pname] = #tableRows.pname
        end
    end
end

function readTargetProperties()
    propertiesValues = sim.getProperties(target, {skipLarge = true})
    propertiesInfos = sim.getPropertiesInfos(target)
    propertiesNames = {}
    matchingPropertiesNames = {}
    local pat = getFilteringPattern()
    local strFindError
    for pname, _ in pairs(propertiesInfos) do
        table.insert(propertiesNames, pname)
        local ok, m = pcall(string.find, pname, pat)
        if ok then
            if (m and not filterInvert) or (not m and filterInvert) then
                table.insert(matchingPropertiesNames, pname)
            end
        else
            strFindError = strFindError or m
        end
    end
    simUI.setStyleSheet(ui, ui_filter, strFindError and 'border: 1px solid red' or '')
    table.sort(propertiesNames, propertyOrder)
    table.sort(matchingPropertiesNames, propertyOrder)
    generateTree(matchingPropertiesNames)
end

function toSimpleString(v, pname)
    if v == nil then return '' end
    local impr = sim.app.customData.propertyExplorer.impr ~= false
    local ptype = propertiesInfos[pname].type
    if ptype == sim.propertytype_handle then
        v = v.handle
    elseif ptype == sim.propertytype_handlearray then
        v = map(function(x) return x.handle end, v)
    elseif table.find({sim.propertytype_color, sim.propertytype_vector3, sim.propertytype_matrix, sim.propertytype_quaternion, sim.propertytype_pose}, ptype) then
        v = v:data()
    elseif impr and pname:endswith 'Time' and (ptype == sim.propertytype_float or ptype == sim.propertytype_int) then
        local seconds = math.floor(v)
        local milliseconds = math.floor((v - seconds) * 1000)
        if seconds > 60 * 60 * 24 then
            v = os.date("%Y-%m-%d %H:%M:%S", seconds) .. string.format(".%03d", milliseconds)
        else
            v = string.format("%02d:%02d:%02d.%03d", seconds // 3600, (seconds // 60) % 60, seconds % 60, milliseconds)
        end
    end
    return _S.anyToString(v, {omitQuotes = true})
end

function updateTableRow(i, updateSingle)
    local pname = tableRows.pname[i]
    if tableRows.type[i] == 'classHeader' then
        -- class group header
        tableRows.ptype[i] = ''
        tableRows.pvalue[i] = ''
        tableRows.pflags[i] = -1
        tableRows.pdisplayv[i] = ''
        tableRows.description[i] = ''
    elseif tableRows.type[i] == 'treeNode' then
        -- prefix group header
        tableRows.ptype[i] = '...'
        tableRows.pvalue[i] = ''
        tableRows.pflags[i] = -2
        local prefixa = string.split(pname, '%.')
        tableRows.pdisplayv[i] = ''
        tableRows.description[i] = ''
    elseif tableRows.type[i] == 'property' then
        -- normal row
        propertiesInfos[pname] = sim.getPropertyInfos(target, pname, {label=true})
        local flags = propertiesInfos[pname].flags
        if flags.readable then
            if not flags.large then
                propertiesValues[pname] = sim.getProperty(target, pname)
            end
        end
        local ptypeStr = sim.getPropertyTypeString(propertiesInfos[pname].type)
        ptypeStr = ptypeStr:gsub('array(%d+)$', '[%1]')
        ptypeStr = ptypeStr:gsub('array$', '[]')
        tableRows.ptype[i] = ptypeStr
        tableRows.pvalue[i] = sim.convertPropertyValue(propertiesValues[pname], propertiesInfos[pname].type, sim.propertytype_string)
        tableRows.description[i] = propertiesInfos[pname].descr or ''
        if tableRows.pvalue[i] == nil then tableRows.pvalue[i] = '' end
        tableRows.pflags[i] = flags.value
        if flags.large then
            tableRows.pdisplayv[i] = '<big data>'
            tableRows.pflags[i] = -3
        elseif flags.silent then
            tableRows.pdisplayv[i] = '<silent>'
            tableRows.pflags[i] = -3
        elseif not flags.readable then
            tableRows.pdisplayv[i] = flags.writable and '<write-only>' or '<not readable>'
            tableRows.pflags[i] = -3
        else
            tableRows.pdisplayv[i] = toSimpleString(propertiesValues[pname], pname)
            tableRows.pdisplayv[i] = string.elide(tableRows.pdisplayv[i], 30, {truncateAtNewLine=true})
        end
    end
    if updateSingle then
        simUI.setPropertiesRow(ui, ui_table, i - 1, tableRows.pname[i], tableRows.ptype[i], tableRows.pvalue[i], tableRows.pflags[i], tableRows.pdisplayk[i], tableRows.pdisplayv[i], tableRows.icon[i], tableRows.description[i])
    end
end

function onTargetChanged()
    readTargetProperties()
    comboLabels, comboHandles = {}, {}
    local comboIdx = 0
    sim.app.customData.propertyExplorer.uiTargetRadio = target == sim.app and 1 or 2
    if target == sim.app then
        table.insert(comboLabels, 'sim.app')
        table.insert(comboHandles, sim.app)
    elseif target == sim.scene then
        table.insert(comboLabels, 'sim.scene')
        table.insert(comboHandles, sim.scene)
    else
        local superTarget = getSuperObject(target) or target
        table.insert(comboLabels, superTarget:getAlias(1))
        table.insert(comboHandles, superTarget)
        local subObjects = getSubObjects(superTarget)
        for i, subObject in ipairs(subObjects or {}) do
            table.insert(comboLabels, '    ' .. subObject.objectType .. ' ' .. i)
            table.insert(comboHandles, subObject.handle)
            if subObject == sim.Object:toobject(target) then comboIdx = i end
        end
    end
    simUI.setComboboxItems(ui, ui_combo_selection, comboLabels, comboIdx)
    simUI.setEnabled(ui, ui_combo_selection, #comboLabels > 1)
    selectedRow = -1
    for i, pname in ipairs(tableRows.pname) do
        if selectedProperty == pname then
            selectedRow = i
        end
        updateTableRow(i)
    end
    simUI.setProperties(ui, ui_table, tableRows.pname, tableRows.ptype, tableRows.pvalue, tableRows.pflags, tableRows.pdisplayk, tableRows.pdisplayv, tableRows.icon, tableRows.description)
    if selectedRow ~= -1 then
        simUI.setPropertiesSelection(ui, ui_table, selectedRow - 1, false)
    end
    updateContextMenuForSelectedProperty()
    sim.setEventFilters{[target] = {}}
end

function updateContextMenuForSelectedProperty()
    canAssign = false
    canEdit = false
    canRemove = false
    contextMenuKeys, contextMenuTitles = {}, {}
    local function addContextMenu(key, title, enabled)
        enabled = enabled ~= false
        table.insert(contextMenuKeys, (enabled and '' or '#') .. key)
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
        addContextMenu('#', '    ' .. selectedProperty)
        addContextMenu('copy', 'Copy name to clipboard')
        addContextMenu('printDescr', 'Print description to console', propertiesInfos[selectedProperty].descr ~= '')
        addContextMenu('--', '')
        addContextMenu('#', 'Value:')
        addContextMenu('copyValue', 'Copy value to clipboard', canAssign)
        addContextMenu('copyGetter', 'Copy get code to clipboard', canAssign)
        addContextMenu('copySetter', 'Copy set code to clipboard', canAssign)
        addContextMenu('assign', 'Assign value to variable', canAssign)
        addContextMenu('editInCodeEditor', 'Edit in code editor...', canEdit)
        addContextMenu('loadValueFromFile', 'Load value from file...', canEdit)
        addContextMenu('saveValueToFile', 'Save value to file...', canAssign)
        addContextMenu('--', '')
        addContextMenu('remove', 'Remove property', canRemove)
    elseif selectedProperty and selectedProperty:endswith '.' then
        local cando = true
        for pname, pinfo in pairs(propertiesInfos) do
            if pname:startswith(selectedProperty) and not pinfo.flags.removable then
                cando = false
                break
            end
        end
        addContextMenu('removeall', 'Remove ' .. selectedProperty .. '*', cando)
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

function gen_getObject(o)
    if o.getAlias ~= nil then
        return 'sim.getObject \'' .. o:getAlias(1) .. '\''
    elseif o == sim.scene then
        return 'sim.handle_scene'
    elseif o == sim.app then
        return 'sim.handle_app'
    else
        return tostring(o.handle)
    end
end

function onContextMenu_copyGetter()
    local targetStr = gen_getObject(target)
    local code = string.format('sim.%s(%s, \'%s\')',
        sim.getPropertyGetter(propertiesInfos[selectedProperty].type, true),
        targetStr, selectedProperty)
    simUI.setClipboardText(code)
end

function onContextMenu_copySetter()
    local targetStr = gen_getObject(target)
    local valueStr = _S.anyToString(sim.getProperty(target, selectedProperty))
    local code = string.format('sim.%s(%s, \'%s\', %s)',
        sim.getPropertySetter(propertiesInfos[selectedProperty].type, true),
        targetStr, selectedProperty, valueStr)
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

function onContextMenu_loadValueFromFile()
    local lfsx = require 'lfsx'
    local sceneDir = lfsx.dirname(sim.scene.scenePath)
    local result = simUI.fileDialog(simUI.filedialog_type.load, 'Load file', sceneDir, '', '', '', true)
    if #result == 1 then
        local file = io.open(result[1], 'r')
        local newValue = file:read('*all')
        file:close()
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
end

function onContextMenu_saveValueToFile()
    propertiesValues[selectedProperty] = sim.getProperty(target, selectedProperty)
    local value = sim.convertPropertyValue(propertiesValues[selectedProperty], propertiesInfos[selectedProperty].type, sim.propertytype_string)
    local lfsx = require 'lfsx'
    local sceneDir = lfsx.dirname(sim.scene.scenePath)
    local result = simUI.fileDialog(simUI.filedialog_type.save, 'Save file', sceneDir, '', '', '', true)
    if #result == 1 then
        local file = io.open(result[1], 'w')
        file:write(value)
        file:close()
        print('Value of "' .. selectedProperty .. '" saved to ' .. result[1])
    end
end

function onContextMenu_remove()
    removeSelected()
end

function onContextMenu_removeall()
    if selectedProperty:endswith('.') then
        for pname, pvalue in pairs(sim.getProperties(target)) do
            if string.startswith(pname, selectedProperty) and propertiesInfos[pname].flags.removable then
                sim.removeProperty(target, pname)
            end
        end
    end
end

function onRowSelected(ui, id, row)
    if row == -1 then
        selectedProperty = nil
    else
        selectedProperty = tableRows.pname[row + 1]
    end
    selectedRow = row
    updateContextMenuForSelectedProperty()
end

function onRowDoubleClicked(ui, id, row, col)
    if string.endswith(selectedProperty, '.') then -- it is a group
        -- toggle collapse
        if uiCollapseProps[selectedProperty] then
            uiCollapseProps[selectedProperty] = nil
        else
            uiCollapseProps[selectedProperty] = true
        end
        sim.app.customData.propertyExplorer.uiCollapseProps = uiCollapseProps
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
        sim.app.customData.propertyExplorer.autoStart = false
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
    local simCmd = require 'simCmd'
    local targetStr = gen_getObject(target)
    local code = string.format('value = sim.getProperty(%s, \'%s\')', targetStr, selectedProperty)
    simCmd.exec('lua', code)
    simCmd.exec('lua', 'value')
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
        xml = xml .. '<group flat="true" layout="hbox" content-margins="0,0,0,0">'
        xml = xml .. '<radiobutton text="App" checked="' .. tostring(target == sim.app) .. '" on-click="setTargetApp" />'
        xml = xml .. '<radiobutton text="Sel:" checked="' .. tostring(target ~= sim.app) .. '" on-click="setTargetSel" />'
        xml = xml .. '<combobox id="${ui_combo_selection}" on-change="onSubTargetChanged" stretch="10">'
        xml = xml .. '</combobox>'
        xml = xml .. '</group>'
        xml = xml .. '<group flat="true" layout="hbox" content-margins="0,0,0,0">'
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
        sim.app.customData.propertyExplorer.uiPos = uiPos
        sim.app.customData.propertyExplorer.uiSize = uiSize
        sim.app.customData.propertyExplorer.uiPropsState = uiPropsState
        simUI.destroy(ui)
        ui = nil
    end
end

require('addOns.autoStart').setup{ns = 'propertyExplorer'}
