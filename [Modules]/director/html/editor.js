/*  =========================================================================
    DIRECTOR — Scene Editor JavaScript

    Camera: middle mouse hold → camera control
    Timeline: scroll to zoom, drag to pan, click to set time
    FOV: scroll wheel (when not over timeline)
========================================================================= */

var scene = {
    name: 'untitled',
    duration: 30.0,
    camera: { keyframes: [] },
    entities: [],
    events: []
};

var selectedEntityId = null;
var isPreviewPlaying = false;
var camPollInterval = null;
var currentTimelineTime = 0;

// Timeline zoom/pan state
var tlZoom = 1.0;        // 1.0 = fit entire duration. Higher = zoomed in.
var tlScrollOffset = 0;  // seconds offset from left edge
var MIN_ZOOM = 1.0;
var MAX_ZOOM = 50.0;

// =========================================================================
// NUI COMMUNICATION
// =========================================================================

function nui(name, data) {
    return fetch('https://cfx-nui-director/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    })
    .then(function(r) { return r.text(); })
    .then(function(t) {
        if (!t) return { ok: false };
        try { return JSON.parse(t); } catch(e) { return { ok: false }; }
    })
    .catch(function() { return { ok: false }; });
}

// =========================================================================
// LUA → JS MESSAGES
// =========================================================================

window.addEventListener('message', function(e) {
    var d = e.data;
    if (!d || !d.action) return;

    switch (d.action) {
        case 'openEditor':
            scene = d.scene || scene;
            document.getElementById('editor').classList.remove('hidden');
            syncUI();
            startCamPoll();
            break;
        case 'closeEditor':
            document.getElementById('editor').classList.add('hidden');
            stopCamPoll();
            break;
        case 'sceneUpdated':
            scene = d.scene;
            syncUI();
            break;
        case 'sceneLoaded':
            scene = d.scene;
            tlZoom = 1.0;
            tlScrollOffset = 0;
            syncUI();
            toast('Scene loaded: ' + scene.name, 'success');
            document.getElementById('load-dialog').classList.add('hidden');
            break;
        case 'sceneSaved':
            toast(d.success ? ('Saved: ' + d.name) : 'Save failed', d.success ? 'success' : 'error');
            break;
        case 'sceneList':
            renderSceneList(d.scenes || []);
            break;
        case 'playbackTimeUpdate':
            updatePlayhead(d.time, d.duration);
            break;
        case 'previewEnded':
            exitPreviewMode();
            break;
    }
});

// =========================================================================
// MIDDLE MOUSE → CAMERA CONTROL
// =========================================================================

document.addEventListener('mousedown', function(e) {
    if (e.button === 1) { // middle mouse
        e.preventDefault();
        nui('director:middleMouseDown', {});
    }
});

document.addEventListener('mouseup', function(e) {
    if (e.button === 1) {
        e.preventDefault();
        nui('director:middleMouseUp', {});
    }
});

// Prevent middle-click default (auto-scroll)
document.addEventListener('auxclick', function(e) {
    if (e.button === 1) e.preventDefault();
});

// =========================================================================
// SCROLL WHEEL — FOV (global) or Timeline Zoom (when over timeline)
// =========================================================================

document.addEventListener('wheel', function(e) {
    var overTimeline = e.target.closest('#timeline-track, #timeline-ruler');

    if (overTimeline) {
        // Zoom timeline
        e.preventDefault();
        var oldZoom = tlZoom;

        if (e.deltaY < 0) {
            tlZoom = Math.min(MAX_ZOOM, tlZoom * 1.15);
        } else {
            tlZoom = Math.max(MIN_ZOOM, tlZoom / 1.15);
        }

        // Zoom toward mouse position
        var rect = document.getElementById('timeline-track').getBoundingClientRect();
        var mouseRatio = (e.clientX - rect.left) / rect.width;
        var visibleDur = getVisibleDuration();
        var mouseTime = tlScrollOffset + mouseRatio * (scene.duration / oldZoom);

        // Adjust offset so mouse time stays under cursor
        tlScrollOffset = mouseTime - mouseRatio * visibleDur;
        clampTimelineOffset();
        renderTimeline();
    } else {
        // FOV adjustment
        nui('director:scrollFov', { delta: e.deltaY > 0 ? 1 : -1 });
    }
}, { passive: false });

// =========================================================================
// SYNC ALL UI
// =========================================================================

function syncUI() {
    document.getElementById('scene-name').value = scene.name || 'untitled';
    document.getElementById('scene-duration').value = scene.duration || 30;
    document.getElementById('tl-duration').textContent = formatTime(scene.duration || 30);
    renderCamKeyframes();
    renderEntityList();
    renderTimeline();
}

// =========================================================================
// TIME FORMATTING
// =========================================================================

function formatTime(seconds) {
    var m = Math.floor(seconds / 60);
    var s = seconds % 60;
    if (m > 0) {
        return m + ':' + (s < 10 ? '0' : '') + s.toFixed(1);
    }
    return s.toFixed(1) + 's';
}

function formatTimeTick(seconds) {
    var m = Math.floor(seconds / 60);
    var s = Math.floor(seconds % 60);
    if (m > 0) {
        return m + ':' + (s < 10 ? '0' : '') + s;
    }
    return s + 's';
}

// =========================================================================
// TIMELINE — ZOOM, PAN, TICKS, MARKERS
// =========================================================================

function getVisibleDuration() {
    return (scene.duration || 30) / tlZoom;
}

function clampTimelineOffset() {
    var maxOffset = Math.max(0, (scene.duration || 30) - getVisibleDuration());
    tlScrollOffset = Math.max(0, Math.min(maxOffset, tlScrollOffset));
}

function timeToPercent(time) {
    var visDur = getVisibleDuration();
    return ((time - tlScrollOffset) / visDur) * 100;
}

function percentToTime(pct) {
    return tlScrollOffset + (pct / 100) * getVisibleDuration();
}

function renderTimeline() {
    renderTimelineRuler();
    renderTimelineMarkers();
    updatePlayhead(currentTimelineTime, scene.duration);
}

function renderTimelineRuler() {
    var ruler = document.getElementById('timeline-ruler');
    ruler.innerHTML = '';

    var visDur = getVisibleDuration();
    var dur = scene.duration || 30;

    // Choose tick interval based on zoom level
    var tickInterval;
    if (visDur <= 5) tickInterval = 0.5;
    else if (visDur <= 15) tickInterval = 1;
    else if (visDur <= 30) tickInterval = 2;
    else if (visDur <= 60) tickInterval = 5;
    else if (visDur <= 180) tickInterval = 10;
    else if (visDur <= 600) tickInterval = 30;
    else tickInterval = 60;

    // Find first tick in view
    var firstTick = Math.ceil(tlScrollOffset / tickInterval) * tickInterval;

    for (var t = firstTick; t <= tlScrollOffset + visDur; t += tickInterval) {
        if (t < 0 || t > dur) continue;
        var pct = timeToPercent(t);
        if (pct < -1 || pct > 101) continue;

        var tick = document.createElement('div');
        tick.className = 'ruler-tick';
        tick.style.left = pct + '%';

        var label = document.createElement('span');
        label.className = 'ruler-label';
        label.textContent = formatTimeTick(t);
        tick.appendChild(label);

        ruler.appendChild(tick);

        // Sub-ticks (minor)
        if (tickInterval >= 2) {
            var subInterval = tickInterval / 2;
            var subT = t + subInterval;
            if (subT <= tlScrollOffset + visDur && subT <= dur) {
                var subPct = timeToPercent(subT);
                if (subPct >= 0 && subPct <= 100) {
                    var sub = document.createElement('div');
                    sub.className = 'ruler-tick minor';
                    sub.style.left = subPct + '%';
                    ruler.appendChild(sub);
                }
            }
        }
    }
}

function renderTimelineMarkers() {
    var markers = document.getElementById('timeline-markers');
    markers.innerHTML = '';

    // Camera keyframes
    var kfs = scene.camera ? scene.camera.keyframes : [];
    for (var i = 0; i < kfs.length; i++) {
        var pct = timeToPercent(kfs[i].time);
        if (pct < -2 || pct > 102) continue;
        var m = document.createElement('div');
        m.className = 'tl-marker cam';
        m.style.left = pct + '%';
        m.title = 'Cam @ ' + kfs[i].time.toFixed(1) + 's';
        markers.appendChild(m);
    }

    // Entity keyframes
    var ents = scene.entities || [];
    for (var e = 0; e < ents.length; e++) {
        var ekfs = ents[e].keyframes || [];
        for (var k = 0; k < ekfs.length; k++) {
            var pct = timeToPercent(ekfs[k].time);
            if (pct < -2 || pct > 102) continue;
            var m = document.createElement('div');
            m.className = 'tl-marker entity';
            m.style.left = pct + '%';
            m.title = ents[e].id + ' @ ' + ekfs[k].time.toFixed(1) + 's';
            markers.appendChild(m);
        }
    }
}

function updatePlayhead(time, duration) {
    currentTimelineTime = time;
    var pct = timeToPercent(time);
    pct = Math.max(-1, Math.min(101, pct));
    document.getElementById('timeline-playhead').style.left = pct + '%';
    document.getElementById('tl-time').textContent = formatTime(time);
}

// Timeline drag to pan
var tlDragging = false;
var tlDragStartX = 0;
var tlDragStartOffset = 0;

document.getElementById('timeline-track').addEventListener('mousedown', function(e) {
    if (e.button === 0) {
        // Left click: set playhead time
        var rect = this.getBoundingClientRect();
        var pct = ((e.clientX - rect.left) / rect.width) * 100;
        currentTimelineTime = Math.max(0, percentToTime(pct));
        updatePlayhead(currentTimelineTime, scene.duration);
    } else if (e.button === 2) {
        // Right click: start drag to pan
        e.preventDefault();
        tlDragging = true;
        tlDragStartX = e.clientX;
        tlDragStartOffset = tlScrollOffset;
    }
});

document.addEventListener('mousemove', function(e) {
    if (!tlDragging) return;
    var rect = document.getElementById('timeline-track').getBoundingClientRect();
    var dx = e.clientX - tlDragStartX;
    var pxPerSecond = rect.width / getVisibleDuration();
    tlScrollOffset = tlDragStartOffset - (dx / pxPerSecond);
    clampTimelineOffset();
    renderTimeline();
});

document.addEventListener('mouseup', function(e) {
    if (e.button === 2 && tlDragging) {
        tlDragging = false;
    }
});

// Prevent context menu on timeline
document.getElementById('timeline-track').addEventListener('contextmenu', function(e) {
    e.preventDefault();
});

// =========================================================================
// CAMERA KEYFRAMES (RIGHT PANEL)
// =========================================================================

function renderCamKeyframes() {
    var list = document.getElementById('cam-kf-list');
    var kfs = scene.camera ? scene.camera.keyframes : [];
    list.innerHTML = '';

    if (kfs.length === 0) {
        list.innerHTML = '<div class="empty-hint">No keyframes. Position camera and click + KF.</div>';
        return;
    }

    for (var i = 0; i < kfs.length; i++) {
        var kf = kfs[i];
        var item = document.createElement('div');
        item.className = 'list-item';
        item.innerHTML =
            '<span class="item-time">' + formatTime(kf.time) + '</span>' +
            '<span class="item-label">fov ' + (kf.fov || 50).toFixed(0) + ' · ' + (kf.easing || 'linear') + '</span>' +
            '<span class="item-delete" data-idx="' + i + '">×</span>';
        item.setAttribute('data-idx', i);
        item.onclick = onCamKfClick;
        list.appendChild(item);
    }
}

function onCamKfClick(e) {
    if (e.target.classList.contains('item-delete')) {
        var idx = parseInt(e.target.getAttribute('data-idx'));
        nui('director:deleteCameraKeyframe', { index: idx + 1 });
        return;
    }
    var idx = parseInt(this.getAttribute('data-idx'));
    nui('director:gotoCameraKeyframe', { index: idx + 1 });
}

// =========================================================================
// ENTITY LIST (LEFT PANEL)
// =========================================================================

function renderEntityList() {
    var list = document.getElementById('entity-list');
    var ents = scene.entities || [];
    list.innerHTML = '';

    if (ents.length === 0) {
        list.innerHTML = '<div class="empty-hint">No entities. Click + to add.</div>';
        return;
    }

    for (var i = 0; i < ents.length; i++) {
        var ent = ents[i];
        var item = document.createElement('div');
        item.className = 'list-item' + (ent.id === selectedEntityId ? ' selected' : '');
        item.innerHTML =
            '<span class="item-label">' + esc(ent.id) + '</span>' +
            '<span class="item-badge">' + ent.type + '</span>' +
            '<span class="item-delete" data-id="' + esc(ent.id) + '">×</span>';
        item.setAttribute('data-id', ent.id);
        item.onclick = onEntityClick;
        list.appendChild(item);
    }
}

function onEntityClick(e) {
    if (e.target.classList.contains('item-delete')) {
        nui('director:removeEntity', { id: e.target.getAttribute('data-id') });
        if (selectedEntityId === e.target.getAttribute('data-id')) selectedEntityId = null;
        return;
    }
    selectedEntityId = this.getAttribute('data-id');
    renderEntityList();
}

// =========================================================================
// CAMERA POLLING
// =========================================================================

function startCamPoll() {
    stopCamPoll();
    camPollInterval = setInterval(function() {
        nui('director:getCamState', {}).then(function(r) {
            if (!r.ok) return;
            document.getElementById('cam-x').textContent = r.pos.x.toFixed(1);
            document.getElementById('cam-y').textContent = r.pos.y.toFixed(1);
            document.getElementById('cam-z').textContent = r.pos.z.toFixed(1);
            document.getElementById('cam-fov').textContent = r.fov.toFixed(1);
        });
    }, 250);
}

function stopCamPoll() {
    if (camPollInterval) { clearInterval(camPollInterval); camPollInterval = null; }
}

// =========================================================================
// PREVIEW
// =========================================================================

function enterPreviewMode() {
    isPreviewPlaying = true;
    document.getElementById('btn-preview').classList.add('hidden');
    document.getElementById('btn-stop').classList.remove('hidden');
    stopCamPoll();
    nui('director:preview', {});
}

function exitPreviewMode() {
    isPreviewPlaying = false;
    document.getElementById('btn-preview').classList.remove('hidden');
    document.getElementById('btn-stop').classList.add('hidden');
    startCamPoll();
    updatePlayhead(0, scene.duration);
}

// =========================================================================
// LOAD DIALOG
// =========================================================================

function renderSceneList(scenes) {
    var list = document.getElementById('scene-file-list');
    list.innerHTML = '';
    if (scenes.length === 0) {
        list.innerHTML = '<div class="empty-hint">No saved scenes.</div>';
    }
    for (var i = 0; i < scenes.length; i++) {
        var item = document.createElement('div');
        item.className = 'list-item';
        item.innerHTML = '<span class="item-label">' + esc(scenes[i]) + '</span>';
        item.setAttribute('data-name', scenes[i]);
        item.onclick = function() {
            nui('director:loadScene', { name: this.getAttribute('data-name') });
        };
        list.appendChild(item);
    }
    document.getElementById('load-dialog').classList.remove('hidden');
}

// =========================================================================
// ADD ENTITY FORM
// =========================================================================

function showAddEntityForm() {
    document.getElementById('add-entity-form').classList.remove('hidden');
    document.getElementById('new-entity-id').value = '';
    document.getElementById('new-entity-model').value = '';
}

function hideAddEntityForm() {
    document.getElementById('add-entity-form').classList.add('hidden');
}

function confirmAddEntity() {
    var id = document.getElementById('new-entity-id').value.trim();
    var type = document.getElementById('new-entity-type').value;
    var model = document.getElementById('new-entity-model').value.trim();
    if (!id || !model) { toast('ID and Model required', 'error'); return; }

    nui('director:addEntity', { id: id, type: type, model: model }).then(function(r) {
        if (r.ok) { hideAddEntityForm(); toast('Entity added: ' + id, 'success'); }
        else { toast(r.message || 'Failed', 'error'); }
    });
}

// =========================================================================
// TOAST
// =========================================================================

var toastTimeout = null;
function toast(msg, type) {
    var el = document.getElementById('toast');
    el.textContent = msg;
    el.className = 'toast' + (type ? ' ' + type : '');
    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(function() { el.classList.add('hidden'); }, 3000);
}

// =========================================================================
// UTIL
// =========================================================================

function esc(s) {
    if (!s) return '';
    var d = document.createElement('div');
    d.appendChild(document.createTextNode(s));
    return d.innerHTML;
}

// =========================================================================
// BUTTON HANDLERS
// =========================================================================

document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('btn-close').onclick = function() { nui('director:close', {}); };

    document.getElementById('btn-save').onclick = function() {
        scene.name = document.getElementById('scene-name').value.trim() || 'untitled';
        scene.duration = parseFloat(document.getElementById('scene-duration').value) || 30;
        nui('director:updateScene', { name: scene.name, duration: scene.duration });
        nui('director:saveScene', {});
    };

    document.getElementById('btn-load').onclick = function() { nui('director:listScenes', {}); };
    document.getElementById('btn-preview').onclick = enterPreviewMode;
    document.getElementById('btn-stop').onclick = function() {
        nui('director:stopPreview', {});
        exitPreviewMode();
    };

    document.getElementById('btn-add-cam-kf').onclick = function() {
        nui('director:addCameraKeyframe', { time: currentTimelineTime, easing: 'ease-in-out' });
    };

    document.getElementById('cam-speed').oninput = function() {
        document.getElementById('cam-speed-val').textContent = parseFloat(this.value).toFixed(1);
    };

    document.getElementById('btn-add-entity').onclick = showAddEntityForm;
    document.getElementById('btn-confirm-entity').onclick = confirmAddEntity;
    document.getElementById('btn-cancel-entity').onclick = hideAddEntityForm;

    document.getElementById('btn-cancel-load').onclick = function() {
        document.getElementById('load-dialog').classList.add('hidden');
    };

    document.getElementById('scene-name').onchange = function() {
        scene.name = this.value.trim() || 'untitled';
        nui('director:updateScene', { name: scene.name });
    };

    document.getElementById('scene-duration').onchange = function() {
        scene.duration = parseFloat(this.value) || 30;
        nui('director:updateScene', { duration: scene.duration });
        document.getElementById('tl-duration').textContent = formatTime(scene.duration);
        tlZoom = 1.0;
        tlScrollOffset = 0;
        renderTimeline();
    };
});

// Escape to close
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        nui('director:close', {});
    }
});
