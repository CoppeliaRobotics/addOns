sim = require 'sim'

require 'functional'

require 'addOns.jointGroup'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nInverse kinematics generator...'}
end

function sysCall_init()
    simUI = require 'simUI'
    simIK = require 'simIK'
    ui = simUI.create(
             [[<ui title="Inverse Kinematics generator" closeable="true" on-close="onClose" layout="vbox" modal="true">
        <label word-wrap="true" text="This addon generates a script for solving inverse kinematics for the given tip/target/params. The script will be placed in an 'IK' script object child of the robot model. Choose the params below and click 'Generate'." />
        <group flat="true" content-margins="0,0,0,0" layout="form">
            <label text="Robot model:" />
            <combobox id="${ui_comboRobotModel}" on-change="onModelChanged" />
            <label text="Robot base:" />
            <combobox id="${ui_comboRobotBase}" on-change="updateUi" />
            <label text="Robot tip:" />
            <combobox id="${ui_comboRobotTip}" on-change="updateUi" />
            <label text="Robot target:" />
            <combobox id="${ui_comboRobotTarget}" on-change="updateUi" />
            <label text="Joint group:" />
            <group flat="true" content-margins="0,0,0,0" layout="vbox">
                <combobox id="${ui_comboJointGroup}" on-change="updateUi" />
                <label text="(leave empty to use all joints in the tip-target chain)" />
            </group>
            <label text="Constraint:" />
            <group flat="true" content-margins="0,0,0,0" layout="form">
                <label text="Position:" />
                <group flat="true" content-margins="0,0,0,0" layout="hbox">
                    <checkbox id="${ui_chkConstraintX}" text="X" checked="true" on-change="updateUi" />
                    <checkbox id="${ui_chkConstraintY}" text="Y" checked="true" on-change="updateUi" />
                    <checkbox id="${ui_chkConstraintZ}" text="Z" checked="true" on-change="updateUi" />
                </group>
                <label text="Orientation:" />
                <group flat="true" content-margins="0,0,0,0" layout="hbox">
                    <checkbox id="${ui_chkConstraintAB}" text="Alpha+Beta" checked="true" on-change="updateUi" />
                    <checkbox id="${ui_chkConstraintG}" text="Gamma" checked="true" on-change="updateUi" />
                </group>
            </group>
            <label text="Solver:" />
            <group flat="true" content-margins="0,0,0,0" layout="vbox">
                <group flat="true" content-margins="0,0,0,0" layout="form">
                    <label text="Max. iterations:" />
                    <spinbox id="${ui_spinMaxIterations}" minimum="1" maximum="1000" value="10" on-change="updateUi" />
                    <label text="Damping factor:" />
                    <spinbox id="${ui_spinDampingFactor}" minimum="0" maximum="10" value="0.1" step="0.01" on-change="updateUi" />
                </group>
                <checkbox id="${ui_chkAvoidJointLimits}" text="Actively avoid joint limits" on-change="updateUi" />
                <checkbox id="${ui_chkAbortOnJointLimitsHit}" text="Abort on joint limits hit" on-change="updateUi" />
                <checkbox id="${ui_chkAllowError}" text="Allow error" checked="true" on-change="updateUi" />
                <checkbox id="${ui_chkOutputErrors}" text="Output errors" checked="false" on-change="updateUi" />
            </group>
            <label text="Handling:" />
            <group flat="true" content-margins="0,0,0,0" layout="vbox">
                <checkbox id="${ui_chkEnabled}" text="Enabled" checked="true" on-change="updateUi" />
                <checkbox id="${ui_chkHandleInSimulation}" text="During simulation" checked="true" on-change="updateUi" />
                <checkbox id="${ui_chkHandleInNonSimulation}" text="When not simulating" checked="true" on-change="updateUi" />
            </group>
            <label text="Script:" />
            <group flat="true" content-margins="0,0,0,0" layout="vbox">
                <checkbox id="${ui_chkGenIKVars}" text="IK variables (ikBase, ikTip, ikTarget, ...)" on-change="updateUi" />
            </group>
            <label text="" />
            <button id="${ui_btnGenerate}" text="Generate" on-click="generate" />
        </group>
    </ui>]]
         )
    updateUi()
    local sel = sim.getObjectSel()
    if #sel == 1 then
        local idx = table.find(comboRobotModelHandle, sel[1])
        if idx then simUI.setComboboxSelectedIndex(ui, ui_comboRobotModel, idx - 1, false) end
    end
end

function sysCall_nonSimulation()
    if leaveNow then return {cmd = 'cleanup'} end
