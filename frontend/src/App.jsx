import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell.jsx'
import { ProtectedRoute } from './components/ProtectedRoute.jsx'
import { useAuth } from './context/AuthContext.jsx'
import { GuardPage } from './pages/GuardPage.jsx'
import { AdminPage } from './pages/AdminPage.jsx'
import { LoginPage } from './pages/LoginPage.jsx'
import { SupervisorPage } from './pages/SupervisorPage.jsx'

function RootRedirect() {
  const { user } = useAuth()

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (user.role === 'admin') {
    return <Navigate to="/admin" replace />
  }

  return <Navigate to={user.role === 'supervisor' ? '/supervisor' : '/security'} replace />
}

function App() {
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<RootRedirect />} />
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/admin"
          element={
            <ProtectedRoute allowedRoles={['admin']}>
              <AdminPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/security"
          element={
            <ProtectedRoute allowedRoles={['security', 'admin']}>
              <GuardPage />
            </ProtectedRoute>
          }
        />
        <Route path="/guard" element={<Navigate to="/security" replace />} />
        <Route
          path="/supervisor"
          element={
            <ProtectedRoute allowedRoles={['supervisor', 'admin']}>
              <SupervisorPage />
            </ProtectedRoute>
          }
        />
        <Route path="*" element={<RootRedirect />} />
      </Routes>
    </AppShell>
  )
}

export default App
