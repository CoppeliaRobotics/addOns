if(typeof Element.prototype.clearChildren === 'undefined') {
    Object.defineProperty(Element.prototype, 'clearChildren', {
        configurable: true,
        enumerable: false,
        value: function() {
            while(this.firstChild)
                this.removeChild(this.lastChild);
        }
    });
}

const objtree = document.querySelector('#objtree');
const viewCanvas = document.querySelector('#view');
const axesCanvas = document.querySelector('#axes');
const debugDiv = document.querySelector('#debug');

viewCanvas.addEventListener('mousedown', onMouseDown, false);
viewCanvas.addEventListener('mouseup', onMouseUp, false);
viewCanvas.addEventListener('mousemove', onMouseMove, false);
//viewCanvas.addEventListener('click', onClick, false);
window.addEventListener('resize', onWindowResize);
window.addEventListener('keydown', onKeyDown);

function onKeyDown(event) {
    switch(event.code) {
        case 'KeyH':
            $("#objtreeBG").toggle();
            break;
        case 'KeyD':
            $("#debug").toggle();
            break;
        case 'Escape':
            setSelectPointMode(false);
            transformControlsDisable();
            if(selectedObject !== null) {
                transformControlsDetach();
            }
            break;
        case 'KeyT':
            setSelectPointMode(false);
            transformControlsEnable();
            transformControlsMode('translate');
            if(selectedObject !== null) {
                transformControlsAttach(selectedObject);
            }
            break;
        case 'KeyR':
            setSelectPointMode(false);
            transformControlsEnable();
            transformControlsMode('rotate');
            if(selectedObject !== null) {
                transformControlsAttach(selectedObject);
            }
            break;
        case 'KeyP':
            transformControlsDetach();
            setSelectPointMode(true);
            break;
    }
}

function debug(text) {
    if(text !== undefined)
        console.log(text);
    if(typeof text === 'string' || text instanceof String) {
        debugDiv.innerText = text;
    } else {
        debug(JSON.stringify(text, undefined, 2));
    }
}

THREE.Object3D.DefaultUp = new THREE.Vector3(0,0,1);

const scene = new THREE.Scene();

const ambientLight = new THREE.AmbientLight(0xffffff, 0.7);
scene.add(ambientLight);

const light = new THREE.PointLight(0xffffff, 0.3);

const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.position.set(1.12, -1.9, 1.08);
camera.rotation.set(1.08, 0.64, 0.31);
camera.up.set(0, 0, 1);
camera.add(light);
scene.add(camera); // required because the camera has a child

const renderer = new THREE.WebGLRenderer({canvas: viewCanvas, alpha: true});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);

const orbitControls = new THREE.OrbitControls(camera, renderer.domElement);
orbitControls.addEventListener('change', render);

const transformControls = new THREE.TransformControls(camera, renderer.domElement);
transformControls.enabled = false;
transformControls.addEventListener('change', function(event) {
    bboxHelper.update();
    render();
});
transformControls.addEventListener('dragging-changed', function(event) {
    // disable orbit controls while dragging:
    orbitControls.enabled = !event.value;

    if(event.value)
        transformControlsStartTransform();
    else
        transformControlsEndTransform();
});
scene.add(transformControls);

const raycaster = new THREE.Raycaster();
const bboxHelper = new THREE.BoxHelper(undefined, 0xffffff);
bboxHelper.visible = false;
scene.add(bboxHelper);

const axesScene = new THREE.Scene();
const axesHelper = new THREE.AxesHelper(20);
axesScene.add(axesHelper);
const axesRenderer = new THREE.WebGLRenderer({canvas: axesCanvas, alpha: true});
axesRenderer.setPixelRatio(window.devicePixelRatio);
axesRenderer.setSize(80, 80);
const axesCamera = new THREE.PerspectiveCamera(40, axesCanvas.width / axesCanvas.height, 1, 1000);
axesCamera.up = camera.up;
axesScene.add(axesCamera);

var selectPointMode = false;
var selectedPointConfirmed = false;
var selectedObject = null;

updateTreeTimeout = undefined;

var mouse = {
    dragStart: {x: 0, y: 0},
    dragDelta: function(e) {
        return {
            x: event.clientX - mouse.dragStart.x,
            y: event.clientY - mouse.dragStart.y
        };
    },
    pos: {x: 0, y: 0},
    clickDragTolerance: 1
};

