import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../context/AuthContext.jsx'
import {
  createAdminCheckpoint,
  createAdminUser,
  deleteAdminCheckpoint,
  deleteAdminUser,
  exportAdminReport,
  fetchAdminCheckpoints,
  fetchAdminDashboard,
  fetchAdminMasterData,
  fetchAdminReports,
  fetchAdminUsers,
  updateAdminCheckpoint,
  updateAdminUser,
} from '../lib/api.js'

const defaultUserForm = { id: null, name: '', nik: '', email: '', password: '', role_id: '' }
const defaultCheckpointForm = { id: null, building_name: '', name: '', nfc_uid: '', qr_code: '', sort_order: 1 }

export function AdminPage() {
  const { token, user } = useAuth()
  const [dashboard, setDashboard] = useState(null)
  const [report, setReport] = useState(null)
  const [masterData, setMasterData] = useState({ roles: [], permissions: [] })
  const [users, setUsers] = useState([])
  const [checkpoints, setCheckpoints] = useState([])
  const [userForm, setUserForm] = useState(defaultUserForm)
  const [checkpointForm, setCheckpointForm] = useState(defaultCheckpointForm)
  const [period, setPeriod] = useState('daily')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('Admin panel siap dipakai.')
  const [isLoading, setIsLoading] = useState(true)

  const loadAdminData = useCallback(async () => {
    setIsLoading(true)
    try {
      const [dashboardPayload, reportPayload, masterPayload, usersPayload, checkpointsPayload] = await Promise.all([
        fetchAdminDashboard(token),
        fetchAdminReports(token, period),
        fetchAdminMasterData(token),
        fetchAdminUsers(token),
        fetchAdminCheckpoints(token),
      ])
      setDashboard(dashboardPayload)
      setReport(reportPayload)
      setMasterData(masterPayload)
      setUsers(usersPayload.data)
      setCheckpoints(checkpointsPayload.data)
      setError('')
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setIsLoading(false)
    }
  }, [period, token])

  useEffect(() => {
    loadAdminData()
  }, [loadAdminData])

  async function handleUserSubmit(event) {
    event.preventDefault()
    try {
      if (userForm.id) {
        await updateAdminUser(token, userForm.id, {
          name: userForm.name,
          nik: userForm.nik,
          email: userForm.email,
          password: userForm.password || undefined,
          role_id: Number(userForm.role_id),
        })
        setNotice('Data user berhasil diperbarui.')
      } else {
        await createAdminUser(token, {
          name: userForm.name,
          nik: userForm.nik,
          email: userForm.email,
          password: userForm.password,
          role_id: Number(userForm.role_id),
        })
        setNotice('User baru berhasil dibuat.')
      }
      setUserForm(defaultUserForm)
      await loadAdminData()
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  async function handleCheckpointSubmit(event) {
    event.preventDefault()

    const duplicate = checkpoints.find((entry) => {
      if (checkpointForm.id && entry.id === checkpointForm.id) {
        return false
      }

      const sameNfc = checkpointForm.nfc_uid && entry.nfc_uid === checkpointForm.nfc_uid
      const sameQr = checkpointForm.qr_code && entry.qr_code === checkpointForm.qr_code
      const differentIdentity =
        entry.name !== checkpointForm.name || entry.building_name !== checkpointForm.building_name

      return differentIdentity && (sameNfc || sameQr)
    })

    if (duplicate) {
      const accepted = window.confirm(
        `Kode ini sudah dipakai oleh ${duplicate.name} di area ${duplicate.building_name}. Lanjutkan?`,
      )
      if (!accepted) {
        return
      }
    }

    try {
      if (checkpointForm.id) {
        await updateAdminCheckpoint(token, checkpointForm.id, {
          building_name: checkpointForm.building_name,
          name: checkpointForm.name,
          nfc_uid: checkpointForm.nfc_uid,
          qr_code: checkpointForm.qr_code,
          sort_order: Number(checkpointForm.sort_order),
        })
        setNotice('Checkpoint berhasil diperbarui.')
      } else {
        await createAdminCheckpoint(token, {
          building_name: checkpointForm.building_name,
          name: checkpointForm.name,
          nfc_uid: checkpointForm.nfc_uid,
          qr_code: checkpointForm.qr_code,
          sort_order: Number(checkpointForm.sort_order),
        })
        setNotice('Checkpoint baru berhasil dibuat.')
      }

      setCheckpointForm(defaultCheckpointForm)
      await loadAdminData()
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  async function handleDeleteUser(id) {
    await deleteAdminUser(token, id)
    await loadAdminData()
  }

  async function handleDeleteCheckpoint(id) {
    await deleteAdminCheckpoint(token, id)
    await loadAdminData()
  }

  async function handleExport() {
    try {
      await exportAdminReport(token, period)
      setNotice('Export PDF admin berhasil diunduh.')
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  const stats = dashboard?.stats

  return (
    <section className="workspace admin-layout">
      <article className="card monitor-panel">
        <div className="panel-header">
          <div>
            <p className="section-tag">Admin Dashboard</p>
            <h3>Kontrol master data untuk {user.name}</h3>
          </div>
          <button className="secondary-button compact-button" onClick={loadAdminData} type="button">
            Refresh Data
          </button>
        </div>

        {error ? <p className="error-banner">{error}</p> : null}
        {!error ? <p className="success-banner">{notice}</p> : null}

        <div className="summary-grid summary-grid-three">
          <article className="summary-tile"><span>Users</span><strong>{stats?.total_users ?? 0}</strong></article>
          <article className="summary-tile"><span>Checkpoint</span><strong>{stats?.total_checkpoints ?? 0}</strong></article>
          <article className="summary-tile"><span>Logs</span><strong>{stats?.total_logs ?? 0}</strong></article>
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
            <article><span>New Users</span><strong>{report?.summary?.new_users ?? 0}</strong></article>
            <article><span>Total Scan</span><strong>{report?.summary?.total_scans ?? 0}</strong></article>
          </div>
        </article>
      </article>

      <article className="card app-panel">
        <div className="admin-sections">
          <section className="data-card">
            <div className="panel-header">
              <div>
                <p className="section-tag">Users</p>
                <h3>Kelola akun aplikasi</h3>
              </div>
            </div>

            <form className="form-stack" onSubmit={handleUserSubmit}>
              <input placeholder="Nama" value={userForm.name} onChange={(event) => setUserForm((current) => ({ ...current, name: event.target.value }))} required />
              <input placeholder="NIK" value={userForm.nik} onChange={(event) => setUserForm((current) => ({ ...current, nik: event.target.value }))} required />
              <input type="email" placeholder="Email" value={userForm.email} onChange={(event) => setUserForm((current) => ({ ...current, email: event.target.value }))} required />
              <input type="password" placeholder={userForm.id ? 'Password baru (opsional)' : 'Password'} value={userForm.password} onChange={(event) => setUserForm((current) => ({ ...current, password: event.target.value }))} required={!userForm.id} />
              <select value={userForm.role_id} onChange={(event) => setUserForm((current) => ({ ...current, role_id: event.target.value }))} required>
                <option value="">Pilih role</option>
                {masterData.roles.map((role) => (
                  <option key={role.id} value={role.id}>{role.name}</option>
                ))}
              </select>
              <button className="primary-button" type="submit">{userForm.id ? 'Update User' : 'Tambah User'}</button>
            </form>

            <div className="table-wrap">
              <table className="data-table">
                <thead><tr><th>Nama</th><th>NIK</th><th>Email</th><th>Role</th><th>Aksi</th></tr></thead>
                <tbody>
                  {users.map((entry) => (
                    <tr key={entry.id}>
                      <td>{entry.name}</td>
                      <td>{entry.nik}</td>
                      <td>{entry.email}</td>
                      <td>{entry.role_name || entry.role}</td>
                      <td className="action-cell">
                        <button className="secondary-button compact-button" type="button" onClick={() => setUserForm({ id: entry.id, name: entry.name, nik: entry.nik, email: entry.email, password: '', role_id: String(entry.role_id ?? '') })}>Edit</button>
                        <button className="secondary-button compact-button danger-button" type="button" onClick={() => handleDeleteUser(entry.id)}>Hapus</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="data-card">
            <div className="panel-header">
              <div>
                <p className="section-tag">Checkpoint</p>
                <h3>Daftarkan NFC UID dan QR Code</h3>
              </div>
            </div>

            <form className="form-stack" onSubmit={handleCheckpointSubmit}>
              <input placeholder="Area / Gedung" value={checkpointForm.building_name} onChange={(event) => setCheckpointForm((current) => ({ ...current, building_name: event.target.value }))} required />
              <input placeholder="Nama Checkpoint" value={checkpointForm.name} onChange={(event) => setCheckpointForm((current) => ({ ...current, name: event.target.value }))} required />
              <input placeholder="NFC UID" value={checkpointForm.nfc_uid} onChange={(event) => setCheckpointForm((current) => ({ ...current, nfc_uid: event.target.value.toUpperCase() }))} required />
              <input placeholder="QR Code" value={checkpointForm.qr_code} onChange={(event) => setCheckpointForm((current) => ({ ...current, qr_code: event.target.value.toUpperCase() }))} />
              <input type="number" min="1" placeholder="Urutan" value={checkpointForm.sort_order} onChange={(event) => setCheckpointForm((current) => ({ ...current, sort_order: event.target.value }))} required />
              <button className="primary-button" type="submit">{checkpointForm.id ? 'Update Checkpoint' : 'Tambah Checkpoint'}</button>
            </form>

            <div className="table-wrap">
              <table className="data-table">
                <thead><tr><th>Nama</th><th>Area</th><th>NFC UID</th><th>QR Code</th><th>Aksi</th></tr></thead>
                <tbody>
                  {checkpoints.map((entry) => (
                    <tr key={entry.id}>
                      <td>{entry.name}</td>
                      <td>{entry.building_name}</td>
                      <td>{entry.nfc_uid}</td>
                      <td>{entry.qr_code || '-'}</td>
                      <td className="action-cell">
                        <button className="secondary-button compact-button" type="button" onClick={() => setCheckpointForm({ id: entry.id, building_name: entry.building_name, name: entry.name, nfc_uid: entry.nfc_uid, qr_code: entry.qr_code || '', sort_order: entry.sort_order })}>Edit</button>
                        <button className="secondary-button compact-button danger-button" type="button" onClick={() => handleDeleteCheckpoint(entry.id)}>Hapus</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>

        {isLoading ? <div className="empty-card">Memuat data admin...</div> : null}
      </article>
    </section>
  )
}
