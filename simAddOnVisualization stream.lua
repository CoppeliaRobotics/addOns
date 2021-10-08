function sysCall_info()
    return {autoStart=false,menu='Connectivity\nVisualization stream'}
end

function sysCall_init()
    zmqEnable=tonumber(sim.getStringNamedParam('visualizationStream.zmq.enable') or '1')
    wsEnable=tonumber(sim.getStringNamedParam('visualizationStream.ws.enable') or '1')

    if zmqEnable>0 and simZMQ then
        simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call
        zmqPUBPort=tonumber(sim.getStringNamedParam('visualizationStream.zmq.pub.port') or '23010')
        zmqREPPort=tonumber(sim.getStringNamedParam('visualizationStream.zmq.rep.port') or zmqPUBPort+1)
        print('Add-on "Visualization stream": ZMQ endpoint on ports '..tostring(zmqPUBPort)..', '..tostring(zmqREPPort)..'...')
        zmqContext=simZMQ.ctx_new()
        zmqPUBSocket=simZMQ.socket(zmqContext,simZMQ.PUB)
        simZMQ.bind(zmqPUBSocket,string.format('tcp://*:%d',zmqPUBPort))
        zmqREPSocket=simZMQ.socket(zmqContext,simZMQ.REP)
        simZMQ.bind(zmqPUBSocket,string.format('tcp://*:%d',zmqREPPort))
    elseif zmqEnable>0 then
        sim.addLog(sim.verbosity_errors,'Visualization stream: the ZMQ plugin is not available')
        zmqEnable=0
    end

    if wsEnable>0 and simWS then
        wsPort=tonumber(sim.getStringNamedParam('visualizationStream.ws.port') or '23020')
        print('Add-on "Visualization stream": WS endpoint on port '..tostring(wsPort)..'...')
        wsServer=simWS.start(wsPort)
        simWS.setOpenHandler(wsServer,'onWSOpen')
        simWS.setCloseHandler(wsServer,'onWSClose')
        simWS.setMessageHandler(wsServer,'onWSMessage')
        simWS.setHTTPHandler(wsServer,'onWSHTTP')
        wsClients={}
    elseif wsEnable>0 then
        sim.addLog(sim.verbosity_errors,'Visualization stream: the WS plugin is not available')
        wsEnable=0
    end

    if zmqEnable==0 and wsEnable==0 then
        sim.addLog(sim.verbosity_errors,'Visualization stream: aborting because no RPC backend available')
        return {cmd='cleanup'}
    end

    codec=sim.getStringNamedParam('visualizationStream.codec') or 'cbor'
    if codec=='json' then
        json=require('dkjson')
        encode=json.encode
        decode=json.decode
        opcode=simWS.opcode.text
    elseif codec=='cbor' then
        cbor=require('org.conman.cbor')
        encode=cbor.encode
        decode=cbor.decode
        opcode=simWS.opcode.binary
    else
        error('unsupported codec: '..codec)
    end
    base64=require('base64')

    localData={}
    remoteData={}
end

function sysCall_addOnScriptSuspend()
    return {cmd='cleanup'}
end

function sysCall_nonSimulation()
    processZMQRequests()
    scan()
end

function sysCall_sensing()
    processZMQRequests()
    scan()
end

function sysCall_cleanup()
    if zmqPUBSocket or zmqREPSocket then
        if zmqPUBSocket then simZMQ.close(zmqPUBSocket) end
        if zmqREPSocket then simZMQ.close(zmqREPSocket) end
        simZMQ.ctx_term(zmqContext)
    end

    if wsServer then
        simWS.stop(wsServer)
    end
end

function processZMQRequests()
    if not zmqREPSocket then return end
    while true do
        local rc,revents=simZMQ.poll({zmqREPSocket},{simZMQ.POLLIN},0)
        if rc<=0 then break end
        local rc,req=simZMQ.recv(zmqREPSocket,0)
        local resp=onZMQRequest(decode(req))
        simZMQ.send(zmqREPSocket,encode(resp),0)
    end
end

function onZMQRequest(data)
    local resp={}
    if data.cmd=='getbacklog' then
        -- send current objects:
        for handle,data in pairs(remoteData) do
            table.insert(resp,objectAdded(handle))
            table.insert(resp,objectChanged(handle))
        end
    end
    return resp
end

function onWSOpen(server,connection)
    if server==wsServer then
        wsClients[connection]=1
        -- send current objects:
        for handle,data in pairs(remoteData) do
            sendEvent(objectAdded(handle),connection)
            sendEvent(objectChanged(handle),connection)
        end
    end
