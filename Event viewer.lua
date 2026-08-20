local sim = require 'sim'
local simUI
local cbor
local fnmatch

function sysCall_info()
    return {menu = 'Developer tools\nEvent viewer'}
end

function sysCall_init()
    cbor = require 'simCBOR'
    cbor.NULL_VALUE = setmetatable({}, {__tostring = function() return 'null' end})
    cbor.SIMPLE[22] = function(pos) return cbor.NULL_VALUE, pos, 'null' end

    simUI = require 'simUI'
    fnmatch = require 'fnmatch'

    createUi()
end

function sysCall_cleanup()
    destroyUi()
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_event(events)
    local txt = ''
    for _, e in ipairs(cbor.decode(events)) do
        local ret = processEvent(e)
        if ret then
            txt = txt .. (sep or '') .. ret .. ','
            sep = '\n\n'
        end
    end
    simUI.appendText(ui, ui_txtLog, txt)
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_sensing()
    if leaveNow then return {cmd = 'cleanup'} end
end

function processEvent(e)
    local function p(n)
        return sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.' .. n, {noError = true})
    end
    if p('excludeLogMsg') and e.event == 'logMsg' then return end
    if p('excludeMsgDispatchTime') and e.event == 'msgDispatchTime' then return end
    local ks = table.keys(e.data)
    table.sort(ks)
    if p('excludeSelectionEvents') and e.event == 'objectChanged' and e.handle == sim.handle_scene and table.eq(ks, {'selection'}) then return end
    if p('excludeSelectionEvents') and e.event == 'objectChanged' and e.handle ~= sim.handle_scene and table.eq(ks, {'selected'}) then return end
    if p('excludeCollapseEvents') and e.event == 'objectChanged' and table.eq(ks, {'collapsed', 'objectPropertyFlags'}) then return end

    if not testFilter(e) then return end

    if filterFieldsEnabled then
        for k in pairs(e.data) do
            if not testFilterField(k) then
                e.data[k] = nil
            end
        end
        
        if filterNonEmptyData and next(e.data) == nil then return end
    end

    return _S.tableToString(e, {indent = true}, 99)
end

function testFilter(e)
    if not filterEnabled then return true end
    if not filterFunc then return false end
    local ok, ret = pcall(filterFunc(), e)
    if not ok then return false end
    return ret
end

function testFilterField(f)
    for _, filterField in ipairs(filterFieldsList) do
        if fnmatch.fnmatch(f, filterField) then
            return true
        end
    end
end

function onFilterChanged()
    for pname, ui_ctrl in pairs {
        filterEnabled = ui_chkFilter,
        excludeLogMsg = ui_chkExcludeLogMsg,
        excludeMsgDispatchTime = ui_chkExcludeMsgDispatchTime,
        excludeSelectionEvents = ui_chkExcludeSelectionEvents,
        excludeCollapseEvents = ui_chkExcludeCollapseEvents,
        stripData = ui_chkStripData,
        filterFieldsEnabled = ui_chkFilterFields,
        filterNonEmptyData = ui_chkFilterNonEmpty,
    } do
        local checkboxValue = simUI.getCheckboxValue(ui, ui_ctrl) > 0
        sim.setBoolProperty(sim.handle_app, 'customData.eventViewer.' .. pname, checkboxValue)
    end

    local filterFuncStr = simUI.getEditValue(ui, ui_txtFilter)
    filterFunc = loadstring('return function(e) return ' .. filterFuncStr .. ' end')
    simUI.setStyleSheet(ui, ui_txtFilter, filterFunc and '' or 'border: 1px solid red')
    sim.setStringProperty(sim.handle_app, 'customData.eventViewer.filterFunc', filterFuncStr)

    filterEnabled = sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.filterEnabled')
    simUI.setEnabled(ui, ui_txtFilter, filterEnabled)

    simUI.setCheckboxValue(ui, ui_chkExclude, (
            sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.excludeLogMsg')
            or sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.excludeMsgDispatchTime')
            or sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.excludeSelectionEvents')
            or sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.excludeCollapseEvents')
        ) and 2 or 0)

    local filterFieldsStr = simUI.getEditValue(ui, ui_txtFilterFields)
    filterFieldsStr = string.trim(filterFieldsStr)
    if filterFieldsStr == '' then
        filterFieldsList = {}
    else
        filterFieldsList = string.split(filterFieldsStr, '[ ,;]+')
    end
    sim.setStringProperty(sim.handle_app, 'customData.eventViewer.filterFields', filterFieldsStr)

    filterFieldsEnabled = sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.filterFieldsEnabled')
    simUI.setEnabled(ui, ui_txtFilterFields, filterFieldsEnabled)
    simUI.setEnabled(ui, ui_chkFilterNonEmpty, filterFieldsEnabled)
    
    filterNonEmptyData = sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.filterNonEmptyData')
