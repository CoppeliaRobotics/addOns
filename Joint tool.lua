sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nJoint tool'}
end

function sysCall_addOnScriptSuspend()
    return {cmd = 'cleanup'}
end

function sysCall_init()
    simUI = require 'simUI'
    sim.addLog(
        sim.verbosity_scriptinfos,
        "Select a model, a joint group, or individual joints to use the Joint tool."
    )
    sel = {}
    idToJointMap = {}
    jointToIdMap = {}
end

function setJointPos(ui, id, val)
    local h = idToJointMap[id]
    local p = val * math.pi / 180
    sim.setJointPosition(h, p)
    sim.announceSceneContentChange()
end

function closeUi()
    if not ui then return end
    uiPos = table.pack(simUI.getPosition(ui))
    simUI.destroy(ui)
    ui = nil
end

function closeUi_user()
    closeUi()
    leaveNow = true
end

function printConfig()
    local cfg = {}
    for id, jointHandle in pairs(idToJointMap) do
        table.insert(cfg, sim.getJointPosition(jointHandle))
    end
    print(cfg)
end

function sysCall_selChange(inData)
    sel = inData.sel

    -- get selected joints:
    local jointHandles = {}
    for i, objectHandle in ipairs(sel) do
        local dat = sim.readCustomBufferData(objectHandle, '__jointGroup__')
        if dat and #dat > 0 then
            for j, jointHandle in ipairs(sim.getReferencedHandles(objectHandle)) do
                if sim.getObjectType(jointHandle) == sim.sceneobject_joint then
                    table.insert(jointHandles, jointHandle)
                else
                    sim.addLog(
                        sim.verbosity_warnings,
                        'ignoring object referenced by joint group ' ..
                            sim.getObjectAlias(objectHandle, 2) .. ': ' ..
                            sim.getObjectAlias(jointHandle, 2)
                    )
                end
            end
        elseif sim.getModelProperty(objectHandle) & sim.modelproperty_not_model == 0 then
            for j, jointHandle in ipairs(sim.getObjectsInTree(objectHandle, sim.sceneobject_joint)) do
                table.insert(jointHandles, jointHandle)
            end
        elseif sim.getObjectType(objectHandle) == sim.sceneobject_joint then
            table.insert(jointHandles, objectHandle)
        else
            sim.addLog(
                sim.verbosity_warnings,
                'ignoring selected object: ' .. sim.getObjectAlias(objectHandle, 2)
            )
        end
    end

    idToJointMap = {}
    jointToIdMap = {}
    local nid = 1
    closeUi()
    for i, jointHandle in ipairs(jointHandles) do
        local isSpherical = sim.getJointType(jointHandle) == sim.joint_spherical
        local mh, a, b = sim.getJointDependency(jointHandle)
        if not isSpherical and mh == -1 and not jointToIdMap[jointHandle] then
            jointToIdMap[jointHandle] = nid
            idToJointMap[nid] = jointHandle
            nid = nid + 1
        end
    end
    if nid == 1 then return end

    aliasOption = sim.getNamedInt32Param('jointTool.aliasOption') or 9
    local uiPosStr = uiPos and
                         string.format('placement="absolute" position="%d,%d"', table.unpack(uiPos)) or
                         'placement="relative" position="280,500" '
    xml = '<ui closeable="true" ' .. uiPosStr ..
              'resizable="false" on-close="closeUi_user" title="Joint tool" layout="vbox">\n'
    xml = xml .. '  <group flat="true" content-margins="0,0,0,0" layout="form">\n'
    for id, jointHandle in pairs(idToJointMap) do
        local v = sim.getJointPosition(jointHandle) * 180 / math.pi
        local cyclic, i = sim.getJointInterval(jointHandle)
        local vmin, vmax = i[1] * 180 / math.pi, (i[1] + i[2]) * 180 / math.pi
        xml = xml ..
                  string.format(
                      '    <label text="%s" />\n', sim.getObjectAlias(jointHandle, aliasOption)
                  )
        xml = xml .. string.format(
                  '    <group flat="true" content-margins="0,0,0,0" layout="hbox"><spinbox id="%s" value="%f" minimum="%f" maximum="%f" step="0.5" on-change="setJointPos" /><label text="%.1f~%.1f [deg]" enabled="false" /></group>\n',
                  id, v, vmin, vmax, vmin, vmax
              )
    end
    xml = xml .. '  </group>\n'
    xml = xml .. '  <button text="Print current config" on-click="printConfig" />\n'
    xml = xml .. '</ui>'
    ui = simUI.create(xml)
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_cleanup()
    if ui then simUI.destroy(ui) end
end
