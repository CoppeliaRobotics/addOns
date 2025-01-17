sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nEvent viewer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    cbor.NULL_VALUE = setmetatable({}, {__tostring = function() return 'null' end})
    cbor.SIMPLE[22] = function(pos) return cbor.NULL_VALUE, pos, 'null' end

    simUI = require 'simUI'
    ui = simUI.create [[<ui title="Event viewer" position="-400,100" size="640,220" placement="relative" closeable="true" resizable="true" on-close="onClose">
        <group layout="hbox">
            <checkbox id="${ui_chkFilter}" text="" on-change="onFilterChanged" />
            <label text="Filter:" />
            <edit id="${ui_txtFilter}" value="e.event ~= 'logMsg' and e.event ~= 'msgDispatchTime'" enabled="false" on-change="onFilterChanged" />
        </group>
        <text-browser id="${ui_txtLog}" type="plain" word-wrap="false" read-only="false" style="QTextBrowser { font-family: Courier New; }" />
    </ui>]]
    onFilterChanged()

    sep = ''
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_event(event)
    local txt = ''
    for _, e in ipairs(cbor.decode(tostring(event))) do
        if testFilter(e) then
            local s = _S.tableToString(e, {indent = true}, 99)
            txt = txt .. sep .. s .. ','
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

function testFilter(e)
    if not filterEnabled then return true end
    if not filterFunc then return false end
    local ok, ret = pcall(filterFunc(), e)
    if not ok then return false end
    return ret
end

function onFilterChanged()
    filterEnabled = simUI.getCheckboxValue(ui, ui_chkFilter) > 0
    simUI.setEnabled(ui, ui_txtFilter, filterEnabled)
    filterFunc = loadstring('return function(e) return ' .. simUI.getEditValue(ui, ui_txtFilter) .. ' end')
    simUI.setStyleSheet(ui, ui_txtFilter, filterFunc and '' or 'border: 1px solid red')
end

function onClose()
    leaveNow = true
end
