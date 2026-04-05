<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'slug', 'description'])]
class Permission extends Model
{
    public function roles()
    {
        return $this->belongsToMany(Role::class);
    }
}
