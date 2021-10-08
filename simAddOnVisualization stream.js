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
const canvas = document.querySelector('#c');

canvas.addEventListener('mousedown', onMouseDown, false);
canvas.addEventListener('mouseup', onMouseUp, false);
canvas.addEventListener('mousemove', onMouseMove, false);
//canvas.addEventListener('click', onClick, false);
window.addEventListener('resize', onWindowResize);

THREE.Object3D.DefaultUp = new THREE.Vector3(0,0,1);

const scene = new THREE.Scene();

const ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
scene.add(ambientLight);

const light = new THREE.PointLight(0xffffff, 0.7);

const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.position.x = 1.12;
camera.position.y = -1.9;
camera.position.z = 1.08;
camera.rotation.x = 1.08;
camera.rotation.y = 0.64;
camera.rotation.z = 0.31;
camera.up.x = 0;
camera.up.y = 0;
camera.up.z = 1;
camera.add(light);
scene.add(camera); // required because the camera has a child

const renderer = new THREE.WebGLRenderer({canvas, alpha: true});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);

const orbitControls = new THREE.OrbitControls(camera, renderer.domElement);
orbitControls.addEventListener('change', render);

const raycaster = new THREE.Raycaster();
const bboxHelper = new THREE.BoxHelper(undefined, 0xffffff);
bboxHelper.visible = false;
scene.add(bboxHelper);

var selectedObject = null;

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

function render() {
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
	raycaster.setFromCamera({
        // normalized device coordinates (-1...+1)
        x: (event.clientX / window.innerWidth) * 2 - 1,
        y: -(event.clientY / window.innerHeight) * 2 + 1
    }, camera);
    const intersects = raycaster.intersectObjects(scene.children, true);
    var obj = null;
	for(let i = 0; i < intersects.length; i++) {
        if(intersects[i].object.userData.handle !== undefined) {
            obj = intersects[i].object;
            break;
        }
	}
    //setSelectedObject(obj);
}

function setSelectedObject(o) {
    if(o == null) {
        bboxHelper.visible = false;
        selectedObject = null;
    } else {
        selectedObject = o;
        bboxHelper.setFromObject(selectedObject);
        bboxHelper.visible = true;
    }
}

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
    //console.log("added", e);

    if(e.type == "shape") {
        if(e.meshData.length > 1) {
            meshes[e.handle] = new THREE.Group();
            for(var i = 0; i < e.meshData.length; i++) {
                meshes[e.handle].add(makeMesh(e.meshData[i]));
            }
        } else if(e.meshData.length == 1) {
            meshes[e.handle] = makeMesh(e.meshData[0]);
        }
        meshes[e.handle].userData = {handle: e.handle, type: e.type};
        scene.add(meshes[e.handle]);
    } else if(e.type == "pointcloud") {
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(e.points, 3));
        const material = new THREE.PointsMaterial({color: 0x0000FF, size: 0.005});
        meshes[e.handle] = new THREE.Points(geometry, material);
        scene.add(meshes[e.handle]);
    } else if(e.type == "dummy" || e.type == "forcesensor" || e.type == "joint") {
        meshes[e.handle] = new THREE.Group();
        meshes[e.handle].userData = {handle: e.handle, type: e.type};
        scene.add(meshes[e.handle]);
    } else if(e.type == "camera") {
        if(e.name == "DefaultCamera" && e.absolutePose !== undefined) {
            camera.position.x = e.absolutePose[0];
            camera.position.y = e.absolutePose[1];
            camera.position.z = e.absolutePose[2];
            camera.quaternion.x = e.absolutePose[3];
            camera.quaternion.y = e.absolutePose[4];
            camera.quaternion.z = e.absolutePose[5];
            camera.quaternion.w = e.absolutePose[6];
            //camera.updateProjectionMatrix();
            orbitControls.update();
        } else {
            meshes[e.handle] = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 1, 1000);
            meshes[e.handle].userData = {handle: e.handle, type: e.type};
            scene.add(meshes[e.handle]);
        }
    }
}

function setVisibility(o, v) {
    // can't change object visibility, as that would affect children too:
    //o.visible = e.visible;

    if(o.type === "Mesh" && o.material !== undefined)
        o.material.visible = v;
    else if(o.type === "Group")
        for(var child of o.children)
            setVisibility(child, v);
}

function onObjectChanged(e) {
    //console.log("changed", e, {self: meshes[e.handle], parent: meshes[e.parent]});

    var o = meshes[e.handle];
    if(o === undefined) return;

    if(e.name !== undefined) {
        o.name = e.name;
    }
    if(e.parent !== undefined) {
        if(meshes[e.parent] !== undefined) {
            meshes[e.parent].attach(o);
        } else /*if(e.parent === -1)*/ {
            scene.attach(o);
        }
    }
    if(e.pose !== undefined) {
        o.position.x = e.pose[0];
        o.position.y = e.pose[1];
        o.position.z = e.pose[2];
        o.quaternion.x = e.pose[3];
        o.quaternion.y = e.pose[4];
        o.quaternion.z = e.pose[5];
        o.quaternion.w = e.pose[6];
    } else if(e.absolutePose !== undefined) {
        o.position.x = e.absolutePose[0];
        o.position.y = e.absolutePose[1];
        o.position.z = e.absolutePose[2];
        o.quaternion.x = e.absolutePose[3];
        o.quaternion.y = e.absolutePose[4];
        o.quaternion.z = e.absolutePose[5];
        o.quaternion.w = e.absolutePose[6];
    }
    if(e.visible !== undefined) {
        setVisibility(o, e.visible);
    }
}

function onObjectRemoved(e) {
    if(meshes[e.handle] === undefined) return;
    scene.remove(meshes[e.handle]);
    delete meshes[e.handle];
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
        dispatchEvent(CBOR.decode(event.data));
    }
} else if(codec == "json") {
    websocket.onmessage = function(event) {
        dispatchEvent(JSON.parse(event.data));
    }
}
