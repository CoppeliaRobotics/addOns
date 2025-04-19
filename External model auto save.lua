sim = require 'sim'
extModel = require 'addOns.extModel'

function sysCall_info()
    return {
        menu = 'Developer tools\nExternal model auto save',
    }
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
end

function sysCall_beforeSave(inData)
    if inData.regularSave then
        extModel.scanForExtModelsToSave()
    end
end

require('addOns.autoStart').setup{ns = 'extModelAutoSave', readNamedParam = false}