end

function sysCall_cleanup()
    if ui then
        simUI.destroy(ui);
        ui = nil
    end
end

function onModelChanged()
    updateUi()
    local robotModel = getRobotModelHandle()
    local needsUpdateUi = false
    if robotModel then
        -- make some reasonable guesses:

        -- select base = robot model
        local idx = table.find(comboRobotBaseHandle, robotModel)
        if idx then
            simUI.setComboboxSelectedIndex(ui, ui_comboRobotBase, idx - 1)
            needsUpdateUi = true
        end

        -- find 'tip'/'target' within model:
        for _, prefix in ipairs{'', 'ik', 'arm'} do
            local cap = prefix == '' and identity or string.capitalize
            local tip = sim.getObject('./' .. prefix .. cap 'tip', {proxy = robotModel, noError = true})
            local target = sim.getObject('./' .. prefix .. cap 'target', {proxy = robotModel, noError = true})
            if tip ~= -1 and target ~= -1 then
                local tip_idx = table.find(comboRobotTipHandle, tip)
                if tip_idx then
                    simUI.setComboboxSelectedIndex(ui, ui_comboRobotTip, tip_idx - 1)
                    needsUpdateUi = true
                end
                local target_idx = table.find(comboRobotTargetHandle, target)
                if target_idx then
                    simUI.setComboboxSelectedIndex(ui, ui_comboRobotTarget, target_idx - 1)
                    needsUpdateUi = true
                end
                break
            end
        end

        simUI.setComboboxSelectedIndex(ui, ui_comboJointGroup, -1)

        if needsUpdateUi then updateUi() end
    end
end

function getRobotModelHandle()
    if comboRobotModelHandle then
        return comboRobotModelHandle[1 + simUI.getComboboxSelectedIndex(ui, ui_comboRobotModel)]
    end
end

function populateComboRobotModel()
    local oldRobotModel, idx = getRobotModelHandle(), 0
    comboRobotModelName = {}
    comboRobotModelHandle = {}
    for i, h in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        if (sim.getModelProperty(h) & sim.modelproperty_not_model) == 0 then
            table.insert(comboRobotModelName, sim.getObjectAlias(h))
            table.insert(comboRobotModelHandle, h)
            if h == oldRobotModel then idx = #comboRobotModelHandle end
        end
    end
    simUI.setComboboxItems(ui, ui_comboRobotModel, comboRobotModelName, idx - 1)
end

function getRobotBaseHandle()
    if comboRobotBaseHandle then
        return comboRobotBaseHandle[1 + simUI.getComboboxSelectedIndex(ui, ui_comboRobotBase)]
    end
end

function populateComboRobotBase()
    local robotModel = getRobotModelHandle()
    local oldRobotBase, idx = getRobotBaseHandle(), 0
    comboRobotBaseName = {}
    comboRobotBaseHandle = {}
    if robotModel then
        for i, h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotBaseName, sim.getObjectAlias(h, 5))
            table.insert(comboRobotBaseHandle, h)
            if h == oldRobotBase then idx = #comboRobotBaseHandle end
        end
    end
    simUI.setComboboxItems(ui, ui_comboRobotBase, comboRobotBaseName, idx - 1)
end

function getRobotTipHandle()
    if comboRobotTipHandle then
        return comboRobotTipHandle[1 + simUI.getComboboxSelectedIndex(ui, ui_comboRobotTip)]
    end
end

function populateComboRobotTip()
    local robotModel = getRobotModelHandle()
    local oldRobotTip, idx = getRobotTipHandle(), 0
    comboRobotTipName = {}
    comboRobotTipHandle = {}
    if robotModel then
        for i, h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotTipName, sim.getObjectAlias(h, 5))
            table.insert(comboRobotTipHandle, h)
            if h == oldRobotTip then idx = #comboRobotTipHandle end
        end
    end
    simUI.setComboboxItems(ui, ui_comboRobotTip, comboRobotTipName, idx - 1)
end

function getRobotTargetHandle()
    if comboRobotTargetHandle then
        return comboRobotTargetHandle[1 + simUI.getComboboxSelectedIndex(ui, ui_comboRobotTarget)]
    end
end

function populateComboRobotTarget()
    local robotModel = getRobotModelHandle()
    local oldRobotTarget, idx = getRobotTargetHandle(), 0
    comboRobotTargetName = {}
    comboRobotTargetHandle = {}
    if robotModel then
        for i, h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotTargetName, sim.getObjectAlias(h, 5))
            table.insert(comboRobotTargetHandle, h)
            if h == oldRobotTarget then idx = #comboRobotTargetHandle end
        end
    end
    simUI.setComboboxItems(ui, ui_comboRobotTarget, comboRobotTargetName, idx - 1)
