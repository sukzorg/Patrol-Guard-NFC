<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <title>{{ $title }}</title>
    <style>
      body { font-family: DejaVu Sans, sans-serif; color: #0f172a; font-size: 12px; }
      h1, h2, h3, p { margin: 0; }
      .header { padding: 18px; border: 1px solid #cbd5e1; border-radius: 12px; background: #f8fafc; margin-bottom: 18px; }
      .brand { font-size: 11px; color: #475569; text-transform: uppercase; letter-spacing: 1px; }
      .title { margin-top: 6px; font-size: 20px; font-weight: bold; }
      .grid { width: 100%; margin: 14px 0 18px; border-collapse: separate; border-spacing: 8px; }
      .tile { background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 10px; padding: 10px; }
      .tile-label { font-size: 10px; color: #475569; text-transform: uppercase; }
      .tile-value { margin-top: 6px; font-size: 18px; font-weight: bold; }
      .section { margin-top: 18px; }
      .section h3 { margin-bottom: 10px; font-size: 14px; }
      table { width: 100%; border-collapse: collapse; }
      th, td { border: 1px solid #cbd5e1; padding: 8px; text-align: left; vertical-align: top; }
      th { background: #e2e8f0; }
      .muted { color: #64748b; }
    </style>
  </head>
  <body>
    <div class="header">
      <div class="brand">Management WTC Mangga Dua</div>
      <div class="title">{{ $title }}</div>
      <p class="muted">{{ $roleLabel }} | Periode {{ strtoupper($report['period']) }} | {{ $report['range_label'] }}</p>
    </div>

    <table class="grid">
      <tr>
        @foreach($report['summary'] as $label => $value)
          <td class="tile">
            <div class="tile-label">{{ str_replace('_', ' ', $label) }}</div>
            <div class="tile-value">{{ $value }}</div>
          </td>
        @endforeach
      </tr>
    </table>

    <div class="section">
      <h3>Rekap Security</h3>
      <table>
        <thead>
          <tr>
            <th>Nama</th>
            <th>NIK</th>
            <th>Total Scan</th>
          </tr>
        </thead>
        <tbody>
          @forelse($report['security_breakdown'] as $row)
            <tr>
              <td>{{ $row['label'] }}</td>
              <td>{{ $row['nik'] ?? '-' }}</td>
              <td>{{ $row['value'] }}</td>
            </tr>
          @empty
            <tr><td colspan="3">Belum ada data.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Rekap Checkpoint</h3>
      <table>
        <thead>
          <tr>
            <th>Checkpoint</th>
            <th>Area</th>
            <th>Total Scan</th>
          </tr>
        </thead>
        <tbody>
          @forelse($report['checkpoint_breakdown'] as $row)
            <tr>
              <td>{{ $row['label'] }}</td>
              <td>{{ $row['area'] ?? '-' }}</td>
              <td>{{ $row['value'] }}</td>
            </tr>
          @empty
            <tr><td colspan="3">Belum ada data.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Aktivitas Terbaru</h3>
      <table>
        <thead>
          <tr>
            <th>Security</th>
            <th>NIK</th>
            <th>Checkpoint</th>
            <th>Area</th>
            <th>Waktu</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          @forelse($report['recent_activity'] as $row)
            <tr>
              <td>{{ $row['security_name'] ?? '-' }}</td>
              <td>{{ $row['nik'] ?? '-' }}</td>
              <td>{{ $row['checkpoint_name'] ?? '-' }}</td>
              <td>{{ $row['building_name'] ?? '-' }}</td>
              <td>{{ $row['scanned_at'] ?? '-' }}</td>
              <td>{{ $row['sync_status'] ?? '-' }}</td>
            </tr>
          @empty
            <tr><td colspan="6">Belum ada data.</td></tr>
          @endforelse
        </tbody>
      </table>
    </div>
  </body>
</html>