end

function onWSClose(server,connection)
    if server==wsServer then
        wsClients[connection]=nil
    end
end

function onWSMessage(server,connection,message)
end

function onWSHTTP(server,connection,resource,data)
    if resource=='/' then
        return 200,[[<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <title>CoppeliaSim remote view</title>
        <style>
            body {
                margin: 0;
                background-image: linear-gradient(rgb(204,222,235), rgb(13,13,26));
            }
            #logo {
                position: absolute;
                right: 20px;
                top: 20px;
                z-index: 100;
                pointer-events: none;
                width: 500px;
                height: auto;
            }
		</style>
    </head>
    <body>
        <script src="https://cdn.jsdelivr.net/gh/spaceify/cbor-js@master/cbor.js" integrity="sha512-0ABB8mRQj73e8+aaUzonPYnP34/YsUCf6SGUJp/pj5BUXttDonDIvCI7XuC7C27Qem6yRpzIzTlq8kJSlUNjoQ==" crossorigin="anonymous"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.js" integrity="sha512-NLtnLBS9Q2w7GKK9rKxdtgL7rA7CAS85uC/0xd9im4J/yOL4F9ZVlv634NAM7run8hz3wI2GabaA6vv8vJtHiQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script src="https://threejs.org/examples/js/controls/OrbitControls.js"></script>
        <script>
            const wsPort = ]]..wsPort..[[;
            const codec = "]]..codec..[[";
        </script>
        <script src="/.js"></script>
        </script>
        <img id="logo" src="data:image/png;base64,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" />
    </body>
</html>]]
    elseif resource=='/.js' then
        return 200,[[
THREE.Object3D.DefaultUp = new THREE.Vector3(0,0,1);

const scene = new THREE.Scene();

const ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
scene.add(ambientLight);

const light = new THREE.PointLight(0xffffff, 0.7);

const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.add(light);
scene.add(camera); // required because the camera has a child

const renderer = new THREE.WebGLRenderer({alpha: true});
renderer.setSize(window.innerWidth, window.innerHeight);

document.body.appendChild(renderer.domElement);

const controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.addEventListener('change', render);

camera.position.x = 1.12;
camera.position.y = -1.9;
camera.position.z = 1.08;
camera.rotation.x = 1.08;
camera.rotation.y = 0.64;
camera.rotation.z = 0.31;
camera.up.x = 0;
camera.up.y = 0;
camera.up.z = 1;

function render() {
	renderer.render(scene, camera);
}

function animate() {
	requestAnimationFrame(animate);
    controls.update();
    render();
}
animate();

window.addEventListener('resize', onWindowResize);

function onWindowResize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
}

// handle updates from CoppeliaSim:

var meshes = {};

function makeMesh(meshData) {
    const geometry = new THREE.BufferGeometry();
    // XXX: vertex attribute format handed by CoppeliaSim is not correct
    //      we expand all attributes and discard indices
    if(false) {
        geometry.setIndex(meshData.indices);
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(meshData.vertices, 3));
        geometry.setAttribute('normal', new THREE.Float32BufferAttribute(meshData.normals, 3));
    } else {
        var ps = [];
        var ns = [];
        for(var i = 0; i < meshData.indices.length; i++) {
            var index = meshData.indices[i];
            var p = meshData.vertices.slice(3 * index, 3 * (index + 1));
            ps.push(p[0], p[1], p[2]);
            var n = meshData.normals.slice(3 * i, 3 * (i + 1));
            ns.push(n[0], n[1], n[2]);
        }
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(ps, 3));
        geometry.setAttribute('normal', new THREE.Float32BufferAttribute(ns, 3));
    }
    var texture = null;
    if(meshData.texture !== undefined) {
        var image = new Image();
        image.src =  "data:image/png;base64," + meshData.texture.texture;
        texture = new THREE.Texture();
        texture.image = image;
		if((meshData.texture.options & 1) > 0)
            texture.wrapS = THREE.RepeatWrapping;
		if((meshData.texture.options & 2) > 0)
            texture.wrapT = THREE.RepeatWrapping;
		if((meshData.texture.options & 4) > 0)
            texture.magFilter = texture.minFilter = THREE.LinearFilter;
        else
            texture.magFilter = texture.minFilter = THREE.NearestFilter;
        image.onload = function() {
            texture.needsUpdate = true;
        };

        if(false) { // XXX: see above
            geometry.setAttribute('uv', new THREE.Float32BufferAttribute(meshData.texture.coordinates, 2));
        } else {
            var uvs = [];
            for(var i = 0; i < meshData.indices.length; i++) {
                var index = meshData.indices[i];
                var uv = meshData.texture.coordinates.slice(2 * i, 2 * (i + 1));
                uvs.push(uv[0], uv[1]);
            }
            geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
        }
    }
    const c = meshData.colors;
    const material = new THREE.MeshPhongMaterial({
        side: THREE.DoubleSide,
        color:    new THREE.Color(c[0], c[1], c[2]),
        specular: new THREE.Color(c[3], c[4], c[5]),
        emissive: new THREE.Color(c[6], c[7], c[8]),
        map: texture
    });

    return new THREE.Mesh(geometry, material);
}

