function sysCall_info()
    return {autoStart=false,menu='Exporters\nVideo recorder...'}
end

function sysCall_init()
    capturing=false
    numCapturedFrames=0
    outputDir=sim.getStringParam(sim.stringparam_importexportdir)
    ui=simUI.create[[<ui title="Video Recorder" closeable="true" on-close="onUiClose">
        <group layout="hbox" content-margins="0,0,0,0">
            <label text="Output dir:" />
            <edit id="${editOutputBaseDir}" value="${outputDir}" />
            <button id="${btnBrowseOutputDir}" text="Browse..." on-click="browse" />
        </group>
        <group layout="hbox" content-margins="0,0,0,0">
            <button id="${btnStartCapture}" text="Start capture" on-click="startCapture" />
            <button id="${btnStopCapture}" text="Stop capture" on-click="stopCapture" enabled="false" />
        </group>
    </ui>]]
end

function sysCall_cleanup()
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_afterSimulation()
end

function sysCall_beforeInstanceSwitch()
end

function sysCall_sensing()
    if capturing then
        capture()
    end
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
    if capturing then
        capture()
    end
end

function onUiClose()
end

function browse()
    local r=simUI.fileDialog(simUI.filedialog_type.folder,'Select output directory',outputDir,'','','',true)
    if r[1]=='' then return end
    outputDir=r[1]
    updateUi()
end

function startCapture()
    if capturing then return end
    capturing=true
    filePrefix=string.format('%d_',os.time())
    numCapturedFrames=0
    updateUi()
end

function stopCapture()
    if not capturing then return end
    capturing=false
    if numCapturedFrames>0 then
    end
    updateUi()
end

function updateUi()
    simUI.setEnabled(ui,btnStartCapture,not capturing)
    simUI.setEnabled(ui,btnStopCapture,capturing)
    simUI.setEditValue(ui,editOutputBaseDir,outputDir)
end

function capture()
    local img,res=sim.getScaledImage('\xff\x00\xff',{1,1},{1024,768},0)
    local fileName=string.format('%s/%s%08d.png',outputDir,filePrefix,numCapturedFrames)
    numCapturedFrames=numCapturedFrames+1
    sim.saveImage(img,res,0,fileName,-1)
end
