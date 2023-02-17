function sysCall_info()
    return {autoStart=false,menu='Geometry / Mesh\nMesh convex hull'}
end

function sysCall_init()
    if sim.isPluginLoaded('QHull') then
        local sel=sim.getObjectSelection()
        local ok,err=pcall(simQHull.computeShape,sel)
        if not ok then
            simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','simQHull error: '..err)
        else
            sim.announceSceneContentChange()
        end
    else
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh convex hull add-on','This tool requires the QHull plugin.')
    end
    return {cmd='cleanup'}
end
