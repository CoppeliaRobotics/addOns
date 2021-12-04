function sysCall_info()
    return {autoStart=false}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_init()
    local h=sim.loadModel("./system/alphabet.ttm")
    local allChars="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    allLetters={}
    maxHeight=0
    for i=1,#allChars,1 do
        local char=string.sub(allChars,i,i)
        local m=sim.getObject('./'..char,{proxy=h})
        sim.setModelProperty(m,0)
        allLetters[char]=sim.saveModel(m)
        local s=sim.getShapeBB(m)
        if char=='o' then
            spaceWidth=s[1]
        end
        if s[2]>maxHeight then
            maxHeight=s[2]
        end
    end
    sim.removeModel(h)

    sim.addLog(sim.verbosity_scriptinfos,"This tool allows to generate 3D text. Courtesy of 'Mechatronics Ninja'")
    prevObj=-1
    showDlg()
    config={}
    config.color={1,1,1}
    config.text="Hello\nWorld"
    config.height=0.1
    config.centered=false
end

function sysCall_nonSimulation()
    if leaveNow then
        return {cmd='cleanup'}
    end
    local s=sim.getObjectSelection()
    if s and #s==1 then
        initDlg(s[1])
    else
        prevObj=-1
    end
end

function sysCall_beforeSimulation()
    hideDlg()
end

function sysCall_afterSimulation()
    showDlg()
end

function sysCall_cleanup()
    hideDlg()
end

function sysCall_beforeInstanceSwitch()
    hideDlg()
end

function sysCall_afterInstanceSwitch()
    showDlg()
end

function showDlg()
    if not ui then
        local pos='position="-50,50" placement="relative"'
        if uiPos then
            pos='position="'..uiPos[1]..','..uiPos[2]..'" placement="absolute"'
        end
        local xml ='<ui title="3D text generator" activate="false" closeable="true" on-close="close_callback" '..pos..[[>
            <label text="Text:"/>
            <edit value="Hello\nWorld" on-change="text_callback" id="1" />
            <label text="Height:"/>
            <edit value="0.1" on-change="height_callback" id="2" />
            <checkbox checked="false" text="Centered" on-change="centered_callback" id="3" />
            <button text="Edit color" on-click="color_callback" id="4"/>
            <button text="Generate new" on-click="generate_callback" id="5"/>
        </ui>]]
        ui=simUI.create(xml)
    end
end

function initDlg(obj)
    if obj>=0 and obj~=prevObj and ui then
        local data=sim.readCustomTableData(obj,'__info__')
        if data.type=='3dText' then
            prevObj=obj
            config=sim.readCustomTableData(obj,'__config__')
            local txt=config.text:gsub("\n","\\n")
            simUI.setEditValue(ui,1,txt)
            simUI.setEditValue(ui,2,string.format("%2f",config.height))
            simUI.setCheckboxValue(ui,3,not config.centered and 0 or 2) 
        end
    end
end

function hideDlg()
    if ui then
        uiPos={}
        uiPos[1],uiPos[2]=simUI.getPosition(ui)
        simUI.destroy(ui)
        ui=nil
    end
end

function height_callback(ui,id,v)
    local nb=tonumber(v)
    if nb then
        if nb<0.01 then
            nb=0.01
        end
        if nb>1 then
            nb=1
        end
        config.height=nb
        update()
    end
end

function centered_callback(ui,id,v)
    config.centered=(v~=0)
    update()
end

function text_callback(ui,id,v)
    v=v:gsub("\\n","\n")
    config.text=v
    update()
end

function color_callback()
    local c=simUI.colorDialog(config.color,"Text color",false,true)
    if c then
        config.color=c
        update()
    end
end

function generate_callback()
    update(true)
end

function close_callback()
    leaveNow=true
end

function update(generateNew)
    local s=sim.getObjectSelection()
    local parentDummy
    if s and (#s==1) then
        local data=sim.readCustomTableData(s[1],'__info__')
        if data.type=='3dText' then
            parentDummy=s[1]
        end
    end
    local doNothing
    if generateNew then
        parentDummy=nil
    else
        doNothing=(parentDummy==nil)
    end
    if not doNothing then
        local h=writeText(config.text,config.height,config.centered,config.color,parentDummy)
        sim.writeCustomTableData(h,'__info__',{type='3dText'})
        sim.writeCustomTableData(h,'__config__',config)
    end
end

function writeText(txt,height,centered,color,parentDummy)
    height=height or 0.1
    color=color or {1,1,1}
    local off=0
    local voff=0
    local shapes={}
    local lines={{}}
    local linesW={0}
    local scaling=height/0.1
    for i=1,#txt,1 do
        local char=string.sub(txt,i,i)
        if allLetters[char] then
            local h=sim.loadModel(allLetters[char])
            local size=sim.getShapeBB(h)
            local p=sim.getObjectPosition(h,-1)
            off=off+size[1]*0.55
            sim.setObjectPosition(h,-1,{off,p[2]-voff,0})
            off=off+size[1]*0.55
            shapes[#shapes+1]=h
            lines[#lines][#lines[#lines]+1]=h
            linesW[#linesW]=off
        else
            if char=="\n" then
                off=0
                voff=voff+maxHeight*1.1
                lines[#lines+1]={}
                linesW[#linesW+1]=0
            else
                off=off+spaceWidth
            end
        end
    end

    if centered then
        for i=1,#linesW,1 do
            for j=1,#lines[i],1 do
                local s=lines[i][j]
                local p=sim.getObjectPosition(s,-1)
                sim.setObjectPosition(s,-1,{p[1]-linesW[i]/2,p[2],p[3]})
            end
        end
    end
    local s
    if #shapes>0 then
        if #shapes>1 then
            s=sim.groupShapes(shapes,true)
        else
            s=shapes[1]
        end
        local p=sim.getObjectPosition(s,-1)
        sim.setObjectPosition(s,-1,{p[1],p[2]+voff,p[3]})
        sim.setModelProperty(s,sim.modelproperty_not_model)
        sim.reorientShapeBoundingBox(s,-1)
        sim.setObjectProperty(s,sim.objectproperty_selectable|sim.objectproperty_selectmodelbaseinstead)
        sim.setObjectAlias(s,'text')
        sim.scaleObjects({s},scaling,true)
        sim.setShapeColor(s,nil,sim.colorcomponent_ambient_diffuse,color)
    end
    if parentDummy==nil then
        parentDummy=sim.createDummy(0.005)
    else
        while true do
            local c=sim.getObjectChild(parentDummy,0)
            if c==-1 then
                break
            end
            sim.removeObject(c)
        end
    end
    local retVal=parentDummy
    if #shapes>0 then
        sim.setObjectParent(s,retVal,false)
    end
    sim.setModelProperty(retVal,0)
    sim.setObjectProperty(retVal,sim.objectproperty_selectable|sim.objectproperty_collapsed)
    sim.setObjectInt32Param(retVal,sim.objintparam_visibility_layer,1024)
    if #txt==0 then
        txt="txt"
    end
    sim.setObjectAlias(retVal,txt)
    sim.setObjectSelection({retVal})
    return retVal
end