const selectPointSphere = new THREE.Mesh(
    new THREE.SphereGeometry(0.01, 8, 4),
    new THREE.MeshBasicMaterial({color: 0xff0000})
);
selectPointSphere.visible = false;
scene.add(selectPointSphere);

const selectPointArrow = new THREE.ArrowHelper(
    new THREE.Vector3(0, 0, 1),
    new THREE.Vector3(0, 0, 0),
    0.2,
    0xff0000
);
selectPointArrow.visible = false;
scene.add(selectPointArrow);

function isObjectPickable(o) {
    if(o.visible === false)
        return null;
    if(o.userData.uid !== undefined)
        return o;
    var sm = o.userData.supermeshUid;
    if(sm !== undefined) {
        if(meshes[sm] !== undefined) {
            if(meshes[sm].userData.visible) {
                return meshes[sm];
            }
        } else {
            console.log(`found an intersect but supermeshUid ${sm} is not known`);
        }
    }
    return null;
}

function showSurfacePoint(intersect) {
    intersect.object.updateMatrixWorld();
    //intersect.object.updateWorldMatrix(true, false);
    selectPointSphere.position.copy(intersect.point);
    selectPointSphere.visible = true;
    // normal is local, convert it to global:
    var normalMatrix = new THREE.Matrix3().getNormalMatrix(intersect.object.matrixWorld);
    var normal = intersect.face.normal.clone().applyMatrix3(normalMatrix).normalize();
    selectPointArrow.setDirection(normal);
    selectPointArrow.position.copy(intersect.point);
    selectPointArrow.visible = true;
}

function render() {
    if(selectPointMode) {
        raycaster.setFromCamera({
            // normalized device coordinates (-1...+1)
            x: (mouse.pos.x / window.innerWidth) * 2 - 1,
            y: -(mouse.pos.y / window.innerHeight) * 2 + 1
        }, camera);
        const intersects = raycaster.intersectObjects(scene.children, true);
        for(let i = 0; i < intersects.length; i++) {
            var obj = isObjectPickable(intersects[i].object);
            if(obj !== null) {
                showSurfacePoint(intersects[i]);
                break;
            }
        }
    }

    axesCamera.position.subVectors(camera.position, orbitControls.target);
    axesCamera.position.setLength(50);
    axesCamera.lookAt(axesScene.position);

    axesRenderer.render(axesScene, axesCamera);
	renderer.render(scene, camera);
}

function animate() {
	requestAnimationFrame(animate);
    orbitControls.update();
    render();
}
animate(0);

function onMouseDown(event) {
    mouse.dragStart.x = event.clientX;
    mouse.dragStart.y = event.clientY;
}

function onMouseUp(event) {
    var d = mouse.dragDelta();
    if(Math.hypot(d.x, d.y) <= mouse.clickDragTolerance)
        onClick(event);
}

function onMouseMove(event) {
    mouse.pos.x = event.clientX;
    mouse.pos.y = event.clientY;
}

function onClick(event) {
    if(selectPointMode) {
        selectedPointConfirmed = true;

        setSelectPointMode(false);
        transformControlsDisable();
        if(selectedObject !== null) {
            transformControlsDetach();
        }
        return;
    }

	raycaster.setFromCamera({
        // normalized device coordinates (-1...+1)
        x: (event.clientX / window.innerWidth) * 2 - 1,
        y: -(event.clientY / window.innerHeight) * 2 + 1
    }, camera);
    const intersects = raycaster.intersectObjects(scene.children, true);
    var obj = null;
	for(let i = 0; i < intersects.length; i++) {
        obj = isObjectPickable(intersects[i].object);
        if(obj !== null) break;
	}
    setSelectedObject(obj, true);
}

function transformControlsEnable() {
    transformControls.enabled = true;
}

function transformControlsDisable() {
    transformControls.enabled = false;
}

function transformControlsMode(mode) {
    transformControls.setMode(mode);
}

