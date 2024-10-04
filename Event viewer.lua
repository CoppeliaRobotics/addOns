sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nEvent viewer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    cbor.NULL_VALUE = setmetatable({}, {__tostring = function() return 'null' end})
    cbor.SIMPLE[22] = function(pos) return cbor.NULL_VALUE, pos, 'null' end

    simUI = require 'simUI'
    ui = simUI.create [[<ui title="Event viewer" position="-400,100" size="640,220" placement="relative" closeable="true" resizable="true" on-close="onClose" content-margins="0,0,0,0">
        <text-browser id="1" type="plain" word-wrap="false" read-only="false" style="QTextBrowser { font-family: Courier New; }" />
    </ui>]]
    sep = ''
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_event(event)
    local txt = ''
    for _, event in ipairs(cbor.decode(tostring(event))) do
        local s = _S.tableToString(event, {indent = true}, 99)
        txt = txt .. sep .. s
        sep = '\n\n'
    end
    simUI.appendText(ui, 1, txt)
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_sensing()
    if leaveNow then return {cmd = 'cleanup'} end
end

function onClose()
    leaveNow = true
end