end

function getJointGroupHandle()
    if comboJointGroupHandle then
        return comboJointGroupHandle[1 + simUI.getComboboxSelectedIndex(ui, ui_comboJointGroup)]
    end
end

function populateComboJointGroup()
    local robotModel = getRobotModelHandle()
    local oldJointGroup, idx = getJointGroupHandle(), 0
    comboJointGroupName = {}
    comboJointGroupHandle = {}
    if robotModel then
        for _, h in ipairs(getJointGroups(robotModel)) do
            table.insert(comboJointGroupName, sim.getObjectAlias(h))
            table.insert(comboJointGroupHandle, h)
            if h == oldJointGroup then idx = #comboJointGroupHandle end
        end
    end
    simUI.setComboboxItems(ui, ui_comboJointGroup, comboJointGroupName, idx - 1)
end

function getConstraint()
    return 0 + (simUI.getCheckboxValue(ui, ui_chkConstraintX) > 0 and simIK.constraint_x or 0) +
               (simUI.getCheckboxValue(ui, ui_chkConstraintY) > 0 and simIK.constraint_y or 0) +
               (simUI.getCheckboxValue(ui, ui_chkConstraintZ) > 0 and simIK.constraint_z or 0) +
               (simUI.getCheckboxValue(ui, ui_chkConstraintAB) > 0 and simIK.constraint_alpha_beta or
                   0) +
               (simUI.getCheckboxValue(ui, ui_chkConstraintG) > 0 and simIK.constraint_gamma or 0)
end

function getConstraintVar()
    local c = getConstraint()
    local r = ''
    for _, i in ipairs {
        {'simIK.constraint_pose', simIK.constraint_pose},
        {'simIK.constraint_position', simIK.constraint_position},
        {'simIK.constraint_orientation', simIK.constraint_orientation},
        {'simIK.constraint_x', simIK.constraint_x}, {'simIK.constraint_y', simIK.constraint_y},
        {'simIK.constraint_z', simIK.constraint_z},
        {'simIK.constraint_alpha_beta', simIK.constraint_alpha_beta},
        {'simIK.constraint_gamma', simIK.constraint_gamma},
    } do
        if (c & i[2]) == i[2] then
            c = c & ~i[2]
            r = r .. (r == '' and '' or '|') .. i[1]
        end
    end
    return r
end

function updateUi()
    populateComboRobotModel()
    populateComboRobotBase()
    populateComboRobotTip()
    populateComboRobotTarget()
    populateComboJointGroup()
    simUI.setEnabled(
        ui, ui_btnGenerate,
        not not (getRobotModelHandle() and getRobotBaseHandle() and getRobotTipHandle() and
            getRobotTargetHandle() and getConstraint() ~= 0)
    )
end

function onClose()
    leaveNow = true
end