function onObjectAdded(e) {
    if(e.type == "shape") {
        if(e.meshData.length > 1) {
            meshes[e.handle] = new THREE.Group();
            for(var i = 0; i < e.meshData.length; i++) {
                meshes[e.handle].add(makeMesh(e.meshData[i]));
            }
        } else if(e.meshData.length == 1) {
            meshes[e.handle] = makeMesh(e.meshData[0]);
        }
        meshes[e.handle].userData = {handle: e.handle};
        scene.add(meshes[e.handle]);
    } else if(e.type == "camera" && e.absolutePose !== undefined) {
        var p = e.absolutePose.slice(0, 3);
        var q = e.absolutePose.slice(3);
        camera.position.x = p[0];
        camera.position.y = p[1];
        camera.position.z = p[2];
        camera.quaternion.x = q[0];
        camera.quaternion.y = q[1];
        camera.quaternion.z = q[2];
        camera.quaternion.w = q[3];
        //camera.updateProjectionMatrix();
        controls.update();
    }
}

function onObjectChanged(e) {
    var o = meshes[e.handle];
    if(o === undefined) return;

    if(e.name !== undefined) {
        o.name = e.name;
    }
    if(e.pose !== undefined) {
        o.position.x = e.pose[0];
        o.position.y = e.pose[1];
        o.position.z = e.pose[2];
        o.quaternion.x = e.pose[3];
        o.quaternion.y = e.pose[4];
        o.quaternion.z = e.pose[5];
        o.quaternion.w = e.pose[6];
    }
    if(e.visible !== undefined) {
        // can't change object visibility, as that would affect children too:
        //o.visible = e.visible;
        if(o.material !== undefined)
            o.material.visible = e.visible;
    }
    if(e.parent !== undefined) {
        if(meshes[e.parent] !== undefined) {
            meshes[e.parent].attach(o);
        } else /*if(e.parent === -1)*/ {
            scene.attach(o);
        }
    }
}

function onObjectRemoved(e) {
    if(meshes[e.handle] === undefined) return;
    scene.remove(meshes[e.handle]);
    delete meshes[e.handle];
}

var websocket = new WebSocket('ws://127.0.0.1:' + wsPort);
if(codec == 'cbor')
    websocket.binaryType = "arraybuffer";
websocket.onmessage = function(event) {
    var data = event.data;
    if(codec == "cbor")
        data = CBOR.decode(data);
    else if(codec == "json")
        data = JSON.parse(data);
    else {
        return;
    }
    if(data.event == "objectAdded") onObjectAdded(data);
    else if(data.event == "objectChanged") onObjectChanged(data);
    else if(data.event == "objectRemoved") onObjectRemoved(data);
}
]]
    end
end

function getObjectData(handle)
    local data={}
    data.name=sim.getObjectAlias(handle,0)
    data.parent=sim.getObjectParent(handle)
    data.pose=sim.getObjectPose(handle,data.parent)
    data.absolutePose=sim.getObjectPose(handle,-1)
    data.visible=sim.getObjectInt32Param(handle,sim.objintparam_visible)>0
    -- fetch type-specific data:
    local t=sim.getObjectType(handle)
    if t==sim.object_shape_type then
        --local _,o=sim.getShapeColor(handle,'',sim.colorcomponent_transparency)
        ---- XXX: opacity of compounds is always 0.5
        ---- XXX: sim.getShapeViz doesn't return opacity... maybe it should?
        --data.opacity=o
    elseif t==sim.object_joint_type then
        local st=sim.getJointType(handle)
        if st==sim_joint_revolute_subtype then
            data.subtype='revolute'
        elseif st==sim_joint_prismatic_subtype then
            data.subtype='prismatic'
        elseif st==sim_joint_spherical_subtype then
            data.subtype='spherical'
        end
        if st~=sim_joint_spherical_subtype then
            data.jointPosition=sim.getJointPosition(handle)
        else
            data.jointMatrix=sim.getJointMatrix(handle)
        end
    elseif t==sim.object_graph_type then
    elseif t==sim.object_camera_type then
    elseif t==sim.object_light_type then
    elseif t==sim.object_dummy_type then
    elseif t==sim.object_proximitysensor_type then
    elseif t==sim.object_octree_type then
    elseif t==sim.object_pointcloud_type then
    elseif t==sim.object_visionsensor_type then
    elseif t==sim.object_forcesensor_type then
    end
    return data
