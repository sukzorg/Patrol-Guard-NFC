const initialCheckpoints = [
  { id: "CP-01", name: "Lobby Timur", zone: "Gedung A", uid: "NFC-A1-7782" },
  { id: "CP-02", name: "Ruang Server", zone: "Lantai 2", uid: "NFC-B3-1209" },
  { id: "CP-03", name: "Koridor Parkir", zone: "Basement", uid: "NFC-C4-4431" },
  { id: "CP-04", name: "Loading Dock", zone: "Area Belakang", uid: "NFC-D7-2290" },
  { id: "CP-05", name: "Rooftop Access", zone: "Lantai 12", uid: "NFC-E2-9188" },
];

const state = {
  isOnline: true,
  isLoggedIn: false,
  sessionId: null,
  guardName: "Dimas Pratama",
  shift: null,
  lastUpload: null,
  logs: [],
  checkpoints: initialCheckpoints.map((checkpoint) => ({
    ...checkpoint,
    visitedAt: null,
    syncStatus: "upcoming",
  })),
};

const elements = {
  loginForm: document.querySelector("#loginForm"),
  emailInput: document.querySelector("#emailInput"),
  shiftSelect: document.querySelector("#shiftSelect"),
  networkButton: document.querySelector("#networkButton"),
  networkStatusLabel: document.querySelector("#networkStatusLabel"),
  guardStatePill: document.querySelector("#guardStatePill"),
  operatorName: document.querySelector("#operatorName"),
  operatorShift: document.querySelector("#operatorShift"),
  sessionIdLabel: document.querySelector("#sessionIdLabel"),
  sessionBadge: document.querySelector("#sessionBadge"),
  queueBadge: document.querySelector("#queueBadge"),
  coverageBadge: document.querySelector("#coverageBadge"),
  checkpointList: document.querySelector("#checkpointList"),
  activityList: document.querySelector("#activityList"),
  lastScanLabel: document.querySelector("#lastScanLabel"),
  activeGuardKpi: document.querySelector("#activeGuardKpi"),
  pendingKpi: document.querySelector("#pendingKpi"),
  coverageKpi: document.querySelector("#coverageKpi"),
  lastUploadKpi: document.querySelector("#lastUploadKpi"),
  pendingCount: document.querySelector("#pendingCount"),
  syncedCount: document.querySelector("#syncedCount"),
  failedCount: document.querySelector("#failedCount"),
  queueModePill: document.querySelector("#queueModePill"),
  syncNarrative: document.querySelector("#syncNarrative"),
  progressLabel: document.querySelector("#progressLabel"),
  progressBar: document.querySelector("#progressBar"),
  timelineStatusPill: document.querySelector("#timelineStatusPill"),
  timelineList: document.querySelector("#timelineList"),
  syncHealthPill: document.querySelector("#syncHealthPill"),
  scanButton: document.querySelector("#scanButton"),
  syncButton: document.querySelector("#syncButton"),
  resetButton: document.querySelector("#resetButton"),
};