function transformControlsAttach(obj) {
    if(obj === null || obj === undefined) return;

    var clone = obj.clone(true);
    if(clone.material !== undefined) {
        clone.material = obj.material.clone();
        clone.material.transparent = true;
        clone.material.opacity = 0.4;
    }

    delete clone.userData.uid;

    obj.parent.add(clone);

    obj.userData.clone = clone;
    clone.userData.original = obj;

    bboxHelper.setFromObject(clone);

    transformControls.attach(clone);
}

function transformControlsStartTransform() {
}

function transformControlsEndTransform() {
    var clone = transformControls.object;
    var obj = clone.userData.original;
    /* (original object will change as the result of synchronization)
    obj.position.copy(clone.position);
    obj.quaternion.copy(clone.quaternion);
    */
    var p = clone.position.toArray();
    var q = clone.quaternion.toArray();
    sim.setObjectPose([obj.userData.handle, sim.handle_parent, p.concat(q)], function(e) {});
}

function transformControlsDetach() {
    if(transformControls.object === undefined)
        return; // was not attached

    var clone = transformControls.object;
    var obj = clone.userData.original;

    //obj.userData.uid = clone.userData.uid;

    clone.removeFromParent();

    delete clone.userData.original;
    delete obj.userData.clone;

    bboxHelper.setFromObject(obj);

    transformControls.detach();
}

function findModelBase(o, followSMBI) {
    if(o === null) return null;
    if(o.userData.modelBase && !o.userData.selectModelBaseInstead) {
        return o;
    } else {
        return findModelBase(o.parent);
    }
}

function setSelectedObject(o, followSMBI) {
    if(selectedObject !== null && selectedObject.userData.treeElement !== undefined) {
        $(selectedObject.userData.treeElement).removeClass('selected');
    }

    if(o == null) {
        bboxHelper.visible = false;
        selectedObject = null;
        transformControlsDetach();
    } else {
        if(followSMBI && o.userData.selectModelBaseInstead) {
            var modelBase = findModelBase(o);
            if(modelBase !== null)
                o = modelBase;
        }

        debug(`id = ${o.id}`);
        selectedObject = o;
        if(selectedObject.userData.treeElement !== undefined) {
            $(selectedObject.userData.treeElement).addClass('selected');
        }
        bboxHelper.setFromObject(selectedObject);
        bboxHelper.visible = true;
        if(transformControls.object !== undefined) {
            transformControlsDetach();
            transformControlsAttach(selectedObject);
        } else if(transformControls.enabled) {
            transformControlsAttach(selectedObject);
        }
    }
}

function setSelectPointMode(enable) {
    selectPointMode = enable;
    if(enable) {
        selectedPointConfirmed = false;
    } else {
        if(!selectedPointConfirmed) {
            selectPointSphere.visible = false;
            selectPointArrow.visible = false;
        }
    }
}

function onWindowResize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
}

// handle updates from CoppeliaSim:

var remoteApiClient = new RemoteAPIClient();
var sim = null;
remoteApiClient.websocket.addEventListener('open', function(event) {
    remoteApiClient.getObject('sim', function(o) { sim = o; });
});

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
    if(meshData.transparency !== undefined && meshData.transparency > 0.001) {
        material.transparent = true;
        material.opacity = 1 - meshData.transparency;
    }

    return new THREE.Mesh(geometry, material);
}

function setCommonUserData(o, e) {
    o.userData = {
        uid: e.uid,
        type: e.type,
        handle: e.handle,
        modelBase: e.modelBase,
        selectModelBaseInstead: e.selectModelBaseInstead
    };
}