function generate()
    local robotModel = getRobotModelHandle()
    local simBase = getRobotBaseHandle()
    local simTip = getRobotTipHandle()
    local simTarget = getRobotTargetHandle()
    local jointGroup = getJointGroupHandle()
    local existingIK = sim.getObject('./IK', {proxy = robotModel, noError = true})
    if existingIK ~= -1 then
        if simUI.msgbox_result.ok ~= simUI.msgBox(
            simUI.msgbox_type.warning, simUI.msgbox_buttons.okcancel, 'IK already exists',
            'The specified model already contains an \'IK\' object. By proceeding, it will be replaced!'
        ) then return end
        if simUI.msgbox_result.yes ~= simUI.msgBox(
            simUI.msgbox_type.question, simUI.msgbox_buttons.yesno, 'Confirm object removal',
            'Are you sure you want to remove object ' .. sim.getObjectAlias(existingIK, 1) .. '?'
        ) then return end
        sim.removeObjects {existingIK}
    end
    local dampingFactor = simUI.getSpinboxValue(ui, ui_spinDampingFactor)
    local maxIterations = simUI.getSpinboxValue(ui, ui_spinMaxIterations)
    local enabled = simUI.getCheckboxValue(ui, ui_chkEnabled) > 0
    local handleInSim = simUI.getCheckboxValue(ui, ui_chkHandleInSimulation) > 0
    local handleInNonSim = simUI.getCheckboxValue(ui, ui_chkHandleInNonSimulation) > 0
    local avoidJointLimits = simUI.getCheckboxValue(ui, ui_chkAvoidJointLimits) > 0
    local abortOnJointLimitsHit = simUI.getCheckboxValue(ui, ui_chkAbortOnJointLimitsHit) > 0
    local allowError = simUI.getCheckboxValue(ui, ui_chkAllowError) > 0
    local outputErrors = simUI.getCheckboxValue(ui, ui_chkOutputErrors) > 0
    local genIKVars = simUI.getCheckboxValue(ui, ui_chkGenIKVars) > 0

    local ikScript = sim.createScript(sim.scripttype_customization, '')
    sim.setObjectAlias(ikScript, 'IK')
    sim.setObjectParent(ikScript, robotModel, false)
    sim.setObjectPose(ikScript, {0, 0, 0, 0, 0, 0, 1}, robotModel)
    sim.setObjectInt32Param(ikScript, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(ikScript, sim.objintparam_manipulation_permissions, 0)
    sim.setReferencedHandles(ikScript, {simBase}, 'ik.base')
    sim.setReferencedHandles(ikScript, {simTip}, 'ik.tip')
    sim.setReferencedHandles(ikScript, {simTarget}, 'ik.target')
    if jointGroup then
        sim.setReferencedHandles(ikScript, {jointGroup}, 'jointGroup')
    end

    local scriptText = ''
    local function appendLine(...)
        scriptText = scriptText .. string.format(...) .. '\n'
    end

    appendLine("sim = require 'sim'")
    appendLine("simIK = require 'simIK'")
    appendLine("")
    appendLine("function sysCall_init()")
    appendLine("    self = sim.getObject '.'")
    appendLine("")
    appendLine("    simBase = sim.getReferencedHandle(self, 'ik.base')")
    appendLine("    simTip = sim.getReferencedHandle(self, 'ik.tip')")
    appendLine("    simTarget = sim.getReferencedHandle(self, 'ik.target')")
    if jointGroup then
        appendLine("    jointGroup = sim.getReferencedHandle(self, 'jointGroup')")
        appendLine("    simJoints = sim.getReferencedHandles(jointGroup)")
    end
    appendLine("")
    appendLine("    enabled = %s", enabled)
    appendLine("    handleWhenSimulationRunning = %s", handleInSim)
    appendLine("    handleWhenSimulationStopped = %s", handleInNonSim)
    appendLine("    dampingFactor = %f", dampingFactor)
    appendLine("    maxIterations = %d", maxIterations)
    appendLine("    if dampingFactor > 0 then")
    appendLine("        method = simIK.method_damped_least_squares")
    appendLine("    else")
    appendLine("        method = simIK.method_pseudo_inverse")
    appendLine("    end")
    appendLine("    constraint = %s", getConstraintVar())
    appendLine("    ikOptions = {")
    appendLine("        syncWorlds = true,")
    appendLine("        allowError = %s,", allowError)
    appendLine("    }")
    appendLine("    ikEnv = simIK.createEnvironment()")
    appendLine("    ikGroup = simIK.createGroup(ikEnv)")
    appendLine("    simIK.setGroupCalculation(ikEnv, ikGroup, method, dampingFactor, maxIterations)")
    if avoidJointLimits or abortOnJointLimitsHit then
        appendLine("    local flags = simIK.getGroupFlags(ikEnv, ikGroup)")
        if avoidJointLimits then appendLine("    flags = flags | simIK.group_avoidlimits") end
        if abortOnJointLimitsHit then
            appendLine("    flags = flags | simIK.group_stoponlimithit")
        end
        appendLine("    simIK.setGroupFlags(ikEnv, ikGroup, flags)")
    end
    appendLine("    _, ikHandleMap, simHandleMap = simIK.addElementFromScene(ikEnv, ikGroup, simBase, simTip, simTarget, constraint)")
    appendLine("")
    appendLine("    if jointGroup then")
    appendLine("        -- disable joints not part of the joint group")
    appendLine("        ikJoints = {}")
    appendLine("        for i, ikJoint in ipairs(simIK.getGroupJoints(ikEnv, ikGroup)) do")
    appendLine("            if table.find(simJoints, simHandleMap[ikJoint]) then")
    appendLine("                table.insert(ikJoints, ikJoint)")
    appendLine("            else")
    appendLine("                simIK.setJointMode(ikEnv, ikJoint, simIK.jointmode_passive)")
    appendLine("            end")
    appendLine("        end")
    appendLine("    else")
    appendLine("        ikJoints = simIK.getGroupJoints(ikEnv, ikGroup)")
    appendLine("    end")
    if genIKVars then
        appendLine("")
        appendLine("    ikBase = ikHandleMap[simBase]")
        appendLine("    ikTip = ikHandleMap[simTip]")
        appendLine("    ikTarget = ikHandleMap[simTarget]")
    end
    appendLine("end")

    appendLine("")
    appendLine("function sysCall_actuation()")
    appendLine("    if enabled and handleWhenSimulationRunning then handleIk() end")
    appendLine("end")

    appendLine("")
    appendLine("function sysCall_nonSimulation()")
    appendLine("    if enabled and handleWhenSimulationStopped then handleIk() end")
    appendLine("end")

    appendLine("")
    appendLine("function sysCall_cleanup()")
    appendLine("    simIK.eraseEnvironment(ikEnv)")
    appendLine("end")

    appendLine("")
    appendLine("function handleIk()")
    appendLine("    local result, failureReason = simIK.handleGroup(ikEnv, ikGroup, ikOptions)")
    if outputErrors then
        appendLine("    if result ~= simIK.result_success then")
        appendLine("        sim.addLog(sim.verbosity_errors, 'IK failed: ' .. simIK.getFailureDescription(failureReason))")
        appendLine("    end")
    end
    appendLine("end")

    appendLine("")
    appendLine("function getEnvironment()")
    appendLine("    return ikEnv")
    appendLine("end")

    appendLine("")
    appendLine("function getGroup()")
    appendLine("    return ikGroup")
    appendLine("end")

    appendLine("")
    appendLine("function getElement()")
    appendLine("    return ikElement")
    appendLine("end")

    appendLine("")
    appendLine("function getBase()")
    appendLine("    return simBase")
    appendLine("end")

    appendLine("")
    appendLine("function getTip()")
    appendLine("    return simTip")
    appendLine("end")

    appendLine("")
    appendLine("function getTarget()")
    appendLine("    return simTarget")
    appendLine("end")

    appendLine("")
    appendLine("function getIkJoints()")
    appendLine("    return ikJoints")
    appendLine("end")

    appendLine("")
    appendLine("function getIkConfig()")
    appendLine("    return map(partial(simIK.getJointPosition, ikEnv), getIkJoints())")
    appendLine("end")

    appendLine("")
    appendLine("function setIkConfig(cfg)")
    appendLine("    foreach(partial(simIK.setJointPosition, ikEnv), getIkJoints(), cfg)")
    appendLine("end")

    if genIKVars then
        appendLine("")
        appendLine("function getIkBase()")
        appendLine("    return ikBase")
        appendLine("end")

        appendLine("")
        appendLine("function getIkTip()")
        appendLine("    return ikTip")
        appendLine("end")

        appendLine("")
        appendLine("function getIkTarget()")
        appendLine("    return ikTarget")
        appendLine("end")
    end

    appendLine("")
    appendLine("function getEnabled()")
    appendLine("    return enabled")
    appendLine("end")

    appendLine("")
    appendLine("function setEnabled(b)")
    appendLine("    enabled = not not b")
    appendLine("end")

    appendLine("")
    appendLine("function getHandleWhenSimulationRunning()")
    appendLine("    return handleWhenSimulationRunning")
    appendLine("end")

    appendLine("")
    appendLine("function setHandleWhenSimulationRunning(b)")
    appendLine("    handleWhenSimulationRunning = not not b")
    appendLine("end")

    appendLine("")
    appendLine("function getHandleWhenSimulationStopped()")
    appendLine("    return handleWhenSimulationStopped")
    appendLine("end")

    appendLine("")
    appendLine("function setHandleWhenSimulationStopped(b)")
    appendLine("    handleWhenSimulationStopped = not not b")
    appendLine("end")

    appendLine("")
    appendLine("function mapToIk(simHandle)")
    appendLine("    return ikHandleMap[simHandle]")
    appendLine("end")

    appendLine("")
    appendLine("function mapToSim(ikHandle)")
    appendLine("    return simHandleMap[ikHandle]")
    appendLine("end")

    sim.setObjectStringParam(ikScript, sim.scriptstringparam_text, scriptText)

    local dat = sim.readCustomBufferData(simTip, 'ikTip')
    if not dat or #dat == 0 then
        sim.writeCustomBufferData(simTip, 'ikTip', sim.packInt32Table {1})
    end
    local dat = sim.readCustomBufferData(simTarget, 'ikTarget')
    if not dat or #dat == 0 then
        sim.writeCustomBufferData(simTarget, 'ikTarget', sim.packInt32Table {1})
    end

    sim.announceSceneContentChange()

    leaveNow = true
end
