sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nEvent viewer'}
end

function sysCall_init()
    cbor = require 'org.conman.cbor'
    sim.test('sim.enableEvents', true)
    sim.test('sim.mergeEvents', true)
    sim.test('sim.cborEvents', true)
    consoleHandle = sim.auxiliaryConsoleOpen('Event viewer', 500, 16)
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    sim.auxiliaryConsoleClose(consoleHandle)
end

function sysCall_event(event)
    event = cbor.decode(event)
    sim.auxiliaryConsolePrint(consoleHandle, _S.tableToString(event, {}, 99) .. '\n')
end
