function sysCall_info()
    return {autoStart=false}
end

function sysCall_init()
    ui=simUI.create([[<ui title="Motion Planning generator" closeable="true" on-close="onClose" layout="vbox" modal="true">
        <label wordwrap="true" text="This addon generates a script for solving motion planning tasks for the given robot. The script will be placed in a 'Motion Planning' object under the robot model. Choose the params below and click 'Generate'." />
        <group flat="true" content-margins="0,0,0,0" layout="form">
            <label text="Robot model:" />
            <combobox id="${ui_comboRobotModel}" on-change="onModelChanged" />
            <label text="Algorithm:" />
            <combobox id="${ui_comboAlgorithm}" on-change="updateUi" />
            <label text="Planning time:" />
            <spinbox id="${ui_spinPlanningTime}" minimum="1" maximum="60" value="10" step="1" suffix="s" on-change="updateUi" />
            <label text="" />
            <button id="${ui_btnGenerate}" text="Generate" on-click="generate" />
        </group>
    </ui>]])
    updateUi()
    local sel=sim.getObjectSelection()
    if #sel==1 then
        local idx=table.find(comboRobotModelHandle,sel[1])
        if idx then
            simUI.setComboboxSelectedIndex(ui,ui_comboRobotModel,idx-1,false)
        end
    end
    local idxAlgo=table.find(algorithm,simOMPL.Algorithm.PRM)
    simUI.setComboboxSelectedIndex(ui,ui_comboAlgorithm,idxAlgo-1,false)
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
end

function sysCall_cleanup()
    if ui then simUI.destroy(ui); ui=nil end
end

function onModelChanged()
    updateUi()
end

function getRobotModelHandle()
    if comboRobotModelHandle then
        return comboRobotModelHandle[1+simUI.getComboboxSelectedIndex(ui,ui_comboRobotModel)]
    end
end

function populateComboRobotModel()
    local oldRobotModel,idx=getRobotModelHandle(),0
    comboRobotModelName={}
    comboRobotModelHandle={}
    for i,h in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        if (sim.getModelProperty(h)&sim.modelproperty_not_model)==0 then
            table.insert(comboRobotModelName,sim.getObjectAlias(h))
            table.insert(comboRobotModelHandle,h)
            if h==oldRobotModel then idx=#comboRobotModelHandle end
        end
    end
    simUI.setComboboxItems(ui,ui_comboRobotModel,comboRobotModelName,idx-1)
end

function getAlgorithm()
    if algorithm then
        return algorithm[1+simUI.getComboboxSelectedIndex(ui,ui_comboAlgorithm)]
    end
end

function getAlgorithmName()
    if algorithmName then
        return algorithmName[1+simUI.getComboboxSelectedIndex(ui,ui_comboAlgorithm)]
    end
end

function populateComboAlgorithm()
    local robotModel=getRobotModelHandle()
    local oldAlgorithm,idx=getAlgorithm(),0
    algorithmName={}
    algorithm={}
    for n,v in pairs(simOMPL.Algorithm) do
        table.insert(algorithmName,n)
        table.insert(algorithm,v)
        if v==oldAlgorithm then idx=#algorithm end
    end
    simUI.setComboboxItems(ui,ui_comboAlgorithm,algorithmName,idx-1)
end

function updateUi()
    populateComboRobotModel()
    populateComboAlgorithm()
    simUI.setEnabled(ui,ui_btnGenerate,not not (
        getRobotModelHandle() and getAlgorithm()
    ))
end

function onClose()
    leaveNow=true
end

