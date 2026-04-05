<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Checkpoint;

class CheckpointController extends Controller
{
    public function index()
    {
        return response()->json([
            'data' => Checkpoint::query()
                ->orderBy('sort_order')
                ->get()
                ->map(fn (Checkpoint $checkpoint) => [
                    'id' => $checkpoint->id,
                    'name' => $checkpoint->name,
                    'building_name' => $checkpoint->building_name,
                    'nfc_uid' => $checkpoint->nfc_uid,
                    'qr_code' => $checkpoint->qr_code,
                    'sort_order' => $checkpoint->sort_order,
                ]),
        ]);
    }
}
