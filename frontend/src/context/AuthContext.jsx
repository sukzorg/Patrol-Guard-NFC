/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useState } from 'react'
import { loginRequest, logoutRequest } from '../lib/api.js'
import {
  AUTH_STORAGE_KEY,
  readStoredJson,
  removeStoredJson,
  writeStoredJson,
} from '../lib/storage.js'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [authState, setAuthState] = useState(() => readStoredJson(AUTH_STORAGE_KEY, null))

  useEffect(() => {
    if (authState) {
      writeStoredJson(AUTH_STORAGE_KEY, authState)
      return
    }

    removeStoredJson(AUTH_STORAGE_KEY)
  }, [authState])

  async function login(credentials) {
    const payload = await loginRequest(credentials)
    const nextState = { token: payload.token, user: payload.user }
    setAuthState(nextState)
    return nextState
  }

  async function logout() {
    try {
      if (authState?.token) {
        await logoutRequest(authState.token)
      }
    } catch {
      // Tetap lanjut hapus state lokal agar user tidak terkunci di browser.
    }

    setAuthState(null)
  }

  return (
    <AuthContext.Provider
      value={{
        token: authState?.token ?? null,
        user: authState?.user ?? null,
        isAuthenticated: Boolean(authState?.token),
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error('useAuth must be used inside AuthProvider')
  }

  return context
}
