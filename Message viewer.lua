sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nMessage viewer'}
end

function sysCall_init()
    consoleHandle = sim.auxiliaryConsoleOpen('Broadcast message viewer', 500, 16)
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    sim.auxiliaryConsoleClose(consoleHandle)
end

function sysCall_msg(event)
    sim.auxiliaryConsolePrint(consoleHandle, _S.tableToString(event, {}, 99) .. '\n')
end
