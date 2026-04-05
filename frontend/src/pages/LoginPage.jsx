import { useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext.jsx'

const demoAccounts = [
  {
    title: 'Admin',
    identifier: 'admin@patrol.id',
    password: 'patrol123',
    note: 'Login admin tetap dapat menggunakan email.',
  },
  {
    title: 'Supervisor',
    identifier: '240010',
    password: 'patrol123',
    note: 'Supervisor login dengan NIK.',
  },
  {
    title: 'Security',
    identifier: '240001',
    password: 'patrol123',
    note: 'Security login dengan NIK untuk memulai patroli.',
  },
]

export function LoginPage() {
  const navigate = useNavigate()
  const { isAuthenticated, user, login } = useAuth()
  const [form, setForm] = useState({
    identifier: '240001',
    password: 'patrol123',
  })
  const [error, setError] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  if (isAuthenticated && user) {
    return (
      <Navigate
        to={user.role === 'admin' ? '/admin' : user.role === 'supervisor' ? '/supervisor' : '/security'}
        replace
      />
    )
  }

  async function handleSubmit(event) {
    event.preventDefault()
    setError('')
    setIsSubmitting(true)

    try {
      const nextAuth = await login(form)
      navigate(
        nextAuth.user.role === 'admin'
          ? '/admin'
          : nextAuth.user.role === 'supervisor'
            ? '/supervisor'
            : '/security',
        { replace: true },
      )
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <section className="auth-layout login-shell">
      <article className="hero card surface-grid wtc-hero">
        <div className="hero-copy">
          <div className="hero-brand">
            <div className="hero-mark">WTC</div>
            <div>
              <p className="section-tag">Management WTC Mangga Dua</p>
              <h2>Security Patrol & Monitoring Platform</h2>
            </div>
          </div>

          <p className="hero-text">
            Satu pintu operasional untuk Security, Supervisor, dan Admin dalam memantau patroli,
            checkpoint NFC, rekap periodik, dan laporan PDF.
          </p>

          <div className="hero-highlights">
            <article className="highlight-card">
              <span>01</span>
              <strong>Security Patrol</strong>
              <p>Mulai shift, scan checkpoint, simpan progres lokal, dan lanjutkan patroli kapan saja.</p>
            </article>
            <article className="highlight-card">
              <span>02</span>
              <strong>Supervisor Report</strong>
              <p>Lihat rekap harian, mingguan, bulanan, lalu export PDF langsung dari dashboard.</p>
            </article>
            <article className="highlight-card">
              <span>03</span>
              <strong>Admin Master Data</strong>
              <p>Kelola user, NIK, role, checkpoint, serta aktivitas sistem dari satu halaman.</p>
            </article>
          </div>
        </div>
      </article>

      <article className="card auth-card auth-card-branded">
        <div className="panel-header">
          <div>
            <p className="section-tag">Secure Login</p>
            <h3>Akses sistem operasional</h3>
          </div>
          <span className="pill pill-soft">Production style</span>
        </div>

        <form className="login-card" onSubmit={handleSubmit}>
          <label>
            <span>Email / NIK</span>
            <input
              type="text"
              value={form.identifier}
              onChange={(event) =>
                setForm((current) => ({ ...current, identifier: event.target.value }))
              }
              placeholder="Masukkan email admin atau NIK karyawan"
              required
            />
          </label>
          <label>
            <span>Password</span>
            <input
              type="password"
              value={form.password}
              onChange={(event) =>
                setForm((current) => ({ ...current, password: event.target.value }))
              }
              required
            />
          </label>

          {error ? <p className="error-banner">{error}</p> : null}

          <button className="primary-button" type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Memproses...' : 'Masuk ke Dashboard'}
          </button>
        </form>

        <div className="demo-grid">
          {demoAccounts.map((account) => (
            <button
              key={account.title}
              className="demo-card"
              type="button"
              onClick={() => setForm({ identifier: account.identifier, password: account.password })}
            >
              <strong>{account.title}</strong>
              <span>{account.identifier}</span>
              <p>{account.note}</p>
            </button>
          ))}
        </div>

        <p className="auth-footer-note">Developing Team IT WTC Mangga Dua</p>
      </article>
    </section>
  )
}
