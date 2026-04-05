<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'patrol_session_id',
    'checkpoint_id',
    'local_uuid',
    'scanned_at',
    'gps_latitude',
    'gps_longitude',
    'gps_map_url',
    'sync_status',
    'source',
    'synced_at',
])]
class PatrolLog extends Model
{
    protected function casts(): array
    {
        return [
            'scanned_at' => 'datetime',
            'synced_at' => 'datetime',
            'gps_latitude' => 'float',
            'gps_longitude' => 'float',
        ];
    }

    public function checkpoint()
    {
        return $this->belongsTo(Checkpoint::class);
    }

    public function patrolSession()
    {
        return $this->belongsTo(PatrolSession::class);
    }
}
