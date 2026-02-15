/*
    Character Selection JavaScript

    RECEIVING from Lua:  window.addEventListener('message', ...)
    SENDING to Lua:      fetch(`https://cfx-nui-player/callbackName`, ...)
*/

let characters = [];
let maxCharacters = 3;
let deleteTargetId = null;

// =========================================================================
// RECEIVING MESSAGES FROM LUA (via SendNUIMessage)
// =========================================================================

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'showCharacterSelect':
            characters = data.characters || [];
            maxCharacters = data.maxCharacters || 3;
            renderCharacters();
            showApp();
            break;

        case 'updateCharacters':
            characters = data.characters || [];
            renderCharacters();
            break;

        case 'hide':
            hideApp();
            break;
    }
});

// =========================================================================
// SENDING MESSAGES TO LUA (via RegisterNUICallback)
// =========================================================================

async function nuiCallback(callbackName, data) {
    try {
        const response = await fetch('https://cfx-nui-player/' + callbackName, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        });
        return await response.json();
    } catch (err) {
        console.error('NUI callback error:', err);
        return { ok: false, message: 'Communication error' };
    }
}

// =========================================================================
// RENDER THE CHARACTER LIST
// =========================================================================

function renderCharacters() {
    var list = document.getElementById('character-list');
    var newBtn = document.getElementById('btn-new-char');

    list.innerHTML = '';

    if (characters.length === 0) {
        list.innerHTML = '<p style="text-align:center; color:#8a7a66; padding:20px;">No characters yet. Create one to begin.</p>';
    } else {
        for (var i = 0; i < characters.length; i++) {
            var char = characters[i];
            var cash = (char.cash || 0).toLocaleString();
            var bank = (char.bank || 0).toLocaleString();
            var name = escapeHtml(char.first_name) + ' ' + escapeHtml(char.last_name);
            var job = escapeHtml(char.job_label || 'Unemployed');

            var card = document.createElement('div');
            card.className = 'char-card';
            card.innerHTML =
                '<div class="char-info">' +
                    '<div class="char-name">' + name + '</div>' +
                    '<div class="char-details">' + job + ' &bull; $' + cash + ' cash &bull; $' + bank + ' bank</div>' +
                '</div>' +
                '<div class="char-actions">' +
                    '<button class="btn btn-play" data-id="' + char.id + '">Play</button>' +
                    '<button class="btn btn-delete" data-id="' + char.id + '" data-name="' + name + '">X</button>' +
                '</div>';

            list.appendChild(card);
        }

        // Attach click handlers via event delegation
        list.onclick = function(e) {
            var btn = e.target;
            if (btn.classList.contains('btn-play')) {
                selectCharacter(parseInt(btn.getAttribute('data-id')));
            } else if (btn.classList.contains('btn-delete')) {
                showDeleteConfirm(parseInt(btn.getAttribute('data-id')), btn.getAttribute('data-name'));
            }
        };
    }

    // Show/hide create button based on character limit
    if (characters.length >= maxCharacters) {
        newBtn.classList.add('hidden');
    } else {
        newBtn.classList.remove('hidden');
    }
}

// =========================================================================
// ACTIONS
// =========================================================================

async function selectCharacter(charId) {
    showStatus('Loading character...');
    var result = await nuiCallback('selectCharacter', { id: charId });
    if (!result.ok) {
        showStatus(result.message || 'Failed to select character');
    }
}

async function createCharacter() {
    var firstName = document.getElementById('first-name').value.trim();
    var lastName = document.getElementById('last-name').value.trim();

    if (firstName.length < 2) {
        showCreateError('First name must be at least 2 characters');
        return;
    }
    if (lastName.length < 2) {
        showCreateError('Last name must be at least 2 characters');
        return;
    }

    showStatus('Creating character...');
    var result = await nuiCallback('createCharacter', {
        firstName: firstName,
        lastName: lastName
    });

    if (result.ok) {
        hideCreateForm();
        hideStatus();
    } else {
        showCreateError(result.message || 'Failed to create character');
        hideStatus();
    }
}

function showDeleteConfirm(charId, charName) {
    deleteTargetId = charId;
    document.getElementById('delete-char-name').textContent = charName;
    document.getElementById('char-select').classList.add('hidden');
    document.getElementById('delete-confirm').classList.remove('hidden');
}

function hideDeleteConfirm() {
    deleteTargetId = null;
    document.getElementById('delete-confirm').classList.add('hidden');
    document.getElementById('char-select').classList.remove('hidden');
}

async function confirmDelete() {
    if (!deleteTargetId) return;

    showStatus('Deleting character...');
    var result = await nuiCallback('deleteCharacter', { id: deleteTargetId });

    hideDeleteConfirm();
    if (result.ok) {
        hideStatus();
    } else {
        showStatus(result.message || 'Failed to delete character');
    }
    deleteTargetId = null;
}

// =========================================================================
// UI HELPERS
// =========================================================================

function showApp() {
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('char-select').classList.remove('hidden');
    document.getElementById('create-form').classList.add('hidden');
    document.getElementById('delete-confirm').classList.add('hidden');
}

function hideApp() {
    document.getElementById('app').classList.add('hidden');
}

function showCreateForm() {
    document.getElementById('char-select').classList.add('hidden');
    document.getElementById('create-form').classList.remove('hidden');
    document.getElementById('first-name').value = '';
    document.getElementById('last-name').value = '';
    hideCreateError();
}

function hideCreateForm() {
    document.getElementById('create-form').classList.add('hidden');
    document.getElementById('char-select').classList.remove('hidden');
    hideCreateError();
}

function showCreateError(msg) {
    var el = document.getElementById('create-error');
    el.textContent = msg;
    el.classList.remove('hidden');
}

function hideCreateError() {
    document.getElementById('create-error').classList.add('hidden');
}

function showStatus(msg) {
    var el = document.getElementById('status-msg');
    el.textContent = msg;
    el.classList.remove('hidden');
}

function hideStatus() {
    document.getElementById('status-msg').classList.add('hidden');
}

// Prevent XSS by escaping HTML special characters.
// User input (character names) gets displayed in the HTML,
// so we must escape it to prevent someone naming their character
// "<script>alert('hacked')</script>" and having it execute.
function escapeHtml(text) {
    if (!text) return '';
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}

// Close UI with Escape key
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        nuiCallback('closeUI', {});
    }
});
