local sim
local simUI

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nCreate cylinder/capsule(s) at points...'}
end

function sysCall_init()
    sim = require 'sim-2'
    simUI = require 'simUI'

    if #sim.scene.selection < 2 then
        simUI.msgBox(simUI.msgbox_type.info, simUI.msgbox_buttons.ok, sim.self.addOnMenuPath, 'At least 2 objects must be selected.')
        return {cmd = 'cleanup'}
    end

    ui = simUI.create([[
        <ui title="]] .. sim.self.addOnMenuPath .. [[" closeable="true" on-close="onClose" resizable="true" modal="true" layout="grid">
            <label id="10" text="Shape:" />
            <group id="11" flat="true" content-margins="0,0,0,0" layout="hbox">
                <radiobutton id="12" text="cylinder" checked="true" on-click="updateUi" />
                <radiobutton id="13" text="capsule" checked="false" on-click="updateUi" />
                <checkbox id="14" text="tangent" enabled="false" checked="false" />
            </group>
            <br/>
            <label id="20" text="Diameter:" />
            <spinbox id="21" float="true" minimum="0.0001" maximum="1000.0000" step="0.0001" value="0.01" decimals="6" suffix=" [m]" />
            <br/>
            <label id="30" text="" />
            <checkbox id="31" text="Group shapes" checked="true" />
            <br/>
            <label id="40" text="" />
            <checkbox id="41" text="Dynamic shape" checked="true" />
            <br/>
            <label id="50" text="" />
            <checkbox id="51" text="Respondable shape" checked="true" />
            <br/>
            <label id="60" text="" />
            <button id="61" on-click="execute" text="Create" />
        </ui>
    ]])
end

function onClose()
    leaveNow = true
end

function updateUi()
    simUI.setEnabled(ui, 14, simUI.getRadiobuttonValue(ui, 13) > 0)
end

function execute()
    local cylinder = simUI.getRadiobuttonValue(ui, 12)
    local capsule = simUI.getRadiobuttonValue(ui, 13)
    local tangent = simUI.getCheckboxValue(ui, 14) > 0
    local diameter = simUI.getSpinboxValue(ui, 21)
    local groupShapes = simUI.getCheckboxValue(ui, 31) > 0
    local dynamicShape = simUI.getCheckboxValue(ui, 41) > 0
    local respondableShape = simUI.getCheckboxValue(ui, 51) > 0
    local shapeutils = require 'sim.shapeutils'
    local shapes = {}
    local createFunc, opts
    if cylinder then
        createFunc = shapeutils.createCylinderAtPoints
    end
    if capsule then
        createFunc = shapeutils.createCapsuleAtPoints
        opts = {alt = tangent}
    end
    for i = 2, #sim.scene.selection do
        local shape = createFunc(
            sim.scene.selection[i - 1].position,
            sim.scene.selection[i].position,
            diameter,
            opts
        )
        table.insert(shapes, shape)
    end
    if #shapes > 1 and groupShapes then
        shapes = {sim.scene:groupShapes(shapes)}
    end
    for i, shape in ipairs(shapes) do
        shape = sim.Object:toobject(shape) -- shapeutils returns numeric handle
        shape.dynamic = dynamicShape
        shape.respondable = respondableShape
    end
    leaveNow = true
end

function sysCall_nonSimulation()
    if leaveNow then
        if ui then
            local simUI = require 'simUI'
            simUI.destroy(ui)
            ui = nil
        end
        return {cmd = 'cleanup'}
    end
end
