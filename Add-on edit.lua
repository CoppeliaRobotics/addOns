sim = require 'sim'

function closeUi()
    leaveNow = true
end

function edit()
    index = simUI.getComboboxSelectedIndex(ui, ui_combo)
    selectedAddon = addons[index + 1]

    dummy = sim.createDummy(0.01)
    sim.setObjectAlias(dummy, selectedAddon.name)
    sim.setObjectInt32Param(dummy, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(dummy, sim.objintparam_manipulation_permissions, 0)
    script = sim.addScript(sim.scripttype_customizationscript)
    local file = assert(io.open(selectedAddon.path, 'r'))
    local code = file:read('*a')
    file:close()
    sim.setScriptStringParam(script, sim.scriptstringparam_text, code)
    sim.associateScriptWithObject(script, dummy)

    simUI.setEnabled(ui, ui_combo, false)
    simUI.setEnabled(ui, ui_btnEdit, false)
    simUI.setEnabled(ui, ui_btnSave, true)
end

function save()
    local f = io.open(selectedAddon.path, 'w')
    f:write(sim.getScriptStringParam(script, sim.scriptstringparam_text))
    f:close()
    sim.removeObjects {dummy}
    leaveNow = true
end

function sysCall_info()
    return {autoStart = false, menu = 'Developer tools\nAdd-on edit...'}
end

function sysCall_init()
    simUI = require 'simUI'
    lfs = require 'lfs'

    addonDir = sim.getStringParam(sim.stringparam_addondir)

    addons = {}
    for f in lfs.dir(addonDir) do
        local mode = lfs.attributes(addonDir .. '/' .. f, 'mode')
        if mode == 'file' and string.startswith(f, 'simAddOn') and string.endswith(f, '.lua') then
            local addon = {
                basename = f,
                path = addonDir .. '/' .. f,
                name = string.gsub(f, '^simAddOn(.*)%.lua$', '%1'),
            }
            table.insert(addons, addon)
        end
    end
    table.sort(addons, function(a, b) return a.name < b.name end)

    local addonsCbItems = ''
    for _, x in ipairs(addons) do
        addonsCbItems = addonsCbItems .. '<item>' .. x.name .. '</item>\n'
    end

    ui = simUI.create([[<ui title="Add-on editor" closeable="true" on-close="closeUi" resizable="false">
        <label text="Select an add-on to edit and click Edit; it will be loaded into a customization script. When finished, click Save to save it back to the original add-on script file." wordwrap="true" />
        <combobox id="${ui_combo}">]] .. addonsCbItems .. [[</combobox>
        <button id="${ui_btnEdit}" text="Edit" on-click="edit" />
        <button id="${ui_btnSave}" text="Save" on-click="save" enabled="false" />
    </ui>]])
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end
