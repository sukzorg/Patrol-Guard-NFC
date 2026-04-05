import { NavLink } from 'react-router-dom'
import { useAuth } from '../context/AuthContext.jsx'

export function AppShell({ children }) {
  const { user, logout } = useAuth()

  return (
    <div className="page-shell">
      <div className="ambient ambient-left"></div>
      <div className="ambient ambient-right"></div>

      <header className="topbar">
        <div className="brand-lockup">
          <div className="brand-mark" aria-hidden="true">
            WTC
          </div>
          <div>
            <p className="eyebrow">Management WTC Mangga Dua</p>
            <h1>Security Control Center</h1>
          </div>
        </div>

        <div className="topbar-actions">
          <nav className="nav-pills" aria-label="Primary">
            <NavLink className="nav-pill" to="/login">
              Login
            </NavLink>
            <NavLink className="nav-pill" to="/admin">
              Admin
            </NavLink>
            <NavLink className="nav-pill" to="/security">
              Security App
            </NavLink>
            <NavLink className="nav-pill" to="/supervisor">
              Supervisor
            </NavLink>
          </nav>

          {user ? (
            <div className="account-box">
              <div>
                <p className="muted-label">Signed in as</p>
                <strong>{user.name}</strong>
                <p className="muted-inline">{user.role === 'security' ? `NIK ${user.nik}` : user.email}</p>
              </div>
              <button className="secondary-button compact-button" onClick={logout} type="button">
                Logout
              </button>
            </div>
          ) : (
            <div className="account-box guest-box">
              <span className="pill pill-outline">Offline-first demo</span>
            </div>
          )}
        </div>
      </header>

      <main>{children}</main>
    </div>
  )
}