end

function objectDataChanged(a,b)
    local function poseChanged(a,b)
        if a==nil and b==nil then return false end
        local wl,wa=1,17.5
        local d=sim.getConfigDistance(a,b,{wl,wl,wl,wa,wa,wa,wa},{0,0,0,2,2,2,2})
        return d>0.0001
    end
    return false
        or poseChanged(a.pose,b.pose)
        or poseChanged(a.absolutePose,b.absolutePose)
        or a.parent~=b.parent
        or a.name~=b.name
end

function scan()
    localData={}
    for i,handle in ipairs(sim.getObjectsInTree(sim.handle_scene)) do
        localData[handle]=getObjectData(handle)
    end

    for handle,_ in pairs(remoteData) do
        if localData[handle]==nil then
            sendEvent(objectRemoved(handle))
            remoteData[handle]=nil
        end
    end

    for handle,data in pairs(localData) do
        if remoteData[handle]==nil then
            sendEvent(objectAdded(handle))
        end
    end

    for handle,data in pairs(localData) do
        if remoteData[handle]==nil or objectDataChanged(localData[handle],remoteData[handle]) then
            sendEvent(objectChanged(handle))
            remoteData[handle]=data
        end
    end
end

function objectAdded(handle)
    local data={
        event='objectAdded',
        handle=handle,
    }
    local t=sim.getObjectType(handle)
    if t==sim.object_shape_type then
        data.type="shape"
        data.meshData={}
        for i=0,1000 do
            local meshData=sim.getShapeViz(handle,i)
            if meshData==nil then break end
            if meshData.texture then
                local im=meshData.texture.texture
                local res=meshData.texture.resolution
                local imPNG=sim.saveImage(im,res,1,'.png',-1)
                meshData.texture.texture=base64.encode(imPNG)
            end
            table.insert(data.meshData,meshData)
        end
    elseif t== sim.object_joint_type then
        data.type="joint"
    elseif t==sim.object_graph_type then
        data.type="graph"
    elseif t==sim.object_camera_type then
        data.type="camera"
        -- XXX: trick for giving an initial position for the default frontend camera
        data.absolutePose=sim.getObjectPose(handle,-1)
    elseif t==sim.object_light_type then
        data.type="light"
    elseif t==sim.object_dummy_type then
        data.type="dummy"
    elseif t==sim.object_proximitysensor_type then
        data.type="proximitysensor"
    elseif t==sim.object_octree_type then
        data.type="octree"
    elseif t==sim.object_pointcloud_type then
        data.type="pointcloud"
        data.points=sim.getPointCloudPoints(handle)
    elseif t==sim.object_visionsensor_type then
        data.type="visionsensor"
    elseif t==sim.object_forcesensor_type then
        data.type="forcesensor"
    end
    return data
end

function objectRemoved(handle)
    local data={
        event='objectRemoved',
        handle=handle,
    }
    return data
end

function objectChanged(handle)
    local data={
        event='objectChanged',
        handle=handle,
    }
    for field,value in pairs(localData[handle]) do
        data[field]=value
    end
    return data
end

function sendEvent(d,conn)
    if verbose()>0 then
        print('Visualization stream:',d)
    end
    --d=encode(d)
    d=sim.packTable(d,1)
    if zmqPUBSocket then
        simZMQ.send(zmqPUBSocket,d,0)
    end
    if wsServer then
        for connection,_ in pairs(wsClients) do
            if conn==nil or conn==connection then
                simWS.send(wsServer,connection,d,opcode)
            end
        end
    end
end

function verbose()
    return tonumber(sim.getStringNamedParam('visualizationStream.verbose') or '0')
end
