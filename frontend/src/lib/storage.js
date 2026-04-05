export const AUTH_STORAGE_KEY = 'patrol.auth'
export function getSecuritySessionStorageKey(userId) {
  return `patrol.security.session.${userId}`
}

export function getSecurityLogsStorageKey(userId) {
  return `patrol.security.logs.${userId}`
}

export function readStoredJson(key, fallbackValue) {
  try {
    const rawValue = window.localStorage.getItem(key)
    return rawValue ? JSON.parse(rawValue) : fallbackValue
  } catch {
    return fallbackValue
  }
}

export function writeStoredJson(key, value) {
  window.localStorage.setItem(key, JSON.stringify(value))
}

export function removeStoredJson(key) {
  window.localStorage.removeItem(key)
}
