<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'identifier' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'string', 'max:191'],
            'nik' => ['nullable', 'string', 'max:100'],
            'password' => ['required', 'string'],
        ]);

        $identifier = $credentials['identifier'] ?? $credentials['email'] ?? $credentials['nik'] ?? null;

        if (! filled($identifier)) {
            return response()->json([
                'message' => 'Email atau NIK wajib diisi.',
            ], 422);
        }

        $user = User::query()
            ->where(fn ($query) => $query
                ->where('email', $identifier)
                ->orWhere('nik', $identifier))
            ->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            return response()->json([
                'message' => 'Email/NIK atau password tidak sesuai.',
            ], 422);
        }

        $user->forceFill([
            'api_token' => hash('sha256', Str::random(60)),
        ])->save();

        return response()->json([
            'message' => 'Login berhasil.',
            'token' => $user->api_token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'nik' => $user->nik,
                'email' => $user->email,
                'role' => $user->role,
                'role_id' => $user->role_id,
            ],
        ]);
    }

    public function logout(Request $request)
    {
        $user = $request->user();

        if ($user) {
            $user->forceFill([
                'api_token' => null,
            ])->save();
        }

        return response()->json([
            'message' => 'Sesi berhasil ditutup.',
        ]);
    }
}
