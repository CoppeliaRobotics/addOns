sim = require 'sim'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nDefine joint group...'}
end

function sysCall_init()
    simUI = require 'simUI'

    if sim.getSimulationState() ~= sim.simulation_stopped then return {cmd = 'cleanup'} end

    -- get selection, expand selected models:
    local sel = {}
    for _, handle in ipairs(sim.getObjectSelection()) do
        table.insert(sel, handle)
        if sim.getModelProperty(handle) & sim.modelproperty_not_model == 0 then
            for _, handle1 in ipairs(sim.getObjectsInTree(handle, sim.handle_all, 1)) do
                table.insert(sel, handle1)
            end
        end
    end

    -- filter by joints:
    local joints = {}
    for _, handle in ipairs(sel) do
        if sim.getObjectType(handle) == sim.object_joint_type then
            if sim.getJointType(handle) ~= sim.joint_spherical_subtype then
                table.insert(joints, handle)
            end
        end
    end

    -- at least one joint must be selected:
    if #joints < 1 then
        simUI.msgBox(
            simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, 'No joint selected',
            'Error: no joint selected\n\nTo use this add-on, select some joints then execute the add-on.'
        )
        return {cmd = 'cleanup'}
    end

    local name = ''
    while name == '' do
        name = simUI.inputDialog(
                   'JointGroup',
                   'Enter a name for the joint group which will contain the following joints:\n\n' ..
                       table.join(
                           map(
                               function(h)
                            return ' - ' .. sim.getObjectAlias(h, 7)
                        end, table.slice(joints, 1, 10)
                           ), '\n'
                       ) .. (#joints > 10 and string.format('\n (and %d more)', #joints - 10) or '') ..
                       '\n'
               )
    end
    if name == nil then return {cmd = 'cleanup'} end

    local modelHandle = sim.getObject(':', {proxy = joints[#joints]})

    local scriptText = ''
    local function appendLine(...)
        scriptText = scriptText .. string.format(...) .. '\n'
    end

    appendLine("sim=require'sim'")
    appendLine("")
    appendLine("function sysCall_init()")
    appendLine("    self=sim.getObject'.'")
    appendLine("end")
    appendLine("")
    appendLine("function getJoints()")
    appendLine("    return sim.getReferencedHandles(self)")
    appendLine("end")
    appendLine("")
    appendLine("function getConfig()")
    appendLine("    return map(sim.getJointPosition,getJoints())")
    appendLine("end")
    appendLine("")
    appendLine("function setConfig(cfg)")
    appendLine("    foreach(sim.setJointPosition,getJoints(),cfg)")
    appendLine("end")

    local jointGroupDummy = sim.createDummy(0.01)
    sim.setReferencedHandles(jointGroupDummy, joints)
    local script = sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(script, sim.scriptstringparam_text, scriptText)
    sim.associateScriptWithObject(script, jointGroupDummy)
    sim.setObjectAlias(jointGroupDummy, name)
    sim.setObjectParent(jointGroupDummy, modelHandle, false)
    sim.setObjectPose(jointGroupDummy, {0, 0, 0, 0, 0, 0, 1}, modelHandle)
    sim.setObjectInt32Param(jointGroupDummy, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(jointGroupDummy, sim.objintparam_manipulation_permissions, 0)
    sim.writeCustomDataBlock(jointGroupDummy, '__jointGroup__', sim.packInt32Table {1})

    sim.announceSceneContentChange()

    return {cmd = 'cleanup'}
end