function onObjectAdded(e) {
    //console.log("added", e);

    if(e.type == "shape") {
        if(e.meshData.length > 1) {
            meshes[e.uid] = new THREE.Group();
            for(var i = 0; i < e.meshData.length; i++) {
                var submesh = makeMesh(e.meshData[i]);
                submesh.userData.supermeshUid = e.uid;
                meshes[e.uid].add(submesh);
            }
        } else if(e.meshData.length == 1) {
            meshes[e.uid] = makeMesh(e.meshData[0]);
        }
        setCommonUserData(meshes[e.uid], e);
        meshes[e.uid].visible = false;
        scene.add(meshes[e.uid]);
    } else if(e.type == "pointcloud") {
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(e.points, 3));
        const material = new THREE.PointsMaterial({color: 0x0000FF, size: 0.005});
        meshes[e.uid] = new THREE.Points(geometry, material);
        meshes[e.uid].visible = false;
        scene.add(meshes[e.uid]);
    } else if(e.type == "dummy" || e.type == "forcesensor") {
        meshes[e.uid] = new THREE.Group();
        setCommonUserData(meshes[e.uid], e);
        scene.add(meshes[e.uid]);
    } else if(e.type == "joint") {
        var jf = new THREE.Group();
        meshes[e.uid] = new THREE.Group();
        meshes[e.uid].add(jf);
        setCommonUserData(meshes[e.uid], e);
        meshes[e.uid].userData.jointFrameId = jf.id;
        scene.add(meshes[e.uid]);
    } else if(e.type == "camera") {
        if(e.name == "DefaultCamera" && e.absolutePose !== undefined) {
            camera.position.set(e.absolutePose[0], e.absolutePose[1], e.absolutePose[2]);
            camera.quaternion.set(e.absolutePose[3], e.absolutePose[4], e.absolutePose[5], e.absolutePose[6]);
            //camera.updateProjectionMatrix();
            orbitControls.update();
        } else {
            meshes[e.uid] = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 1, 1000);
            setCommonUserData(meshes[e.uid], e);
            scene.add(meshes[e.uid]);
        }
    }

    if(updateTreeTimeout !== undefined)
        clearTimeout(updateTreeTimeout);
    updateTreeTimeout = setTimeout(updateTree, 1000);
}

function getSceneHierarchy(o) {
    var r = [
        {
            n: o === scene ? "SCENE" : o.name,
            t: o.type
        }
    ];
    if(o.children !== undefined) {
        for(var c of o.children) {
            if(c.userData.uid !== undefined)
                r.push(getSceneHierarchy(c));
        }
    }
    return r;
}

function updateTree(o) {
    if(o === undefined) {
        objtree.clearChildren();
        objtree.appendChild(updateTree(scene));
    } else {
        var li = document.createElement('li');
        var icon = document.createElement('i');
        icon.classList.add('tree-item-icon');
        icon.classList.add('fas');
        if(o.type == "Scene") {
            icon.classList.add('fa-globe');
        } else if(o.userData.type == "camera") {
            icon.classList.add('fa-video');
        } else if(o.userData.type == "shape") {
            icon.classList.add('fa-cubes');
        } else if(o.userData.type == "light") {
            icon.classList.add('fa-lightbulb');
        } else if(o.userData.type == "joint") {
            icon.classList.add('fa-cogs');
        } else if(o.userData.type == "dummy") {
            icon.classList.add('fa-bullseye');
        } else {
            icon.classList.add('fa-question');
        }
        var nameLabel = document.createElement('span');
        nameLabel.classList.add("tree-item");
        nameLabel.appendChild(document.createTextNode(" " +
            (o === scene ? "(scene)" : o.name)
        ));
        nameLabel.addEventListener('click', function() {
            setSelectedObject(o, false);
        });
        o.userData.treeElement = nameLabel;
        var hasChildren = false;
        var childrenContainer = o;
        if(o.userData.type === "joint" && o.userData.jointFrameId !== undefined) {
            childrenContainer = scene.getObjectById(o.userData.jointFrameId);
            if(childrenContainer === undefined) {
                console.log(`invalid joint frame id ${o.userData.jointFrameId} for object id ${o.id}`, o);
            }
        }
        for(var c of childrenContainer.children) {
            if(c.userData.uid !== undefined) {
                hasChildren = true;
                break;
            }
        }
        if(hasChildren) {
            var ul = document.createElement('ul');
            ul.classList.add('active');
            for(var c of childrenContainer.children)
                if(c.userData.uid !== undefined)
                    ul.appendChild(updateTree(c));
            var toggler = document.createElement('span');
            toggler.classList.add('toggler');
            toggler.classList.add('toggler-open');
            toggler.addEventListener('click', function() {
                ul.classList.toggle('active');
                toggler.classList.toggle('toggler-open');
                toggler.classList.toggle('toggler-close');
            });
            li.appendChild(toggler);
            li.appendChild(icon);
            li.appendChild(nameLabel);
            li.appendChild(ul);
        } else {
            li.appendChild(icon);
            li.appendChild(nameLabel);
        }
        return li;
    }
}

