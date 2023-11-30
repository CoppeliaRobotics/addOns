sim = require 'sim'
require 'addOns.jointGroup'

function sysCall_info()
    return {autoStart = false, menu = 'Kinematics\nMotion planning generator...'}
end

function sysCall_init()
    simUI = require 'simUI'
    simOMPL = require 'simOMPL'
    ui = simUI.create(
             [[<ui title="Motion Planning generator" closeable="true" on-close="onClose" layout="vbox" modal="true">
        <label wordwrap="true" text="This addon generates a script for solving motion planning tasks for the given robot. The script will be placed in a 'Motion Planning' object under the robot model. Choose the params below and click 'Generate'." />
        <group flat="true" content-margins="0,0,0,0" layout="form">
            <label text="Robot model:" />
            <combobox id="${ui_comboRobotModel}" on-change="onModelChanged" />
            <label text="Algorithm:" />
            <combobox id="${ui_comboAlgorithm}" on-change="updateUi" />
            <label text="Planning time:" />
            <spinbox id="${ui_spinPlanningTime}" minimum="1" maximum="60" value="10" step="1" suffix="s" on-change="updateUi" />
            <label text="Joint group:" />
            <combobox id="${ui_comboJointGroup}" on-change="updateUi" />
            <label text="" />
            <button id="${ui_btnGenerate}" text="Generate" on-click="generate" />
        </group>
    </ui>]]
         )
    updateUi()
    local sel = sim.getObjectSelection()
    if #sel == 1 then
        local idx = table.find(comboRobotModelHandle, sel[1])
        if idx then simUI.setComboboxSelectedIndex(ui, ui_comboRobotModel, idx - 1, false) end
    end
    local idxAlgo = table.find(algorithm, simOMPL.Algorithm.PRM)
    simUI.setComboboxSelectedIndex(ui, ui_comboAlgorithm, idxAlgo - 1, false)
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

function getAlgorithm()
    if algorithm then return algorithm[1 + simUI.getComboboxSelectedIndex(ui, ui_comboAlgorithm)] end
end

function getAlgorithmName()
    if algorithmName then
        return algorithmName[1 + simUI.getComboboxSelectedIndex(ui, ui_comboAlgorithm)]
    end
end

function populateComboAlgorithm()
    local robotModel = getRobotModelHandle()
    local oldAlgorithm, idx = getAlgorithm(), 0
    algorithmName = {}
    algorithm = {}
    for n, v in pairs(simOMPL.Algorithm) do
        table.insert(algorithmName, n)
        table.insert(algorithm, v)
        if v == oldAlgorithm then idx = #algorithm end
    end
    simUI.setComboboxItems(ui, ui_comboAlgorithm, algorithmName, idx - 1)
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

function updateUi()
    populateComboRobotModel()
    populateComboAlgorithm()
    populateComboJointGroup()
    simUI.setEnabled(
        ui, ui_btnGenerate,
        not not (getRobotModelHandle() and getAlgorithm() and getJointGroupHandle())
    )
end

function onClose()
    leaveNow = true
end

