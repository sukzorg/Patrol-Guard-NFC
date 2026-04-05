const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

async function apiRequest(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  })

  const payload = await response.json().catch(() => ({}))

  if (!response.ok) {
    throw new Error(payload.message || 'Request API gagal diproses.')
  }

  return payload
}

export function loginRequest(credentials) {
  return apiRequest('/login', { method: 'POST', body: credentials })
}

export function logoutRequest(token) {
  return apiRequest('/logout', { method: 'POST', token })
}

export function fetchCheckpoints(token) {
  return apiRequest('/checkpoints', { token })
}

export function startPatrol(token, body) {
  return apiRequest('/patrol/start', { method: 'POST', token, body })
}

export function scanCheckpoint(token, body) {
  return apiRequest('/patrol/scan', { method: 'POST', token, body })
}

export function syncPatrolLogs(token, body) {
  return apiRequest('/patrol/sync', { method: 'POST', token, body })
}

export function endPatrol(token, body) {
  return apiRequest('/patrol/end', { method: 'POST', token, body })
}

export function fetchSupervisorDashboard(token) {
  return apiRequest('/supervisor/dashboard', { token })
}

export function fetchSupervisorReports(token, period) {
  return apiRequest(`/supervisor/reports?period=${period}`, { token })
}

export function fetchAdminDashboard(token) {
  return apiRequest('/admin/dashboard', { token })
}

export function fetchAdminReports(token, period) {
  return apiRequest(`/admin/reports?period=${period}`, { token })
}

export function fetchAdminMasterData(token) {
  return apiRequest('/admin/master-data', { token })
}

export function fetchAdminUsers(token) {
  return apiRequest('/admin/users', { token })
}

export function createAdminUser(token, body) {
  return apiRequest('/admin/users', { method: 'POST', token, body })
}

export function updateAdminUser(token, userId, body) {
  return apiRequest(`/admin/users/${userId}`, { method: 'PUT', token, body })
}

export function deleteAdminUser(token, userId) {
  return apiRequest(`/admin/users/${userId}`, { method: 'DELETE', token })
}

export function fetchAdminCheckpoints(token) {
  return apiRequest('/admin/checkpoints', { token })
}

export function createAdminCheckpoint(token, body) {
  return apiRequest('/admin/checkpoints', { method: 'POST', token, body })
}

export function updateAdminCheckpoint(token, checkpointId, body) {
  return apiRequest(`/admin/checkpoints/${checkpointId}`, { method: 'PUT', token, body })
}

export function deleteAdminCheckpoint(token, checkpointId) {
  return apiRequest(`/admin/checkpoints/${checkpointId}`, { method: 'DELETE', token })
}

async function exportPdf(path, token, filename) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      Accept: 'application/pdf',
      Authorization: `Bearer ${token}`,
    },
  })

  if (!response.ok) {
    let payload = {}
    try {
      payload = await response.json()
    } catch {
      payload = {}
    }
    throw new Error(payload.message || 'Export PDF gagal diproses.')
  }

  const blob = await response.blob()
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}

export function exportSupervisorReport(token, period) {
  return exportPdf(`/supervisor/reports/export?period=${period}`, token, `supervisor-${period}.pdf`)
}

export function exportAdminReport(token, period) {
  return exportPdf(`/admin/reports/export?period=${period}`, token, `admin-${period}.pdf`)
}