function generate()
    local scriptText=''
    local function appendLine(...) scriptText=scriptText..string.format(...)..'\n' end
    local robotModel=getRobotModelHandle()
    local algorithmName=getAlgorithmName()
    local existingMotionPlanning=sim.getObject('./MotionPlanning',{proxy=robotModel,noError=true})
    if existingMotionPlanning~=-1 then
        if simUI.msgbox_result.ok~=simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.okcancel,'MotionPlanning already exists','The specified model already contains a \'MotionPlanning\' object. By proceeding, it will be replaced!') then return end
        if simUI.msgbox_result.yes~=simUI.msgBox(simUI.msgbox_type.question,simUI.msgbox_buttons.yesno,'Confirm object removal','Are you sure you want to remove object '..sim.getObjectAlias(existingMotionPlanning,1)..'?') then return end
        sim.removeObjects{existingMotionPlanning}
    end

    scriptText=[===[function sysCall_init()
    model=sim.getObject'::'
    task=simOMPL.createTask'main'
    joints=getJoints()
    startState=ObjectProxy'./StartState'
    goalState=ObjectProxy'./GoalState'
    simOMPL.setStateSpaceForJoints(task,joints,{1,1,1})
    robotCollection=sim.createCollection()
    sim.addItemToCollection(robotCollection,sim.handle_tree,model,0)
    simOMPL.setCollisionPairs(task,{robotCollection,sim.handle_all})
    setAlgorithm(simOMPL.Algorithm.]===]..algorithmName..[===[)
    planTime=planTime or 10
    simplificationTime=simplificationTime or -1
    stateCnt=stateCnt or 0
end

function sysCall_cleanup()
    simOMPL.destroyTask(task)
end

function setAlgorithm(a)
    simOMPL.setAlgorithm(task,a)
end

function setStartState(cfg)
    simOMPL.setStartState(task,cfg)
end

function setGoalState(cfg)
    simOMPL.setGoalState(task,cfg)
end

function updateStartState()
    simOMPL.setStartState(task,startState:getConfig())
end

function updateGoalState()
    simOMPL.setGoalState(task,goalState:getConfig())
end

function compute()
    updateStartState()
    updateGoalState()
    simOMPL.setup(task)
    solved,path=simOMPL.compute(task,planTime,simplificationTime,stateCnt)
    printf('solved: %s',solved)
    printf('approximate: %s',simOMPL.hasApproximateSolution(task))
    printf('path: %d items',#path)
    if solved and createPath then
        createPath(path)
    end
end

function createPath()
    local pathDummy=sim.createDummy(0.05)
    sim.setObjectAlias(pathDummy,'Path')
    sim.setModelProperty(pathDummy,0)
    sim.setObjectParent(pathDummy,model)
    sim.setObjectInt32Param(pathDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(pathDummy,sim.objintparam_manipulation_permissions,0)
    sim.setObjectProperty(pathDummy,sim.objectproperty_collapsed)
    local s=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(s,sim.scriptstringparam_text,
[[require'models.robotConfigPath_customization']])
    sim.associateScriptWithObject(s,pathDummy)
    local n=simOMPL.getStateSpaceDimension(task)
    sim.writeCustomTableData(pathDummy,'path',Matrix(-1,n,path):totable())
    local stateDummy=sim.createDummy(0.01)
    sim.setObjectAlias(stateDummy,'State')
    sim.setObjectParent(stateDummy,pathDummy,false)
    sim.setObjectPose(stateDummy,pathDummy,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(stateDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(stateDummy,sim.objintparam_manipulation_permissions,0)
    sim.setObjectProperty(stateDummy,sim.objectproperty_collapsed)
    local s=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(s,sim.scriptstringparam_text,
[[require'models.robotConfig_customization'
model=sim.getObject'::'
color={1,1,0}
ik=false
create=true
]])
    sim.associateScriptWithObject(s,stateDummy)
end

function getJoints()
    local joints={}
    visitTree(model,function(h)
        if h~=model and sim.getModelProperty(h)&sim.modelproperty_not_model==0 then return false end
        if sim.getObjectType(h)==sim.object_joint_type then
            table.insert(joints,h)
        end
        return true
    end)
    return joints
end

function visitTree(handle,visitor)
    if not visitor(handle) then return end
    local i=0
    while true do
        local childHandle=sim.getObjectChild(handle,i)
        if childHandle==-1 then return end
        visitTree(childHandle,visitor)
        i=i+1
    end
end

function ObjectProxy(p,t)
    t=t or sim.scripttype_customizationscript
    return sim.getScriptFunctions(sim.getScript(t,sim.getObject(p)))
end]===]

    local motionPlanningDummy=sim.createDummy(0.01)
    sim.setModelProperty(motionPlanningDummy,0)
    sim.setObjectAlias(motionPlanningDummy,'MotionPlanning')
    sim.setObjectParent(motionPlanningDummy,robotModel,false)
    sim.setObjectPose(motionPlanningDummy,robotModel,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(motionPlanningDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(motionPlanningDummy,sim.objintparam_manipulation_permissions,0)
    local startStateDummy=sim.createDummy(0.01)
    sim.setObjectAlias(startStateDummy,'StartState')
    sim.setObjectParent(startStateDummy,motionPlanningDummy,false)
    sim.setObjectPose(startStateDummy,motionPlanningDummy,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(startStateDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(startStateDummy,sim.objintparam_manipulation_permissions,0)
    local goalStateDummy=sim.createDummy(0.01)
    sim.setObjectAlias(goalStateDummy,'GoalState')
    sim.setObjectParent(goalStateDummy,motionPlanningDummy,false)
    sim.setObjectPose(goalStateDummy,motionPlanningDummy,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(goalStateDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(goalStateDummy,sim.objintparam_manipulation_permissions,0)

    local script=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(script,sim.scriptstringparam_text,scriptText)
    sim.associateScriptWithObject(script,motionPlanningDummy)
    local startStateScript=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(startStateScript,sim.scriptstringparam_text,[[require'models.robotConfig_customization'
model=sim.getObject'::']])
    sim.associateScriptWithObject(startStateScript,startStateDummy)
    local goalStateScript=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(goalStateScript,sim.scriptstringparam_text,[[require'models.robotConfig_customization'
model=sim.getObject'::'
color={0,1,0}]])
    sim.associateScriptWithObject(goalStateScript,goalStateDummy)

    leaveNow=true
end
