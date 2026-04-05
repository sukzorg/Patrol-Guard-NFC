<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['building_name', 'name', 'nfc_uid', 'qr_code', 'sort_order'])]
class Checkpoint extends Model
{
    public function logs()
    {
        return $this->hasMany(PatrolLog::class);
    }
}
