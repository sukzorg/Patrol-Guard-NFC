import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../context/AuthContext.jsx'
import {
  endPatrol,
  fetchCheckpoints,
  scanCheckpoint,
  startPatrol,
  syncPatrolLogs,
} from '../lib/api.js'
import {
  getSecurityLogsStorageKey,
  getSecuritySessionStorageKey,
  readStoredJson,
  removeStoredJson,
  writeStoredJson,
} from '../lib/storage.js'

const defaultShift = 'Pagi'

function buildMapOpenUrl(latitude, longitude) {
  if (latitude == null || longitude == null) {
    return ''
  }

  return `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=18/${latitude}/${longitude}`
}

function formatClock(value) {
  if (!value) {
    return '-'
  }

  return new Intl.DateTimeFormat('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

async function captureLocation() {
  if (!navigator.geolocation) {
    return null
  }

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (position) =>
        resolve({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 5000 },
    )
  })
}

export function GuardPage() {
  const { token, user } = useAuth()
  const sessionKey = useMemo(() => getSecuritySessionStorageKey(user.id), [user.id])
  const logsKey = useMemo(() => getSecurityLogsStorageKey(user.id), [user.id])
  const [checkpoints, setCheckpoints] = useState([])
  const [session, setSession] = useState(() => readStoredJson(sessionKey, null))
  const [logs, setLogs] = useState(() => readStoredJson(logsKey, []))
  const [shift, setShift] = useState(defaultShift)
  const [browserOnline, setBrowserOnline] = useState(window.navigator.onLine)
  const [forceOffline, setForceOffline] = useState(false)
  const [statusMessage, setStatusMessage] = useState('Mulai shift untuk membuka sesi patroli.')
  const [successMessage, setSuccessMessage] = useState('')
  const [error, setError] = useState('')
  const [isWorking, setIsWorking] = useState(false)
  const [isScanning, setIsScanning] = useState(false)
  const [mapPreviewErrors, setMapPreviewErrors] = useState({})

  const isOnline = browserOnline && !forceOffline
  const pendingLogs = logs.filter((log) => log.syncStatus !== 'synced')
  const visitedMap = new Map(logs.map((log) => [log.checkpointId, log]))
  const nextCheckpoint = checkpoints.find((checkpoint) => !visitedMap.has(checkpoint.id))

  useEffect(() => {
    function handleOnlineChange() {
      setBrowserOnline(window.navigator.onLine)
    }

    window.addEventListener('online', handleOnlineChange)
    window.addEventListener('offline', handleOnlineChange)

    return () => {
      window.removeEventListener('online', handleOnlineChange)
      window.removeEventListener('offline', handleOnlineChange)
    }
  }, [])

  useEffect(() => {
    writeStoredJson(logsKey, logs)
  }, [logs, logsKey])

  useEffect(() => {
    if (session) {
      writeStoredJson(sessionKey, session)
      return
    }
    removeStoredJson(sessionKey)
  }, [session, sessionKey])

  useEffect(() => {
    let isMounted = true

    async function loadCheckpoints() {
      try {
        const payload = await fetchCheckpoints(token)
        if (isMounted) {
          setCheckpoints(payload.data)
          setError('')
        }
      } catch (requestError) {
        if (isMounted) {
          setError(requestError.message)
        }
      }
    }

    loadCheckpoints()

    return () => {
      isMounted = false
    }
  }, [token])

  async function handleStartShift() {
    setError('')
    setIsWorking(true)

    try {
      const payload = await startPatrol(token, { shift })
      setSession(payload.data)
      setStatusMessage(`Shift ${payload.data.shift} aktif. Sesi patroli siap dipakai.`)
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setIsWorking(false)
    }
  }

  async function runScan(checkpoint, source) {
    if (!session?.id || !checkpoint) {
      return
    }

    setError('')
    setSuccessMessage('')
    setIsWorking(true)
    setIsScanning(true)

    const scannedAt = new Date().toISOString()
    const localUuid = crypto.randomUUID()
    const gps = await captureLocation()

    const localLog = {
      localUuid,
      checkpointId: checkpoint.id,
      checkpointName: checkpoint.name,
      buildingName: checkpoint.building_name,
      nfcUid: checkpoint.nfc_uid,
      qrCode: checkpoint.qr_code,
      scannedAt,
      gpsLatitude: gps?.latitude ?? null,
      gpsLongitude: gps?.longitude ?? null,
      gpsMapUrl: gps
        ? `https://staticmap.openstreetmap.de/staticmap.php?center=${gps.latitude},${gps.longitude}&zoom=18&size=640x320&markers=${gps.latitude},${gps.longitude},red-pushpin`
        : null,
      gpsOpenUrl: gps ? buildMapOpenUrl(gps.latitude, gps.longitude) : '',
      syncStatus: isOnline ? 'synced' : 'pending',
      syncedAt: isOnline ? scannedAt : null,
      source,
      message: isOnline
        ? 'Checkpoint tervalidasi dan langsung terkirim ke server.'
        : 'Checkpoint tersimpan lokal dan menunggu sinkronisasi.',
    }

    try {
      if (isOnline) {
        const payload = await scanCheckpoint(token, {
          patrol_session_id: session.id,
          checkpoint_id: checkpoint.id,
          local_uuid: localUuid,
          scanned_at: scannedAt,
          gps_latitude: gps?.latitude,
          gps_longitude: gps?.longitude,
          source,
        })

        setLogs((currentLogs) => [
          ...currentLogs,
          {
            ...localLog,
            syncedAt: payload.data.synced_at,
            gpsMapUrl: payload.data.gps_map_url || localLog.gpsMapUrl,
            gpsOpenUrl: payload.data.gps_open_url || localLog.gpsOpenUrl,
          },
        ])
      } else {
        setLogs((currentLogs) => [...currentLogs, localLog])
      }

      setStatusMessage(`Checkpoint ${checkpoint.name} berhasil dicatat.`)
      setSuccessMessage(`Checkpoint ${checkpoint.name} berhasil dikonfirmasi.`)
    } catch (requestError) {
      setLogs((currentLogs) => [
        ...currentLogs,
        {
          ...localLog,
          syncStatus: 'pending',
          syncedAt: null,
          message: 'Server tidak terjangkau. Log dipindahkan ke antrean offline.',
        },
      ])
      setError(requestError.message)
    } finally {
      setIsScanning(false)
      setIsWorking(false)
    }
  }

  async function handleNfcScan() {
    if (!nextCheckpoint) {
      setStatusMessage('Semua checkpoint pada rute hari ini sudah selesai dikunjungi.')
      return
    }
    await runScan(nextCheckpoint, 'nfc-scan')
  }

  async function handleQrScan() {
    if (!session?.id) {
      setError('Mulai shift terlebih dahulu sebelum scan checkpoint.')
      return
    }

    const code = window.prompt('Masukkan QR code checkpoint')
    if (!code) {
      return
    }

    const normalizedCode = code.trim().toUpperCase().replaceAll(/\s+/g, '-')
    const checkpoint = checkpoints.find(
      (entry) => String(entry.qr_code || '').trim().toUpperCase() === normalizedCode,
    )

    if (!checkpoint) {
      setError(`QR code ${normalizedCode} tidak cocok dengan checkpoint mana pun.`)
      return
    }

    await runScan(checkpoint, 'qr-scan')
  }

  async function handleManualSync() {
    if (!session?.id || !pendingLogs.length || !isOnline) {
      return
    }

    try {
      const payload = await syncPatrolLogs(token, {
        patrol_session_id: session.id,
        logs: pendingLogs.map((log) => ({
          checkpoint_id: log.checkpointId,
          local_uuid: log.localUuid,
          scanned_at: log.scannedAt,
          gps_latitude: log.gpsLatitude,
          gps_longitude: log.gpsLongitude,
          source: log.source,
        })),
      })

      const syncMap = new Map(payload.data.map((log) => [log.local_uuid, log]))
      setLogs((currentLogs) =>
        currentLogs.map((log) => {
          const syncedLog = syncMap.get(log.localUuid)
          if (!syncedLog) {
            return log
          }

          return {
            ...log,
            syncStatus: 'synced',
            syncedAt: syncedLog.synced_at,
            gpsMapUrl: syncedLog.gps_map_url || log.gpsMapUrl,
            gpsOpenUrl: syncedLog.gps_open_url || log.gpsOpenUrl,
            message: 'Log offline sudah berhasil dikirim ke server.',
          }
        }),
      )

      setSuccessMessage('Sinkronisasi antrean lokal berhasil dijalankan.')
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  async function handleEndShift() {
    if (!session?.id) {
      return
    }

    try {
      await endPatrol(token, { patrol_session_id: session.id })
      setSession(null)
      setSuccessMessage('Shift berhasil ditutup.')
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  const pendingCount = logs.filter((log) => log.syncStatus !== 'synced').length

  return (
    <section className="workspace">
      <article className="card app-panel">
        <div className="panel-header">
          <div>
            <p className="section-tag">Security Console</p>
            <h3>Halo, {user.name}</h3>
          </div>
          <span className={`status-badge ${isOnline ? 'status-online' : 'status-offline'}`}>
            {isOnline ? 'Online' : 'Offline'}
          </span>
        </div>

        <div className="summary-grid summary-grid-three">
          <article className="summary-tile">
            <span>Session</span>
            <strong>{session ? 'Active' : 'Belum aktif'}</strong>
          </article>
          <article className="summary-tile">
            <span>Checkpoint</span>
            <strong>{visitedMap.size}/{checkpoints.length || 0}</strong>
          </article>
          <article className="summary-tile">
            <span>Pending</span>
            <strong>{pendingCount}</strong>
          </article>
        </div>

        <div className="operator-card card">
          <div>
            <p className="muted-label">NIK</p>
            <strong>{user.nik}</strong>
          </div>
          <div>
            <p className="muted-label">Shift</p>
            <strong>{session?.shift || shift}</strong>
          </div>
          <div>
            <p className="muted-label">Session ID</p>
            <strong>{session?.uuid || '-'}</strong>
          </div>
        </div>

        <div className="form-row">
          <label className="login-card">
            <span>Shift Hari Ini</span>
            <select value={shift} onChange={(event) => setShift(event.target.value)}>
              <option value="Pagi">Pagi</option>
              <option value="Sore">Sore</option>
              <option value="Malam">Malam</option>
            </select>
          </label>
          <button className="primary-button" type="button" onClick={handleStartShift} disabled={isWorking}>
            {session ? 'Shift Sudah Aktif' : 'Mulai Shift'}
          </button>
        </div>

        <div className="panel-stack">
          <article className="info-card">
            <div className="panel-header">
              <div>
                <p className="section-tag">Checkpoint Tools</p>
                <h3>NFC, QR, dan GPS checkpoint</h3>
              </div>
              <button className="toggle-button" type="button" onClick={() => setForceOffline((current) => !current)}>
                {forceOffline ? 'Kembali Online' : 'Simulasikan Offline'}
              </button>
            </div>
            <p className="microcopy">{statusMessage}</p>
            {successMessage ? <p className="success-banner">{successMessage}</p> : null}
            {error ? <p className="error-banner">{error}</p> : null}
          </article>

          <div className={`nfc-scan-panel ${isScanning ? 'is-active' : ''}`}>
            <div className="nfc-pulse"></div>
            <div>
              <p className="section-tag">Checkpoint Scanner</p>
              <h3>{isScanning ? 'Scanning NFC / QR...' : 'Siap melakukan checkpoint'}</h3>
            </div>
          </div>

          <div className="form-row">
            <button className="primary-button" type="button" onClick={handleNfcScan} disabled={!session || isWorking}>
              Scan NFC
            </button>
            <button className="secondary-button" type="button" onClick={handleQrScan} disabled={!session || isWorking}>
              Scan QR
            </button>
            <button className="secondary-button" type="button" onClick={handleManualSync} disabled={!session || !pendingLogs.length || !isOnline}>
              Sinkronkan Queue
            </button>
            <button className="secondary-button" type="button" onClick={handleEndShift} disabled={!session || isWorking}>
              Tutup Shift
            </button>
          </div>
        </div>
      </article>

      <article className="card monitor-panel">
        <div className="panel-header">
          <div>
            <p className="section-tag">Local Device Feed</p>
            <h3>Riwayat scan security</h3>
          </div>
        </div>

        <div className="activity-list">
          {logs.length ? (
            [...logs].reverse().map((log) => (
              <article className="activity-item" key={log.localUuid}>
                <div className="activity-head">
                  <div>
                    <strong>{log.checkpointName}</strong>
                    <div className="activity-meta">
                      <span>{log.buildingName}</span>
                      <span>{formatClock(log.scannedAt)}</span>
                      <span>{log.source}</span>
                    </div>
                  </div>
                  <span className={`status-badge status-${log.syncStatus}`}>{log.syncStatus}</span>
                </div>
                <div className="activity-meta">
                  <span>{log.message}</span>
                </div>
                {log.gpsLatitude != null && log.gpsLongitude != null ? (
                  <div className="gps-card">
                    <p>GPS: {log.gpsLatitude}, {log.gpsLongitude}</p>
                    {log.gpsMapUrl && !mapPreviewErrors[log.localUuid] ? (
                      <img
                        alt="GPS preview"
                        src={log.gpsMapUrl}
                        onError={() =>
                          setMapPreviewErrors((current) => ({
                            ...current,
                            [log.localUuid]: true,
                          }))
                        }
                      />
                    ) : (
                      <p className="gps-map-fallback">Preview map tidak tersedia. Gunakan tombol Buka Peta.</p>
                    )}
                    <div className="map-actions">
                      <a
                        className="secondary-button compact-button"
                        href={log.gpsOpenUrl || buildMapOpenUrl(log.gpsLatitude, log.gpsLongitude)}
                        rel="noreferrer"
                        target="_blank"
                      >
                        Buka Peta
                      </a>
                    </div>
                  </div>
                ) : null}
              </article>
            ))
          ) : (
            <div className="empty-card">Belum ada aktivitas. Mulai shift lalu scan checkpoint pertama.</div>
          )}
        </div>
      </article>
    </section>
  )
}
