sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nMake objects same appearance'}
end

function sysCall_init()
    local sel = sim.getObjectSel()
    local shapes = filter(function(h) return sim.getObjectType(h) == sim.sceneobject_shape end, sel)
    if #shapes < 2 then
        simUI = require 'simUI'
        simUI.msgBox(
            simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Make objects same appearance add-on',
            'Not enough shapes selected selected.'
        )
    else
        for i, h in ipairs(shapes) do
            if i > 1 then
                sim.setShapeAppearance(h, sim.getShapeAppearance(shapes[1]))
            end
        end
    end
    return {cmd = 'cleanup'}
end
