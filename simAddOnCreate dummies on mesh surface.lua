sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Geometry / Mesh\nCreate dummies on mesh surface'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    dummySize = 0.02
    dummyColor = {0, 1, 0}
    alias = 'Dummy'
    zOffset = 0
    sim.addLog(
        sim.verbosity_scriptinfos,
        "This tool allows to create dummies from points sampled on mesh surfaces"
    )
    showDlg()
    sim.broadcastMsg {
        id = 'pointSampler.enable',
        data = {key = 'createDummiesOnMeshSurf', surfacePoint = true, surfaceNormal = true},
    }
end

function sysCall_msg(event)
    if not event.data or not event.data.key or event.data.key ~= 'createDummiesOnMeshSurf' then
        return
    end
    if event.id == 'pointSampler.click' then
        if event.data.pointNormalMatrix then
            createDummy(event.data.pointNormalMatrix)
            sim.announceSceneContentChange()
        end
    end
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_afterSimulation()
    showDlg()
end

function sysCall_cleanup()
    sim.broadcastMsg {id = 'pointSampler.disable', data = {key = 'createDummiesOnMeshSurf'}}
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function sysCall_afterInstanceSwitch()
    showDlg()
end

function clearTextInfo()
end

function createDummy(m)
    local h = sim.createDummy(dummySize)
    sim.setObjectColor(h, 0, sim.colorcomponent_ambient_diffuse, dummyColor)
    sim.setObjectMatrix(h, m, sim.handle_world)
    sim.setObjectPose(h, {0, 0, zOffset, 0, 0, 0, 1}, h)
    sim.setObjectAlias(h, alias)
end

function showDlg()
    if not ui then
        local pos = 'position="-50,150" placement="relative"'
        if uiPos then
            pos = 'position="' .. uiPos[1] .. ',' .. uiPos[2] .. '" placement="absolute"'
        end
        local xml = [[<ui title="Create dummies on mesh surface" layout="form" activate="false" closeable="true" resizable="true" on-close="close_callback" ]] ..  pos .. [[>
            <label id="9" text="" />
            <checkbox id="10" text="Constrain to vertices" on-change="changedConstrain" />
            <label id="11" text="Size:" />
            <spinbox id="12" value="]] .. dummySize .. [[" step="0.001" decimals="3" suffix="m" on-change="changedDummySize" />
            <label id="13" text="Color:" />
            <edit id="14" value="]] .. table.join(dummyColor) .. [[" on-editing-finished="changedColor" />
            <label id="5" text="Alias:" />
            <edit id="6" value="]] .. alias .. [[" on-editing-finished="changedAlias" />
            <label id="7" text="Offset:" />
            <spinbox id="8" value="]] .. zOffset .. [[" step="0.001" suffix="m" on-change="changedZOffset" />
        </ui>]]
        ui = simUI.create(xml)
    end
end

function hideDlg()
    if ui then
        uiPos = {}
        uiPos[1], uiPos[2] = simUI.getPosition(ui)
        simUI.destroy(ui)
        ui = nil
    end
end

function changedConstrain(ui, id, val)
    local constrainToVerticesNew = val > 0
    if constrainToVertices ~= constrainToVerticesNew then
        constrainToVertices = constrainToVerticesNew
        sim.broadcastMsg {id = 'pointSampler.disable', data = {key = 'createDummiesOnMeshSurf'}}
        sim.broadcastMsg {
            id = 'pointSampler.enable',
            data = {
                key = 'createDummiesOnMeshSurf',
                surfacePoint = not constrainToVertices,
                vertex = not not constrainToVertices,
                surfaceNormal = true
            },
        }
    end
end

function changedDummySize(ui, id, val)
    dummySize = val
end

function changedColor(ui, id, val)
    local s = string.split(simUI.getEditValue(ui, 14), ',')
    if #s == 3 then
        local valid = true
        for i = 1, 3 do
            s[i] = tonumber(s[i])
            if s[i] == nil then
                valid = false
            end
        end
        if valid then
            dummyColor = s
        end
    end
    simUI.setEditValue(ui, 14, table.join(dummyColor))
end

function changedAlias(ui, id, val)
    alias = val
end

function changedZOffset(ui, id, val)
    zOffset = val
end

function close_callback()
    leaveNow = true
end