function setPropertyRecursive(o, p, v) {
    if(typeof p === 'string' || p instanceof String) {
        if(o[p] !== undefined)
            o[p] = v;
    } else if(Array.isArray(p)) {
        if(p.length > 0) {
            var objref = o;
            for(var i = 0; i < (p.length - 1); i++) {
                if(objref === undefined) break;
                objref = objref[p[i]];
            }
            if(objref !== undefined)
                objref[p[p.length - 1]] = v;
        }
    } else {
        return;
    }
    if(o.children !== undefined)
        for(var c of o.children)
            setPropertyRecursive(c,p,v);
}

function onObjectChanged(e) {
    //console.log("changed", e, {self: meshes[e.uid], parent: meshes[e.parentUid]});

    var o = meshes[e.uid];
    if(o === undefined) return;

    o.visible = true;

    if(e.name !== undefined) {
        o.name = e.name;
    }
    if(e.parentUid !== undefined) {
        var p = meshes[e.parentUid];
        if(p !== undefined) {
            if(p.userData.jointFrameId !== undefined) {
                // when parenting to a joint, attach to joint child frame:
                var jf = scene.getObjectById(p.userData.jointFrameId);
                if(jf !== undefined) {
                    jf.attach(o);
                } else {
                    console.log(`joint frame with id=${p.userData.jointFrameId} not known`);
                }
            } else {
                p.attach(o);
            }
        } else /*if(e.parentUid === -1)*/ {
            if(e.parentUid !== -1)
                console.log(`parent with uid=${e.parentUid} not known`);
            scene.attach(o);
        }
    }
    if(e.pose !== undefined) {
        o.position.set(e.pose[0], e.pose[1], e.pose[2]);
        o.quaternion.set(e.pose[3], e.pose[4], e.pose[5], e.pose[6]);
    } else if(e.absolutePose !== undefined) {
        o.position.set(e.absolutePose[0], e.absolutePose[1], e.absolutePose[2]);
        o.quaternion.set(e.absolutePose[3], e.absolutePose[4], e.absolutePose[5], e.absolutePose[6]);
    }
    if(e.jointPose !== undefined) {
        if(o.userData.jointFrameId !== undefined) {
            var jf = scene.getObjectById(o.userData.jointFrameId);
            jf.position.set(e.jointPose[0], e.jointPose[1], e.jointPose[2]);
            jf.quaternion.set(e.jointPose[3], e.jointPose[4], e.jointPose[5], e.jointPose[6]);
        }
    }
    if(e.visible !== undefined) {
        if(o.type === "Mesh") {
            o.layers.set(e.visible ? 0 : 1);
        } else if(o.type === "Group") {
            for(var child of o.children)
                if(child.userData.supermeshUid == o.userData.uid)
                    child.layers.set(e.visible ? 0 : 1);
        }
        o.userData.visible = e.visible;
    }
    if(e.handle !== undefined) {
        o.userData.handle = e.handle;
    }

    if(updateTreeTimeout !== undefined)
        clearTimeout(updateTreeTimeout);
    updateTreeTimeout = setTimeout(updateTree, 1000);
}

function onObjectRemoved(e) {
    if(meshes[e.uid] === undefined) return;

    if(meshes[e.uid] === selectedObject)
        setSelectedObject(null, false);

    scene.remove(meshes[e.uid]);
    delete meshes[e.uid];

    if(updateTreeTimeout !== undefined)
        clearTimeout(updateTreeTimeout);
    updateTreeTimeout = setTimeout(updateTree, 1000);
}

function dispatchEvents(events) {
    if(events.length !== undefined)
        for(var event of events)
            dispatchEvent(event);
    else if(events.event !== undefined)
        dispatchEvent(events);
}

function dispatchEvent(e) {
    if(e.event == "objectAdded")
        onObjectAdded(e);
    else if(e.event == "objectChanged")
        onObjectChanged(e);
    else if(e.event == "objectRemoved")
        onObjectRemoved(e);
}

var websocket = new WebSocket('ws://localhost:' + wsPort);
if(codec == 'cbor') {
    websocket.binaryType = "arraybuffer";
    websocket.onmessage = function(event) {
        dispatchEvents(CBOR.decode(event.data));
    }
} else if(codec == "json") {
    websocket.onmessage = function(event) {
        dispatchEvents(JSON.parse(event.data));
    }
}
