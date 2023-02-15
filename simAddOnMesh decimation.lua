function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh decimation'}
end

function sysCall_init()
    if not sim.isPluginLoaded('OpenMesh') then
        sim.addLog(sim.verbosity_scripterrors,'OpenMesh plugin was not found. (simExtOpenMesh.dll or similar). This tool will not run properly.')
        return {cmd='cleanup'}
    end

    sim.addLog(sim.verbosity_scriptinfos,"This tool allows you to simplify a shape (i.e. decimate the mesh). Simply select the shape you wish to decimate, then adjust the decimation factor and press 'Decimated shape!'.")
    prop=0.2
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function showDlg()
    if not ui then
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local xml ='<ui title="Mesh decimation" activate="false" closeable="true" on-close="close_callback" layout="vbox" '..pos..[[>
                <label text="xxx" id="1" />
                <hslider id="2" on-change="slider_callback" minimum="0" maximum="100"/>
                <label text="xxx" id="3" />
                <button text="Decimate selected mesh" on-click="decimate_callback"/>
        </ui>]]
        ui=simUI.create(xml)
        updateUI()
    end
end

function hideDlg()
    if ui then
        uiPos={}
        uiPos[1],uiPos[2]=simUI.getPosition(ui)
        simUI.destroy(ui)
        ui=nil
    end
    currentShape=nil
end

function getCurrentAndAfterTriangleCnt()
    local vertices,indices=sim.getShapeMesh(currentShape)
    local currentTriangleCount=#indices//3
    local afterTriangleCount=currentTriangleCount*prop
    if afterTriangleCount==0 then afterTriangleCount=1 end
    return currentTriangleCount,afterTriangleCount
end

function updateUI(ignoreSlider)
    if not ignoreSlider then
        simUI.setSliderValue(ui,2,100*(prop-0.1)/0.8)
    end
    local currentTriangleCount,afterTriangleCount=getCurrentAndAfterTriangleCnt()
    simUI.setLabelText(ui,1,string.format('Triangle count now: %i',currentTriangleCount))
    simUI.setLabelText(ui,3,string.format('Triangle count after: %i (%i%%)',math.floor(afterTriangleCount),afterTriangleCount*100//currentTriangleCount))
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
    local s=sim.getObjectSelection()
    local show=(s and #s==1 and sim.getObjectType(s[1])==sim.object_shape_type)
    if show then
        currentShape=s[1]
        showDlg()
    else
        currentShape=nil
        hideDlg()
    end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function slider_callback(ui,id,v)
    prop=0.1+0.8*v/100
    updateUI(true)
end

function decimate_callback()
    if currentShape then
        local newShape=simOpenMesh.getDecimatedShape(currentShape,prop)
        sim.removeObjectFromSelection(sim.handle_all,-1)
        sim.addObjectToSelection(sim.handle_single,newShape)
        currentShape=newShape
        sim.announceSceneContentChange()
    end
    updateUI()
end

function close_callback()
    leaveNow=true
end