end

function onClose()
    sim.setBoolProperty(sim.handle_app, 'customData.eventViewer.autoStart', false)
    leaveNow = true
end

function createUi()
    if not ui then
        local xml_pos = ' position="-400,100" placement="relative"'
        local uiPos = sim.getTableProperty(sim.handle_app, 'customData.eventViewer.uiPos', {noError = true})
        if uiPos then
            xml_pos = ' position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end

        local xml_sz = ' size="640,220"'
        local uiSize = sim.getTableProperty(sim.handle_app, 'customData.eventViewer.uiSize', {noError = true})
        if uiSize then
            xml_sz = ' size="' .. uiSize[1] .. ',' .. uiSize[2] .. '"'
        end

        ui = simUI.create([[<ui title="Event viewer"]] .. xml_pos .. xml_sz .. [[ closeable="true" resizable="true" on-close="onClose">
            <group layout="grid">
                <checkbox id="${ui_chkExclude}" text="" checked="true" enabled="false" />
                <label text="Exclude:" />
                <group layout="hbox" content-margins="0,0,0,0" flat="true">
                    <checkbox id="${ui_chkExcludeLogMsg}" text="logMsg" checked="true" on-change="onFilterChanged" />
                    <checkbox id="${ui_chkExcludeMsgDispatchTime}" text="msgDispatchTime" checked="true" on-change="onFilterChanged" />
                    <checkbox id="${ui_chkExcludeSelectionEvents}" text="selection events" checked="true" on-change="onFilterChanged" />
                    <checkbox id="${ui_chkExcludeCollapseEvents}" text="hierarchy collapse events" checked="true" on-change="onFilterChanged" />
                    <stretch />
                </group>
                <br/>
                <checkbox id="${ui_chkFilter}" text="" on-change="onFilterChanged" />
                <label text="Filter:" />
                <edit id="${ui_txtFilter}" value="e.handle == sim.handle_scene" enabled="false" on-change="onFilterChanged" />
                <br/>
                <checkbox id="${ui_chkFilterFields}" text="" on-change="onFilterChanged" />
                <label text="Filter data fields:" />
                <edit id="${ui_txtFilterFields}" value="parent, children, name" enabled="false" on-change="onFilterChanged" />
                <br/>
                <label text="" />
                <label text="" />
                <checkbox id="${ui_chkFilterNonEmpty}" text="Discard events whose fields filter results in empty data" on-change="onFilterChanged" />
            </group>
            <text-browser id="${ui_txtLog}" type="plain" word-wrap="false" read-only="false" style="QTextBrowser { font-family: Courier New; }" />
        </ui>]])

        for pname, ui_ctrl in pairs {
            filterEnabled = ui_chkFilter,
            excludeLogMsg = ui_chkExcludeLogMsg,
            excludeMsgDispatchTime = ui_chkExcludeMsgDispatchTime,
            excludeSelectionEvents = ui_chkExcludeSelectionEvents,
            excludeCollapseEvents = ui_chkExcludeCollapseEvents,
            filterFieldsEnabled = ui_chkFilterFields,
            filterNonEmptyData = ui_chkFilterNonEmpty,
        } do
            local pvalue = sim.getBoolProperty(sim.handle_app, 'customData.eventViewer.' .. pname, {noError = true})
            if pvalue ~= nil then
                simUI.setCheckboxValue(ui, ui_ctrl, pvalue and 2 or 0)
            end
        end

        for pname, ui_ctrl in pairs {
            filterFunc = ui_txtFilter,
            filterFields = ui_txtFilterFields,
        } do
            local s = sim.getStringProperty(sim.handle_app, 'customData.eventViewer.' .. pname, {noError = true})
            if s ~= nil then
                simUI.setEditValue(ui, ui_ctrl, s)
            end
        end

        onFilterChanged()
    end
end

function destroyUi()
    if ui then
        local uiPos = {simUI.getPosition(ui)}
        local uiSize = {simUI.getSize(ui)}
        sim.setTableProperty(sim.handle_app, 'customData.eventViewer.uiPos', uiPos)
        sim.setTableProperty(sim.handle_app, 'customData.eventViewer.uiSize', uiSize)
        simUI.destroy(ui)
        ui = nil
    end
end

require('addOns.autoStart').setup{ns = 'eventViewer'}
