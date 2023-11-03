sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nDistribute objects uniformly'}
end

function sysCall_init()
    local sel = sim.getObjectSel()
    if #sel < 3 then
        simUI = require 'simUI'
        simUI.msgBox(
            simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'Distribute objects uniformly add-on',
            'This tool requires at least 3 shapes to be selected.'
        )
    else
        local min, max = nil, nil
        for i, h in ipairs(sel) do
            local p = sim.getObjectPosition(h)
            if i == 1 then
                min, max = table.slice(p), table.slice(p)
            else
                for j = 1, 3 do
                    min[j], max[j] = math.min(min[j], p[j]), math.max(max[j], p[j])
                end
            end
        end
        local d = {}
        for j = 1, 3 do
            d[j] = max[j] - min[j]
        end
        for i, h in ipairs(sel) do
            local p = {}
            for j = 1, 3 do
                p[j] = min[j] + d[j] * (i - 1) / (#sel - 1)
            end
            sim.setObjectPosition(h, p)
        end
    end
    return {cmd = 'cleanup'}
end