function formatTime(date) {
  return new Intl.DateTimeFormat("id-ID", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function createSessionId() {
  const stamp = new Date().toISOString().slice(11, 19).replaceAll(":", "");
  return `PATROL-${stamp}`;
}

function getCounts() {
  const pending = state.logs.filter((log) => log.syncStatus === "pending").length;
  const synced = state.logs.filter((log) => log.syncStatus === "synced").length;
  const failed = state.logs.filter((log) => log.syncStatus === "failed").length;
  const visited = state.logs.length;

  return { pending, synced, failed, visited };
}

function getNextCheckpoint() {
  return state.checkpoints.find((checkpoint) => checkpoint.syncStatus === "upcoming");
}

function renderCheckpoints() {
  elements.checkpointList.innerHTML = state.checkpoints
    .map((checkpoint) => {
      const label =
        checkpoint.syncStatus === "upcoming"
          ? "Belum dikunjungi"
          : checkpoint.syncStatus === "pending"
            ? "Tersimpan lokal"
            : checkpoint.syncStatus === "failed"
              ? "Perlu retry"
              : "Terkirim ke server";

      const note =
        checkpoint.visitedAt
          ? `Scan ${formatTime(new Date(checkpoint.visitedAt))}`
          : "Menunggu scan NFC";

      return `
        <article class="checkpoint-item">
          <div class="checkpoint-head">
            <div>
              <strong>${checkpoint.name}</strong>
              <div class="checkpoint-meta">
                <span>${checkpoint.id}</span>
                <span>${checkpoint.zone}</span>
                <span>${checkpoint.uid}</span>
              </div>
            </div>
            <span class="status-badge status-${checkpoint.syncStatus}">${label}</span>
          </div>
          <div class="checkpoint-meta">
            <span>${note}</span>
          </div>
        </article>
      `;
    })
    .join("");
}

function renderActivities() {
  if (!state.logs.length) {
    elements.activityList.innerHTML = `
      <article class="activity-item">
        <strong>Belum ada aktivitas</strong>
        <div class="activity-meta">
          <span>Mulai shift untuk mengaktifkan simulasi scan NFC.</span>
        </div>
      </article>
    `;
    return;
  }

  elements.activityList.innerHTML = state.logs
    .slice()
    .reverse()
    .map((log) => {
      const statusLabel =
        log.syncStatus === "pending"
          ? "pending"
          : log.syncStatus === "failed"
            ? "failed"
            : "synced";

      return `
        <article class="activity-item">
          <div class="activity-head">
            <div>
              <strong>${log.checkpointName}</strong>
              <div class="activity-meta">
                <span>${formatTime(new Date(log.scannedAt))}</span>
                <span>${log.uid}</span>
              </div>
            </div>
            <span class="status-badge status-${log.syncStatus}">${statusLabel}</span>
          </div>
          <div class="activity-meta">
            <span>${log.message}</span>
          </div>
        </article>
      `;
    })
    .join("");
}

function renderTimeline() {
  const nextCheckpoint = getNextCheckpoint();
  const items = [
    {
      title: state.isLoggedIn ? "Guard authenticated" : "Menunggu autentikasi",
      detail: state.isLoggedIn
        ? `${state.guardName} aktif di shift ${state.shift}.`
        : "Login diperlukan sebelum sesi patroli dimulai.",
      status: state.isLoggedIn ? "complete" : "upcoming",
    },
    {
      title: state.sessionId ? "Patrol session started" : "Sesi belum aktif",
      detail: state.sessionId
        ? `Session ${state.sessionId} siap menerima scan checkpoint.`
        : "Belum ada sesi patroli berjalan.",
      status: state.sessionId ? "complete" : "upcoming",
    },
    {
      title: nextCheckpoint ? `Checkpoint berikutnya: ${nextCheckpoint.name}` : "Semua checkpoint selesai",
      detail: nextCheckpoint
        ? `Target berikutnya berada di ${nextCheckpoint.zone}.`
        : "Route patroli hari ini sudah tercakup penuh.",
      status: nextCheckpoint ? "pending" : "complete",
    },
  ];

  elements.timelineList.innerHTML = items
    .map(
      (item) => `
        <article class="timeline-item">
          <div class="timeline-head">
            <strong>${item.title}</strong>
            <span class="status-badge status-${item.status}">${item.status}</span>
          </div>
          <div class="timeline-meta">
            <span>${item.detail}</span>
          </div>
        </article>
      `
    )
    .join("");
}

function updateSummary() {
  const counts = getCounts();
  const coverage = Math.round((counts.visited / state.checkpoints.length) * 100) || 0;
  const hasSession = Boolean(state.sessionId);
  const lastLog = state.logs.at(-1);

  elements.networkStatusLabel.textContent = state.isOnline ? "Online" : "Offline";
  elements.guardStatePill.textContent = state.isLoggedIn ? "Guard siap patroli" : "Menunggu login";
  elements.operatorName.textContent = state.isLoggedIn ? state.guardName : "Belum login";
  elements.operatorShift.textContent = state.shift || "-";
  elements.sessionIdLabel.textContent = state.sessionId || "-";
  elements.sessionBadge.textContent = hasSession ? "Sesi aktif" : "Belum dimulai";
  elements.queueBadge.textContent = `${counts.pending} log pending`;
  elements.coverageBadge.textContent = `${counts.visited}/${state.checkpoints.length} checkpoint`;
  elements.lastScanLabel.textContent = lastLog
    ? `Scan terakhir ${formatTime(new Date(lastLog.scannedAt))}`
    : "Belum ada scan";
  elements.activeGuardKpi.textContent = hasSession ? "1" : "0";
  elements.pendingKpi.textContent = String(counts.pending);
  elements.coverageKpi.textContent = `${coverage}%`;
  elements.lastUploadKpi.textContent = state.lastUpload || "-";
  elements.pendingCount.textContent = String(counts.pending);
  elements.syncedCount.textContent = String(counts.synced);
  elements.failedCount.textContent = String(counts.failed);
  elements.queueModePill.textContent = state.isOnline ? "Server reachable" : "Offline cache active";
  elements.timelineStatusPill.textContent = hasSession ? "Session live" : "Idle";
  elements.syncHealthPill.textContent =
    counts.pending > 0
      ? "Perlu sinkronisasi"
      : state.isOnline
        ? "Sistem stabil"
        : "Berjalan offline";
  elements.progressLabel.textContent = `${coverage}%`;
  elements.progressBar.style.width = `${coverage}%`;
  elements.networkButton.setAttribute("aria-pressed", String(!state.isOnline));

  if (!state.logs.length) {
    elements.syncNarrative.textContent =
      "Semua log sudah sinkron dengan server pusat. Mulai sesi untuk membuat data patroli baru.";
  } else if (!state.isOnline && counts.pending > 0) {
    elements.syncNarrative.textContent =
      `${counts.pending} log tersimpan lokal. Data aman di device dan akan dikirim saat koneksi kembali.`;
  } else if (counts.pending > 0) {
    elements.syncNarrative.textContent =
      `${counts.pending} log menunggu proses upload. Tekan sinkronkan untuk mengirim semuanya ke backend.`;
  } else {
    elements.syncNarrative.textContent =
      "Seluruh scan yang tercatat sudah berhasil dikirim ke server dan siap direview supervisor.";
  }
}

function render() {
  renderCheckpoints();
  renderActivities();
  renderTimeline();
  updateSummary();
}

function startSession() {
  state.isLoggedIn = true;
  state.shift = elements.shiftSelect.value;
  state.guardName = elements.emailInput.value.split("@")[0].replace(/\./g, " ");
  state.guardName = state.guardName
    .split(" ")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
  state.sessionId = createSessionId();
  state.lastUpload = null;
  render();
}

function scanCheckpoint() {
  if (!state.sessionId) {
    elements.guardStatePill.textContent = "Login dulu untuk mulai";
    return;
  }

  const nextCheckpoint = getNextCheckpoint();
  if (!nextCheckpoint) {
    elements.guardStatePill.textContent = "Semua checkpoint selesai";
    return;
  }

  const scannedAt = new Date();
  const syncStatus = state.isOnline ? "synced" : "pending";

  nextCheckpoint.visitedAt = scannedAt.toISOString();
  nextCheckpoint.syncStatus = syncStatus;

  state.logs.push({
    checkpointId: nextCheckpoint.id,
    checkpointName: nextCheckpoint.name,
    uid: nextCheckpoint.uid,
    scannedAt: scannedAt.toISOString(),
    syncStatus,
    message: state.isOnline
      ? "UID tervalidasi dan langsung terkirim ke server."
      : "UID tersimpan di SQLite lokal, menunggu sinkronisasi.",
  });

  if (state.isOnline) {
    state.lastUpload = formatTime(scannedAt);
  }

  render();
}

function syncLogs() {
  if (!state.logs.length) {
    return;
  }

  if (!state.isOnline) {
    elements.syncHealthPill.textContent = "Offline, sinkronisasi tertunda";
    return;
  }

  const syncTime = new Date();

  state.logs = state.logs.map((log) => {
    if (log.syncStatus !== "pending" && log.syncStatus !== "failed") {
      return log;
    }

    return {
      ...log,
      syncStatus: "synced",
      message: "Log lokal berhasil dikirim ke server pusat.",
    };
  });

  state.checkpoints = state.checkpoints.map((checkpoint) => {
    if (checkpoint.syncStatus === "pending" || checkpoint.syncStatus === "failed") {
      return { ...checkpoint, syncStatus: "synced" };
    }

    return checkpoint;
  });

  state.lastUpload = formatTime(syncTime);
  render();
}

function resetDemo() {
  state.isOnline = true;
  state.isLoggedIn = false;
  state.sessionId = null;
  state.shift = null;
  state.lastUpload = null;
  state.logs = [];
  state.checkpoints = initialCheckpoints.map((checkpoint) => ({
    ...checkpoint,
    visitedAt: null,
    syncStatus: "upcoming",
  }));

  elements.emailInput.value = "guard@patrol.id";
  elements.shiftSelect.value = "Pagi";
  render();
}

elements.loginForm.addEventListener("submit", (event) => {
  event.preventDefault();
  startSession();
});

elements.networkButton.addEventListener("click", () => {
  state.isOnline = !state.isOnline;
  render();
});

elements.scanButton.addEventListener("click", scanCheckpoint);
elements.syncButton.addEventListener("click", syncLogs);
elements.resetButton.addEventListener("click", resetDemo);

render();
