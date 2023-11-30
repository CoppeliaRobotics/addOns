sim = require 'sim'

function sysCall_info()
    return {
        autoStart = sim.getNamedBoolParam('referencedHandlesHighlight.autoStart') ~= false,
        menu = 'Misc\nReferences handles highlight',
    }
end

function sysCall_init()
    toRestore = {}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_cleanup()
    restore()
end

function highlight(handle)
    table.insert(
        toRestore,
        {handle = handle, color = sim.getObjectInt32Param(handle, sim.objintparam_hierarchycolor)}
    )
    sim.setObjectInt32Param(handle, sim.objintparam_hierarchycolor, 0)
end

function restore()
    for i, t in ipairs(toRestore) do
        -- pcall because during (model) deletion the handle might be already invalid
        pcall(sim.setObjectInt32Param, t.handle, sim.objintparam_hierarchycolor, t.color)
    end
    toRestore = {}
end

function sysCall_selChange(inData)
    restore()
    if #inData.sel == 1 then
        local rh = sim.getReferencedHandles(inData.sel[1])
        local handles = {}
        for i, h in ipairs(rh) do
            handles[h] = true
        end
        for h in pairs(handles) do
            pcall(highlight, h) -- referenced handle might be invalid
        end
    end
end

function sysCall_beforeSave()
    restore()
end

function sysCall_afterSave()
    sysCall_selChange {sel = sim.getObjectSel()}
end

function sysCall_beforeInstanceSwitch()
    restore()
end

function sysCall_afterInstanceSwitch()
    sysCall_selChange {sel = sim.getObjectSel()}
end