function generate()
    local scriptText = ''
    local function appendLine(...)
        scriptText = scriptText .. string.format(...) .. '\n'
    end
    local robotModel = getRobotModelHandle()
    local algorithmName = getAlgorithmName()
    local jointGroup = getJointGroupHandle()
    local existingMotionPlanning = sim.getObject(
                                       './MotionPlanning', {proxy = robotModel, noError = true}
                                   )
    if existingMotionPlanning ~= -1 then
        if simUI.msgbox_result.ok ~= simUI.msgBox(
            simUI.msgbox_type.warning, simUI.msgbox_buttons.okcancel,
            'MotionPlanning already exists',
            'The specified model already contains a \'MotionPlanning\' object. By proceeding, it will be replaced!'
        ) then return end
        if simUI.msgbox_result.yes ~= simUI.msgBox(
            simUI.msgbox_type.question, simUI.msgbox_buttons.yesno, 'Confirm object removal',
            'Are you sure you want to remove object ' ..
                sim.getObjectAlias(existingMotionPlanning, 1) .. '?'
        ) then return end
        sim.removeObjects {existingMotionPlanning}
    end

    local motionPlanningDummy = sim.createDummy(0.01)
    sim.setModelProperty(motionPlanningDummy, 0)
    sim.setObjectAlias(motionPlanningDummy, 'MotionPlanning')
    sim.setObjectParent(motionPlanningDummy, robotModel, false)
    sim.setObjectPose(motionPlanningDummy, {0, 0, 0, 0, 0, 0, 1}, robotModel)
    sim.setObjectInt32Param(motionPlanningDummy, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(motionPlanningDummy, sim.objintparam_manipulation_permissions, 0)

    local jointGroupPath = sim.getObjectAliasRelative(jointGroup, robotModel, 1)
    appendLine("sim=require'sim'")
    appendLine("simOMPL=require'simOMPL'")
    appendLine("robotConfigPath=require'models.robotConfigPath'")
    appendLine("")
    appendLine("function sysCall_init()")
    appendLine("    model=sim.getObject'::'")
    appendLine("    jointGroup=sim.getObject('%s',{proxy=model})", jointGroupPath)
    appendLine("    joints=sim.getReferencedHandles(jointGroup)")
    appendLine("")
    appendLine("    robotCollection=sim.createCollection()")
    appendLine("    sim.addItemToCollection(robotCollection,sim.handle_tree,model,0)")
    appendLine("")
    appendLine("    startState=ObjectProxy'./StartState'")
    appendLine("    goalState=ObjectProxy'./GoalState'")
    appendLine("")
    appendLine("    task=simOMPL.createTask'main'")
    appendLine("")
    appendLine("    -- wrap simOMPL.* functions with task argument:")
    appendLine("    for k,v in pairs(simOMPL) do")
    appendLine("        if type(v)=='function' and not _G[k] then")
    appendLine("            _G[k]=function(...) return simOMPL[k](task,...) end")
    appendLine("        end")
    appendLine("    end")
    appendLine("")
    appendLine("    setStateSpaceForJoints(joints,{1,1,1})")
    appendLine("    setCollisionPairs({robotCollection,sim.handle_all})")
    appendLine("    setAlgorithm(simOMPL.Algorithm.%s)", algorithmName)
    appendLine("end")
    appendLine("")
    appendLine("function sysCall_cleanup()")
    appendLine("    destroyTask()")
    appendLine("end")
    appendLine("")
    appendLine("function compute()")
    appendLine("    setStartState(startState:getConfig())")
    appendLine("    setGoalState(goalState:getConfig())")
    appendLine("    setup()")
    appendLine("    solved,path=simOMPL.compute(task,10)")
    appendLine("    path=Matrix(-1,getStateSpaceDimension(),path)")
    appendLine(
        '%s',
        "    printf('solved: %s (%s)',solved,hasApproximateSolution() and 'approximate' or 'exact')"
    )
    appendLine('%s', "    printf('path: %d states',#path)")
    appendLine("    if solved then")
    appendLine("        robotConfigPath.create(path,model,'%s')", jointGroupPath)
    appendLine("    end")
    appendLine("end")
    appendLine("")
    appendLine("function ObjectProxy(p,t)")
    appendLine("    t=t or sim.scripttype_customizationscript")
    appendLine("    return sim.getScriptFunctions(sim.getScript(t,sim.getObject(p)))")
    appendLine("end")

    local startStateDummy = sim.createDummy(0.01)
    sim.setObjectAlias(startStateDummy, 'StartState')
    sim.setObjectParent(startStateDummy, motionPlanningDummy, false)
    sim.setObjectPose(startStateDummy, {0, 0, 0, 0, 0, 0, 1}, motionPlanningDummy)
    sim.setObjectInt32Param(startStateDummy, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(startStateDummy, sim.objintparam_manipulation_permissions, 0)
    local goalStateDummy = sim.createDummy(0.01)
    sim.setObjectAlias(goalStateDummy, 'GoalState')
    sim.setObjectParent(goalStateDummy, motionPlanningDummy, false)
    sim.setObjectPose(goalStateDummy, {0, 0, 0, 0, 0, 0, 1}, motionPlanningDummy)
    sim.setObjectInt32Param(goalStateDummy, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(goalStateDummy, sim.objintparam_manipulation_permissions, 0)

    local script = sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(script, sim.scriptstringparam_text, scriptText)
    sim.associateScriptWithObject(script, motionPlanningDummy)
    local startStateScript = sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(
        startStateScript, sim.scriptstringparam_text, [[require'models.robotConfig_customization'
model=sim.getObject'::'
jointGroupPath=']] .. jointGroupPath .. "'"
    )
    sim.associateScriptWithObject(startStateScript, startStateDummy)
    local goalStateScript = sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(
        goalStateScript, sim.scriptstringparam_text, [[require'models.robotConfig_customization'
model=sim.getObject'::'
jointGroupPath=']] .. jointGroupPath .. [['
color={0,1,0}]]
    )
    sim.associateScriptWithObject(goalStateScript, goalStateDummy)
    sim.announceSceneContentChange()

    leaveNow = true
end
