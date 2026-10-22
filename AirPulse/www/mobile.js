/**
 * AIRPULSE MOBILE CLIENT ENGINE (OFFLINE IPA & WEB HYBRID)
 * Ultra-responsive Flick Gestures, Virtual Trackpad, Remote Deck, Power Management & Web Audio Synth
 */
(function () {
  'use strict';

  // --- AUDIO SYNTHESIZER ---
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  let audioCtx = null;

  function playTone(freqStart, freqEnd, duration, type = 'sine') {
    try {
      if (!audioCtx && AudioCtx) audioCtx = new AudioCtx();
      if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
      if (!audioCtx) return;

      const now = audioCtx.currentTime;
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freqStart, now);
      osc.frequency.exponentialRampToValueAtTime(freqEnd, now + duration);
      gain.gain.setValueAtTime(0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + duration);
    } catch (e) {}
  }

  const sfx = {
    flick: () => playTone(300, 1200, 0.35),
    success: () => {
      playTone(523, 659, 0.15);
      setTimeout(() => playTone(659, 1046, 0.2), 80);
    },
    click: () => playTone(750, 400, 0.04),
    alarm: () => {
      playTone(880, 440, 0.25, 'triangle');
      setTimeout(() => playTone(880, 440, 0.25, 'triangle'), 150);
    }
  };

  // --- NETWORK CONFIGURATION (OFFLINE IPA & WEB DUAL-MODE) ---
  function getPcHost() {
    if (window.location.protocol === 'file:') {
      return localStorage.getItem('airpulse_pc_host') || '172.20.10.2:8899';
    }
    return window.location.host;
  }

  function getBaseUrl() {
    if (window.location.protocol === 'file:') {
      return 'http://' + getPcHost();
    }
    return window.location.origin || (window.location.protocol + '//' + window.location.host);
  }

  function getWsUrl() {
    if (window.location.protocol === 'file:') {
      return 'ws://' + getPcHost() + '/ws';
    }
    const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    return proto + '//' + window.location.host + '/ws';
  }

  // --- STATE ---
  const state = {
    ws: null,
    activeTab: 'beam',
    stagedFile: null,
    isUploading: false,
    files: [],
    shutdownTimer: null,
    shutdownCountdown: 15
  };

  // --- DOM REFS ---
  const el = {
    statusText: document.getElementById('statusText'),
    statusPulsar: document.getElementById('statusPulsar'),
    btnConfigIp: document.getElementById('btnConfigIp'),
    ipDisplayBadge: document.getElementById('ipDisplayBadge'),
    ipaDlLink: document.getElementById('ipaDlLink'),
    flickStage: document.getElementById('flickStage'),
    mobileFileInput: document.getElementById('mobileFileInput'),
    emptyBeamState: document.getElementById('emptyBeamState'),
    stagedCard: document.getElementById('stagedCard'),
    stagedThumb: document.getElementById('stagedThumb'),
    stagedName: document.getElementById('stagedName'),
    stagedSize: document.getElementById('stagedSize'),
    flickBtn: document.getElementById('flickBtn'),
    touchpadSurface: document.getElementById('touchpadSurface'),
    btnLeftClick: document.getElementById('btnLeftClick'),
    btnRightClick: document.getElementById('btnRightClick'),
    urlInput: document.getElementById('urlInput'),
    urlLaunchBtn: document.getElementById('urlLaunchBtn'),
    vaultList: document.getElementById('vaultList'),
    btnRefreshVault: document.getElementById('btnRefreshVault'),
    // IP Modal
    ipModal: document.getElementById('ipModal'),
    inputPcHost: document.getElementById('inputPcHost'),
    btnCloseIpModal: document.getElementById('btnCloseIpModal'),
    btnCancelIpModal: document.getElementById('btnCancelIpModal'),
    btnSaveIpModal: document.getElementById('btnSaveIpModal'),
    // Power Deck & Shutdown Modal
    btnTriggerShutdown: document.getElementById('btnTriggerShutdown'),
    btnCancelShutdownQuick: document.getElementById('btnCancelShutdownQuick'),
    shutdownModal: document.getElementById('shutdownModal'),
    countdownSeconds: document.getElementById('countdownSeconds'),
    btnAbortShutdown: document.getElementById('btnAbortShutdown')
  };

  // Update IP Badge in Top Island
  function updateIpBadge() {
    const host = getPcHost();
    const shortIp = host.split(':')[0];
    if (el.ipDisplayBadge) {
      el.ipDisplayBadge.textContent = shortIp;
    }
    // If running inside native IPA, hide the "Install IPA" badge
    if (window.location.protocol === 'file:' && el.ipaDlLink) {
      el.ipaDlLink.style.display = 'none';
    }
  }

  // --- WEBSOCKET ENGINE ---
  let reconnectTimeout = null;

  function initWebSocket() {
    if (reconnectTimeout) clearTimeout(reconnectTimeout);
    if (state.ws) {
      try { state.ws.close(); } catch (e) {}
    }

    const wsUrl = getWsUrl();
    if (el.statusText) el.statusText.textContent = `Đang kết nối: ${getPcHost()}...`;
    if (el.statusPulsar) el.statusPulsar.style.background = '#f59e0b';

    try {
      state.ws = new WebSocket(wsUrl);
    } catch (err) {
      handleWsError();
      return;
    }

    state.ws.onopen = () => {
      const devName = /iPhone/i.test(navigator.userAgent) ? 'iPhone' : (/iPad/i.test(navigator.userAgent) ? 'iPad' : (/Android/i.test(navigator.userAgent) ? 'Android' : 'Mobile'));
      state.ws.send(JSON.stringify({ type: 'IDENTIFY', device: devName }));
      if (el.statusText) el.statusText.textContent = `Đã kết nối PC (${devName})`;
      if (el.statusPulsar) el.statusPulsar.style.background = '#10b981';
      loadVault();
    };

    state.ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'FILE_RECEIVED') {
          sfx.success();
          if (navigator.vibrate) navigator.vibrate([30, 40]);
          loadVault();
        } else if (msg.type === 'REMOTE_ACTION_EXECUTED') {
          if (msg.action === 'shutdown_pc') {
            startShutdownCountdown();
          } else if (msg.action === 'cancel_shutdown') {
            stopShutdownCountdown();
          }
        }
      } catch (err) {}
    };

    state.ws.onerror = () => {
      handleWsError();
    };

    state.ws.onclose = () => {
      handleWsError();
    };
  }

  function handleWsError() {
    if (el.statusText) el.statusText.textContent = 'Mất kết nối PC...';
    if (el.statusPulsar) el.statusPulsar.style.background = '#ff3366';
    reconnectTimeout = setTimeout(initWebSocket, 3000);
  }

  // --- IP CONFIGURATION MODAL ---
  function setupIpModal() {
    if (el.btnConfigIp) {
      el.btnConfigIp.addEventListener('click', () => {
        sfx.click();
        if (el.inputPcHost) el.inputPcHost.value = getPcHost();
        if (el.ipModal) el.ipModal.style.display = 'flex';
      });
    }

    const closeModal = () => {
      if (el.ipModal) el.ipModal.style.display = 'none';
    };

    if (el.btnCloseIpModal) el.btnCloseIpModal.addEventListener('click', closeModal);
    if (el.btnCancelIpModal) el.btnCancelIpModal.addEventListener('click', closeModal);

    document.querySelectorAll('.preset-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        sfx.click();
        const host = chip.getAttribute('data-host');
        if (host && el.inputPcHost) el.inputPcHost.value = host;
      });
    });

    if (el.btnSaveIpModal) {
      el.btnSaveIpModal.addEventListener('click', () => {
        sfx.click();
        const raw = (el.inputPcHost ? el.inputPcHost.value : '').trim().replace(/^https?:\/\//i, '').replace(/\/.*$/, '');
        if (raw) {
          localStorage.setItem('airpulse_pc_host', raw);
          updateIpBadge();
          closeModal();
          initWebSocket();
        }
      });
    }
  }

  // --- REMOTE POWER MANAGEMENT ENGINE ---
  function startShutdownCountdown() {
    sfx.alarm();
    if (navigator.vibrate) navigator.vibrate([100, 50, 100, 50, 200]);

    state.shutdownCountdown = 15;
    if (el.countdownSeconds) el.countdownSeconds.textContent = '15s';
    if (el.shutdownModal) el.shutdownModal.style.display = 'flex';

    if (state.shutdownTimer) clearInterval(state.shutdownTimer);

    state.shutdownTimer = setInterval(() => {
      state.shutdownCountdown--;
      if (el.countdownSeconds) el.countdownSeconds.textContent = `${state.shutdownCountdown}s`;

      if (state.shutdownCountdown <= 0) {
        clearInterval(state.shutdownTimer);
        state.shutdownTimer = null;
        if (el.shutdownModal) el.shutdownModal.style.display = 'none';
      }
    }, 1000);
  }

  function stopShutdownCountdown() {
    if (state.shutdownTimer) {
      clearInterval(state.shutdownTimer);
      state.shutdownTimer = null;
    }
    if (el.shutdownModal) el.shutdownModal.style.display = 'none';
    sfx.success();
  }

  function setupPowerDeck() {
    // Shutdown button with countdown
    if (el.btnTriggerShutdown) {
      el.btnTriggerShutdown.addEventListener('click', () => {
        sfx.click();
        fetch(getBaseUrl() + '/api/remote/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'shutdown_pc', device: 'iPhone' })
        })
          .then((res) => res.json())
          .then(() => startShutdownCountdown())
          .catch(() => startShutdownCountdown());
      });
    }

    // Cancel Shutdown buttons
    const triggerCancel = () => {
      sfx.click();
      fetch(getBaseUrl() + '/api/remote/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'cancel_shutdown', device: 'iPhone' })
      })
        .then((res) => res.json())
        .then(() => stopShutdownCountdown())
        .catch(() => stopShutdownCountdown());
    };

    if (el.btnAbortShutdown) el.btnAbortShutdown.addEventListener('click', triggerCancel);
    if (el.btnCancelShutdownQuick) el.btnCancelShutdownQuick.addEventListener('click', triggerCancel);
  }

  // --- FLICK GESTURE ENGINE ---
  let startY = 0;
  let currentY = 0;
  let startTime = 0;
  let isDragging = false;

  function setupFlickGesture() {
    const stage = el.flickStage;
    if (!stage) return;

    stage.addEventListener('click', (e) => {
      if (!state.stagedFile && !state.isUploading && e.target !== el.mobileFileInput) {
        el.mobileFileInput.click();
      }
    });

    el.mobileFileInput.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (file) stageFile(file);
    });

    const card = el.stagedCard;

    card.addEventListener('touchstart', (e) => {
      if (state.isUploading || !state.stagedFile) return;
      isDragging = true;
      startY = e.touches[0].clientY;
      currentY = startY;
      startTime = Date.now();
      card.style.transition = 'none';
      sfx.click();
    }, { passive: true });

    window.addEventListener('touchmove', (e) => {
      if (!isDragging) return;
      currentY = e.touches[0].clientY;
      const deltaY = currentY - startY;

      if (deltaY < 0) {
        const translateY = Math.max(deltaY, -280);
        const scale = 1 - Math.abs(deltaY) * 0.0008;
        card.style.transform = `translateY(${translateY}px) scale(${scale})`;
        stage.classList.add('beaming');
      }
    }, { passive: true });

    window.addEventListener('touchend', () => {
      if (!isDragging) return;
      isDragging = false;
      const deltaY = currentY - startY;
      const elapsed = Math.max(Date.now() - startTime, 1);
      const velocity = Math.abs(deltaY) / elapsed;

      if (deltaY < -75 || (deltaY < -35 && velocity > 0.45)) {
        launchBeam();
      } else {
        card.style.transition = 'transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)';
        card.style.transform = 'translateY(0) scale(1)';
        stage.classList.remove('beaming');
      }
    });

    if (el.flickBtn) {
      el.flickBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        launchBeam();
      });
    }
  }

  function stageFile(file) {
    state.stagedFile = file;
    el.stagedName.textContent = file.name;
    el.stagedSize.textContent = `${(file.size / (1024 * 1024)).toFixed(1)} MB`;

    if (file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (ev) => {
        el.stagedThumb.innerHTML = `<img src="${ev.target.result}" alt="Preview">`;
      };
      reader.readAsDataURL(file);
    } else {
      el.stagedThumb.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
          <polyline points="14 2 14 8 20 8"></polyline>
        </svg>
      `;
    }

    el.emptyBeamState.style.display = 'none';
    el.stagedCard.style.display = 'flex';
    el.stagedCard.classList.remove('launching');
    el.stagedCard.style.transform = 'translateY(0) scale(1)';
  }

  function launchBeam() {
    if (!state.stagedFile || state.isUploading) return;
    state.isUploading = true;

    sfx.flick();
    if (navigator.vibrate) navigator.vibrate([20, 50, 30]);

    el.stagedCard.classList.add('launching');
    el.flickStage.classList.add('beaming');

    const file = state.stagedFile;
    const formData = new FormData();
    formData.append('file', file);

    const xhr = new XMLHttpRequest();
    xhr.onload = () => {
      state.isUploading = false;
      el.flickStage.classList.remove('beaming');
      sfx.success();
      resetBeam();
      loadVault();
    };
    xhr.onerror = () => {
      state.isUploading = false;
      el.flickStage.classList.remove('beaming');
      resetBeam();
    };
    xhr.open('POST', getBaseUrl() + '/api/files/upload', true);
    xhr.send(formData);
  }

  function resetBeam() {
    state.stagedFile = null;
    el.mobileFileInput.value = '';
    el.emptyBeamState.style.display = 'flex';
    el.stagedCard.style.display = 'none';
    el.stagedCard.classList.remove('launching');
  }

  // --- VIRTUAL TRACKPAD ENGINE ---
  let lastTouchX = 0;
  let lastTouchY = 0;
  let touchCount = 0;

  function setupTrackpad() {
    const pad = el.touchpadSurface;
    if (!pad) return;

    pad.addEventListener('touchstart', (e) => {
      touchCount = e.touches.length;
      if (e.touches[0]) {
        lastTouchX = e.touches[0].clientX;
        lastTouchY = e.touches[0].clientY;
      }
    }, { passive: true });

    pad.addEventListener('touchmove', (e) => {
      if (!state.ws || state.ws.readyState !== WebSocket.OPEN) return;
      touchCount = e.touches.length;

      if (touchCount === 1) {
        // Move mouse
        const curX = e.touches[0].clientX;
        const curY = e.touches[0].clientY;
        const dx = Math.round((curX - lastTouchX) * 1.8);
        const dy = Math.round((curY - lastTouchY) * 1.8);

        state.ws.send(JSON.stringify({ type: 'MOUSE_MOVE', dx, dy }));
        lastTouchX = curX;
        lastTouchY = curY;
      } else if (touchCount === 2) {
        // Scroll wheel
        const curY = e.touches[0].clientY;
        const dy = Math.round((lastTouchY - curY) * 1.2);
        state.ws.send(JSON.stringify({ type: 'MOUSE_SCROLL', dy }));
        lastTouchY = curY;
      }
    }, { passive: true });

    pad.addEventListener('touchend', (e) => {
      if (touchCount === 2 && e.touches.length === 0) {
        // Two-finger tap = right click
        sendClick('right');
      }
      touchCount = e.touches.length;
    });

    if (el.btnLeftClick) {
      el.btnLeftClick.addEventListener('click', () => sendClick('left'));
    }
    if (el.btnRightClick) {
      el.btnRightClick.addEventListener('click', () => sendClick('right'));
    }
  }

  function sendClick(button) {
    sfx.click();
    if (navigator.vibrate) navigator.vibrate(15);
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
      state.ws.send(JSON.stringify({ type: 'MOUSE_CLICK', button }));
    }
  }

  // --- REMOTE PC ACTIONS ---
  function setupRemote() {
    if (el.urlLaunchBtn) {
      el.urlLaunchBtn.addEventListener('click', () => {
        const url = el.urlInput.value.trim();
        if (url) {
          sfx.click();
          fetch(getBaseUrl() + '/api/remote/open-url', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url, device: 'Mobile' })
          });
        }
      });
    }

    document.querySelectorAll('.mob-chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        const u = chip.getAttribute('data-url');
        if (u) {
          sfx.click();
          fetch(getBaseUrl() + '/api/remote/open-url', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url: u, device: 'Mobile' })
          });
        }
      });
    });

    document.querySelectorAll('.mob-action-btn[data-action]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const act = btn.getAttribute('data-action');
        if (act) {
          sfx.click();
          if (navigator.vibrate) navigator.vibrate(20);
          fetch(getBaseUrl() + '/api/remote/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: act, device: 'Mobile' })
          });
        }
      });
    });
  }

  // --- VAULT LIST ---
  function loadVault() {
    fetch(getBaseUrl() + '/api/files')
      .then((res) => res.json())
      .then((data) => {
        state.files = data.files || [];
        renderVault();
      })
      .catch(() => {});
  }

  function renderVault() {
    if (!el.vaultList) return;
    if (state.files.length === 0) {
      el.vaultList.innerHTML = `<div style="text-align: center; color: #64748b; font-size: 0.8rem; padding: 30px;">Chưa có file nào</div>`;
      return;
    }

    const base = getBaseUrl();
    el.vaultList.innerHTML = state.files.map((f) => {
      const viewUrl = f.view_url.startsWith('http') ? f.view_url : `${base}${f.view_url}`;
      const dlUrl = f.download_url.startsWith('http') ? f.download_url : `${base}${f.download_url}`;

      return `
        <div class="vault-item-mob">
          <div class="vault-thumb-mob" onclick="window.open('${viewUrl}', '_blank')">
            ${f.is_image ? `<img src="${viewUrl}" alt="${f.name}">` : `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path></svg>`}
          </div>
          <div class="vault-info-mob">
            <div class="vault-title-mob">${f.name}</div>
            <div class="vault-sub-mob">${f.size_formatted}</div>
          </div>
          <a href="${dlUrl}" class="vault-dl-btn" download>Lưu</a>
        </div>
      `;
    }).join('');
  }

  // --- DOCK NAVIGATION ---
  function setupDock() {
    document.querySelectorAll('.dock-item-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        const targetTab = btn.getAttribute('data-tab');
        document.querySelectorAll('.dock-item-btn').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');

        document.querySelectorAll('.tab-pane').forEach((p) => p.classList.remove('active'));
        const activePane = document.getElementById(`tab-${targetTab}`);
        if (activePane) activePane.classList.add('active');

        sfx.click();
      });
    });

    if (el.btnRefreshVault) {
      el.btnRefreshVault.addEventListener('click', () => {
        sfx.click();
        loadVault();
      });
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    updateIpBadge();
    initWebSocket();
    setupIpModal();
    setupPowerDeck();
    setupFlickGesture();
    setupTrackpad();
    setupRemote();
    setupDock();
    loadVault();
  });
})();
