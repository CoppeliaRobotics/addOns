local sim = require 'sim-1'

function sysCall_info()
    return {
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
    sim.setObjectInt32Param(handle, sim.objintparam_hierarchycolor, 1)
end

function restore()
    for i, t in ipairs(toRestore) do
        -- pcall because during (model) deletion the handle might be already invalid
        pcall(sim.setObjectInt32Param, t.handle, sim.objintparam_hierarchycolor, t.color)
    end
    toRestore = {}
end

function update()
    sysCall_selChange {sel = sim.getObjectSel()}
end

function sysCall_selChange(inData)
    restore()
    if #inData.sel == 1 then
        local handle = inData.sel[1]
        local tags = sim.getReferencedHandlesTags(handle)
        local refHandles = {}
        local function addHandles(t)
            local rh = sim.getReferencedHandles(handle, t)
            for i, h in ipairs(rh) do
                refHandles[h] = true
            end
        end
        addHandles()
        for _, tag in ipairs(tags) do addHandles(tag) end
        for h in pairs(refHandles) do
            pcall(highlight, h) -- referenced handle might be invalid
        end
    end
end

function sysCall_beforeCopy(inData)
    restore()
end

function sysCall_afterCopy(inData)
    update()
end

function sysCall_beforeSave()
    restore()
end

function sysCall_afterSave()
    update()
end

function sysCall_beforeInstanceSwitch()
    restore()
end

function sysCall_afterInstanceSwitch()
    update()
end

require('addOns.autoStart').setup{ns = 'referencedHandlesHighlight', default = true}
