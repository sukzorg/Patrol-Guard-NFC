import { useEffect, useState } from 'react'
import { useAuth } from '../context/AuthContext.jsx'
import {
  exportSupervisorReport,
  fetchSupervisorDashboard,
  fetchSupervisorReports,
} from '../lib/api.js'

function buildMapOpenUrl(latitude, longitude) {
  if (latitude == null || longitude == null) {
    return ''
  }

  return `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=18/${latitude}/${longitude}`
}

function formatDateTime(value) {
  if (!value) {
    return '-'
  }

  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

export function SupervisorPage() {
  const { token, user } = useAuth()
  const [dashboard, setDashboard] = useState(null)
  const [report, setReport] = useState(null)
  const [period, setPeriod] = useState('daily')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [isLoading, setIsLoading] = useState(true)
  const [mapPreviewErrors, setMapPreviewErrors] = useState({})

  useEffect(() => {
    let isCancelled = false

    async function loadData() {
      try {
        const [dashboardPayload, reportPayload] = await Promise.all([
          fetchSupervisorDashboard(token),
          fetchSupervisorReports(token, period),
        ])

        if (isCancelled) {
          return
        }

        setDashboard(dashboardPayload)
        setReport(reportPayload)
        setError('')
      } catch (requestError) {
        if (!isCancelled) {
          setError(requestError.message)
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false)
        }
      }
    }

    setIsLoading(true)
    loadData()
    return () => {
      isCancelled = true
    }
  }, [period, token])

  async function handleExport() {
    try {
      await exportSupervisorReport(token, period)
      setNotice('Export PDF supervisor berhasil diunduh.')
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  const stats = dashboard?.stats

  return (
    <section className="workspace">
      <article className="card monitor-panel">
        <div className="panel-header">
          <div>
            <p className="section-tag">Supervisor Board</p>
            <h3>Monitoring patroli untuk {user.name}</h3>
          </div>
          <span className="pill pill-soft">
            {dashboard?.generated_at ? `Refresh ${formatDateTime(dashboard.generated_at)}` : 'Menunggu data'}
          </span>
        </div>

        {error ? <p className="error-banner">{error}</p> : null}
        {!error && notice ? <p className="success-banner">{notice}</p> : null}

        <div className="summary-grid summary-grid-three">
          <article className="summary-tile"><span>Active Security</span><strong>{stats?.active_security ?? stats?.active_guards ?? 0}</strong></article>
          <article className="summary-tile"><span>Pending Sync</span><strong>{stats?.pending_sync ?? 0}</strong></article>
          <article className="summary-tile"><span>Coverage</span><strong>{stats?.coverage_percentage ?? 0}%</strong></article>
        </div>

        <article className="data-card">
          <div className="panel-header">
            <div>
              <p className="section-tag">Preview Report</p>
              <h3>Rekap sebelum export PDF</h3>
            </div>
            <div className="inline-actions">
              <select value={period} onChange={(event) => setPeriod(event.target.value)}>
                <option value="daily">Harian</option>
                <option value="weekly">Mingguan</option>
                <option value="monthly">Bulanan</option>
              </select>
              <button className="secondary-button compact-button" onClick={handleExport} type="button">
                Export PDF
              </button>
            </div>
          </div>
          <div className="queue-stats">
            <article><span>Periode</span><strong>{report?.range_label ?? '-'}</strong></article>
            <article><span>Total Scan</span><strong>{report?.summary?.total_scans ?? 0}</strong></article>
            <article><span>Security Aktif</span><strong>{report?.summary?.unique_security ?? 0}</strong></article>
          </div>
        </article>

        <div className="monitor-grid">
          <section className="timeline-card">
            <div className="panel-header">
              <div>
                <p className="section-tag">Active Sessions</p>
                <h3>Progress petugas yang sedang patroli</h3>
              </div>
            </div>

            <div className="session-list">
              {dashboard?.sessions?.length ? (
                dashboard.sessions.map((session) => {
                  const completion = session.total_checkpoints
                    ? Math.round((session.completed_checkpoints / session.total_checkpoints) * 100)
                    : 0

                  return (
                    <article className="session-item" key={session.id}>
                      <div className="session-head">
                        <div>
                          <strong>{session.security_name || session.guard_name}</strong>
                          <div className="session-meta">
                            <span>NIK {session.nik || '-'}</span>
                            <span>Shift {session.shift}</span>
                            <span>Mulai {formatDateTime(session.started_at)}</span>
                          </div>
                        </div>
                        <span className="status-badge status-online">{completion}%</span>
                      </div>
                      <div className="progress-track">
                        <div className="progress-bar" style={{ width: `${completion}%` }}></div>
                      </div>
                    </article>
                  )
                })
              ) : (
                <div className="empty-card">
                  {isLoading ? 'Mengambil data sesi dari backend...' : 'Belum ada sesi security yang aktif.'}
                </div>
              )}
            </div>
          </section>

          <section className="queue-card">
            <div className="panel-header">
              <div>
                <p className="section-tag">Top Security</p>
                <h3>Rekap performa periode terpilih</h3>
              </div>
            </div>

            <div className="panel-stack">
              {report?.security_breakdown?.length ? (
                report.security_breakdown.map((entry) => (
                  <article className="data-card" key={`${entry.label}-${entry.nik}`}>
                    <span>NIK {entry.nik || '-'}</span>
                    <strong>{entry.label}</strong>
                    <p>{entry.value} total scan pada periode ini</p>
                  </article>
                ))
              ) : (
                <div className="empty-card">Belum ada rekap security untuk periode ini.</div>
              )}
            </div>
          </section>
        </div>
      </article>

      <article className="card app-panel">
        <div className="panel-header">
          <div>
            <p className="section-tag">Recent Logs</p>
            <h3>Feed patroli terbaru</h3>
          </div>
        </div>

        <div className="activity-list">
          {dashboard?.recent_logs?.length ? (
            dashboard.recent_logs.map((log) => (
              <article className="activity-item" key={log.id}>
                <div className="activity-head">
                  <div>
                    <strong>{log.security_name || log.guard_name}</strong>
                    <div className="activity-meta">
                      <span>NIK {log.nik || '-'}</span>
                      <span>{log.checkpoint_name}</span>
                      <span>{formatDateTime(log.scanned_at)}</span>
                    </div>
                  </div>
                  <span className={`status-badge status-${log.sync_status}`}>{log.sync_status}</span>
                </div>
                <div className="activity-meta">
                  <span>{log.building_name}</span>
                </div>
                {log.gps_latitude != null && log.gps_longitude != null ? (
                  <div className="gps-card">
                    <p>GPS: {log.gps_latitude || '-'}, {log.gps_longitude || '-'}</p>
                    {log.gps_map_url && !mapPreviewErrors[log.id] ? (
                      <img
                        alt="GPS preview"
                        src={log.gps_map_url}
                        onError={() =>
                          setMapPreviewErrors((current) => ({
                            ...current,
                            [log.id]: true,
                          }))
                        }
                      />
                    ) : (
                      <p className="gps-map-fallback">Preview map tidak tersedia. Gunakan tombol Buka Peta.</p>
                    )}
                    <div className="map-actions">
                      <a
                        className="secondary-button compact-button"
                        href={log.gps_open_url || buildMapOpenUrl(log.gps_latitude, log.gps_longitude)}
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
            <div className="empty-card">
              {isLoading ? 'Menunggu feed patroli dari server...' : 'Belum ada log patroli di backend.'}
            </div>
          )}
        </div>
      </article>
    </section>
  )
}
