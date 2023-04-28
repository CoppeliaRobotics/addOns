function sysCall_info()
    return {autoStart=false,menu='Exporters\nVideo recorder...'}
end

function sysCall_init()
    capturing=false
    numCapturedFrames=0
    outputDir=sim.getStringParam(sim.stringparam_importexportdir)
    ui=simUI.create[[<ui title="Video Recorder" closeable="true" on-close="onUiClose">
        <group flat="true" layout="hbox" content-margins="0,0,0,0">
            <label text="Output dir:" />
            <edit id="${editOutputBaseDir}" value="${outputDir}" />
            <button id="${btnBrowseOutputDir}" text="Browse..." on-click="browse" />
        </group>
        <checkbox id="${chkMakeVideo}" text="Convert image sequence to video" on-change="updateUi" />
        <group enabled="false" id="${grpVideoEncoderOptions}" flat="true" layout="vbox" content-margins="0,0,0,0">
            <group flat="true" layout="hbox" content-margins="0,0,0,0">
                <label text="Frames per second:" />
                <edit id="${editFPS}" value="20" />
            </group>
            <group flat="true" layout="hbox" content-margins="0,0,0,0">
                <label text="Bitrate: (kbps)" />
                <edit id="${editBitrate}" value="1800" />
            </group>
        </group>
        <group flat="true" layout="hbox" content-margins="0,0,0,0">
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
    leaveNow=true
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
    filePrefix=string.format('%d',os.time())
    numCapturedFrames=0
    updateUi()
end

function stopCapture()
    if not capturing then return end
    capturing=false
    if numCapturedFrames>0 then
        if simUI.getCheckboxValue(ui,chkMakeVideo)>0 then
            local fps=tonumber(simUI.getEditValue(ui,editFPS))
            local br=tonumber(simUI.getEditValue(ui,editBitrate))
            local inf=string.format('%s/%s_%s.png',outputDir,filePrefix,'%08d')
            local outf=string.format('%s/%s.mp4',outputDir,filePrefix)
            sim.addLog(sim.verbosity_scriptinfos,string.format('will run: ffmpeg -r %d -i \"%s\" -c:v libx264 -b:v %dk \"%s\"',fps,inf,br,outf))
        end
    end
    updateUi()
end

function updateUi()
    simUI.setEnabled(ui,btnStartCapture,not capturing)
    simUI.setEnabled(ui,btnStopCapture,capturing)
    simUI.setEditValue(ui,editOutputBaseDir,outputDir)
    simUI.setEnabled(ui,grpVideoEncoderOptions,simUI.getCheckboxValue(ui,chkMakeVideo)>0)
end

function capture()
    local img,res=sim.getScaledImage('\xff\x00\xff',{1,1},{1024,768},0)
    local fileName=string.format('%s/%s_%08d.png',outputDir,filePrefix,numCapturedFrames)
    numCapturedFrames=numCapturedFrames+1
    sim.saveImage(img,res,0,fileName,-1)
end
