function sysCall_info()
    return {autoStart=false}
end

function sysCall_init()
    ui=simUI.create([[<ui title="Inverse Kinematics generator" closeable="true" on-close="onClose" layout="vbox" modal="true">
        <label wordwrap="true" text="This addon generates a script for solving inverse kinematics for the given tip/target/params. The script will be placed in an 'IK' object under the robot model. Choose the params below and click 'Generate'." />
        <group flat="true" content-margins="0,0,0,0" layout="form">
            <label text="Robot model:" />
            <combobox id="${ui_comboRobotModel}" on-change="onModelChanged" />
            <label text="Robot base:" />
            <combobox id="${ui_comboRobotBase}" on-change="updateUi" />
            <label text="Robot tip:" />
            <combobox id="${ui_comboRobotTip}" on-change="updateUi" />
            <label text="Robot target:" />
            <combobox id="${ui_comboRobotTarget}" on-change="updateUi" />
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
            <group flat="true" content-margins="0,0,0,0" layout="form">
                <label text="Max. iterations:" />
                <spinbox id="${ui_spinMaxIterations}" minimum="1" maximum="1000" value="10" on-change="updateUi" />
                <label text="Damping factor:" />
                <spinbox id="${ui_spinDampingFactor}" minimum="0" maximum="10" value="0.01" step="0.01" on-change="updateUi" />
            </group>
            <label text="Handling:" />
            <group flat="true" content-margins="0,0,0,0" layout="vbox">
                <checkbox id="${ui_chkHandleInSimulation}" text="During simulation" checked="true" on-change="updateUi" />
                <checkbox id="${ui_chkHandleInNonSimulation}" text="When not simulating" on-change="updateUi" />
            </group>
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
    local robotModel=getRobotModelHandle()
    local needsUpdateUi=false
    if robotModel then
        -- make some reasonable guesses:

        -- select base = robot model
        local idx=table.find(comboRobotBaseHandle,robotModel)
        if idx then
            simUI.setComboboxSelectedIndex(ui,ui_comboRobotBase,idx-1)
            needsUpdateUi=true
        end

        -- find 'tip' within model:
        local tip=sim.getObject('./tip',{proxy=robotModel,noError=true})
        if tip~=-1 then
            local idx=table.find(comboRobotTipHandle,tip)
            if idx then
                simUI.setComboboxSelectedIndex(ui,ui_comboRobotTip,idx-1)
                needsUpdateUi=true
            end
        end

        -- find 'target' within model:
        local target=sim.getObject('./target',{proxy=robotModel,noError=true})
        if target~=-1 then
            local idx=table.find(comboRobotTargetHandle,target)
            if idx then
                simUI.setComboboxSelectedIndex(ui,ui_comboRobotTarget,idx-1)
                needsUpdateUi=true
            end
        end

        if needsUpdateUi then
            updateUi()
        end
    end
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

function getRobotBaseHandle()
    if comboRobotBaseHandle then
        return comboRobotBaseHandle[1+simUI.getComboboxSelectedIndex(ui,ui_comboRobotBase)]
    end
end

function populateComboRobotBase()
    local robotModel=getRobotModelHandle()
    local oldRobotBase,idx=getRobotBaseHandle(),0
    comboRobotBaseName={}
    comboRobotBaseHandle={}
    if robotModel then
        for i,h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotBaseName,sim.getObjectAlias(h,5))
            table.insert(comboRobotBaseHandle,h)
            if h==oldRobotBase then idx=#comboRobotBaseHandle end
        end
    end
    simUI.setComboboxItems(ui,ui_comboRobotBase,comboRobotBaseName,idx-1)
end

function getRobotTipHandle()
    if comboRobotTipHandle then
        return comboRobotTipHandle[1+simUI.getComboboxSelectedIndex(ui,ui_comboRobotTip)]
    end
end

function populateComboRobotTip()
    local robotModel=getRobotModelHandle()
    local oldRobotTip,idx=getRobotTipHandle(),0
    comboRobotTipName={}
    comboRobotTipHandle={}
    if robotModel then
        for i,h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotTipName,sim.getObjectAlias(h,5))
            table.insert(comboRobotTipHandle,h)
            if h==oldRobotTip then idx=#comboRobotTipHandle end
        end
    end
    simUI.setComboboxItems(ui,ui_comboRobotTip,comboRobotTipName,idx-1)
end

function getRobotTargetHandle()
    if comboRobotTargetHandle then
        return comboRobotTargetHandle[1+simUI.getComboboxSelectedIndex(ui,ui_comboRobotTarget)]
    end
end

function populateComboRobotTarget()
    local robotModel=getRobotModelHandle()
    local oldRobotTarget,idx=getRobotTargetHandle(),0
    comboRobotTargetName={}
    comboRobotTargetHandle={}
    if robotModel then
        for i,h in ipairs(sim.getObjectsInTree(robotModel)) do
            table.insert(comboRobotTargetName,sim.getObjectAlias(h,5))
            table.insert(comboRobotTargetHandle,h)
            if h==oldRobotTarget then idx=#comboRobotTargetHandle end
        end
    end
    simUI.setComboboxItems(ui,ui_comboRobotTarget,comboRobotTargetName,idx-1)
end

function getConstraint()
    return 0
        +(simUI.getCheckboxValue(ui,ui_chkConstraintX)>0 and simIK.constraint_x or 0)
        +(simUI.getCheckboxValue(ui,ui_chkConstraintY)>0 and simIK.constraint_y or 0)
        +(simUI.getCheckboxValue(ui,ui_chkConstraintZ)>0 and simIK.constraint_z or 0)
        +(simUI.getCheckboxValue(ui,ui_chkConstraintAB)>0 and simIK.constraint_alpha_beta or 0)
        +(simUI.getCheckboxValue(ui,ui_chkConstraintG)>0 and simIK.constraint_gamma or 0)
end

function getConstraintVar()
    local c=getConstraint()
    local r=''
    for _,i in ipairs{
        {'simIK.constraint_pose',simIK.constraint_pose},
        {'simIK.constraint_position',simIK.constraint_position},
        {'simIK.constraint_orientation',simIK.constraint_orientation},
        {'simIK.constraint_x',simIK.constraint_x},
        {'simIK.constraint_y',simIK.constraint_y},
        {'simIK.constraint_z',simIK.constraint_z},
        {'simIK.constraint_alpha_beta',simIK.constraint_alpha_beta},
        {'simIK.constraint_gamma',simIK.constraint_gamma},
    } do
        if (c&i[2])==i[2] then
            c=c&~i[2]
            r=r..(r=='' and '' or '|')..i[1]
        end
    end
    return r
end

function updateUi()
    populateComboRobotModel()
    populateComboRobotBase()
    populateComboRobotTip()
    populateComboRobotTarget()
    simUI.setEnabled(ui,ui_btnGenerate,not not (
        getRobotModelHandle() and getRobotBaseHandle() and getRobotTipHandle() and getRobotTargetHandle()
        and getConstraint()~=0
    ))
end

function onClose()
    leaveNow=true
end

function generate()
    local scriptText=''
    local function appendLine(...) scriptText=scriptText..string.format(...)..'\n' end
    local robotModel=getRobotModelHandle()
    local existingIK=sim.getObject('./IK',{proxy=robotModel,noError=true})
    if existingIK~=-1 then
        if simUI.msgbox_result.ok~=simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.okcancel,'IK already exists','The specified model already contains an \'IK\' object. By proceeding, it will be replaced!') then return end
        if simUI.msgbox_result.yes~=simUI.msgBox(simUI.msgbox_type.question,simUI.msgbox_buttons.yesno,'Confirm object removal','Are you sure you want to remove object '..sim.getObjectAlias(existingIK,1)..'?') then return end
        sim.removeObjects{existingIK}
    end
    local dampingFactor=simUI.getSpinboxValue(ui,ui_spinDampingFactor)
    local maxIterations=simUI.getSpinboxValue(ui,ui_spinMaxIterations)
    local handleInSim=simUI.getCheckboxValue(ui,ui_chkHandleInSimulation)>0
    local handleInNonSim=simUI.getCheckboxValue(ui,ui_chkHandleInNonSimulation)>0

    appendLine("function sysCall_init()")
    appendLine("    self=sim.getObject'.'")
    appendLine("    parent=sim.getObjectParent(self)")
    appendLine("")
    appendLine("    simBase=sim.getObject('%s',{proxy=parent})",sim.getObjectAliasRelative(getRobotBaseHandle(),robotModel,1))
    appendLine("    simTip=sim.getObject('%s',{proxy=parent})",sim.getObjectAliasRelative(getRobotTipHandle(),robotModel,1))
    appendLine("    simTarget=sim.getObject('%s',{proxy=parent})",sim.getObjectAliasRelative(getRobotTargetHandle(),robotModel,1))
    appendLine("")
    appendLine("    ikEnv=simIK.createEnvironment()")
    appendLine("")
    appendLine("    dampingFactor=%f",dampingFactor)
    appendLine("    maxIterations=%d",maxIterations)
    appendLine("    if dampingFactor>0 then")
    appendLine("        method=simIK.method_damped_least_squares")
    appendLine("    else")
    appendLine("        method=simIK.method_pseudo_inverse")
    appendLine("    end")
    appendLine("    constraint=%s",getConstraintVar())
    appendLine("    ikGroup=simIK.createIkGroup(ikEnv)")
    appendLine("    simIK.setIkGroupCalculation(ikEnv,ikGroup,method,dampingFactor,maxIterations)")
    appendLine("    simIK.addIkElementFromScene(ikEnv,ikGroup,simBase,simTip,simTarget,constraint)")
    appendLine("end")

    appendLine("")
    appendLine("function sysCall_cleanup()")
    appendLine("    simIK.eraseEnvironment(ikEnv)")
    appendLine("end")

    appendLine("")
    appendLine("function handleIk()")
    appendLine("    local result,failureReason=simIK.applyIkEnvironmentToScene(ikEnv,ikGroup,true)")
    appendLine("    if result~=simIK.result_success then")
    appendLine("        print('IK failed: '..simIK.getFailureDescription(failureReason))")
    appendLine("    end")
    appendLine("end")

    if handleInSim then
        appendLine("")
        appendLine("function sysCall_actuation()")
        appendLine("    handleIk()")
        appendLine("end")
    end
    if handleInNonSim then
        appendLine("")
        appendLine("function sysCall_nonSimulation()")
        appendLine("    handleIk()")
        appendLine("end")
    end

    local ikDummy=sim.createDummy(0.01)
    local script=sim.addScript(handleInNonSim and sim.scripttype_customizationscript or sim.scripttype_childscript)
    sim.setScriptStringParam(script,sim.scriptstringparam_text,scriptText)
    sim.associateScriptWithObject(script,ikDummy)
    sim.setObjectAlias(ikDummy,'IK')
    sim.setObjectParent(ikDummy,robotModel,false)
    sim.setObjectPose(ikDummy,robotModel,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(ikDummy,sim.objintparam_visibility_layer,0)
    leaveNow=true
end
