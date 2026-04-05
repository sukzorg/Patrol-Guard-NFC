<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ApiTokenAuth
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (! $token) {
            return response()->json([
                'message' => 'Bearer token diperlukan untuk mengakses API ini.',
            ], Response::HTTP_UNAUTHORIZED);
        }

        $user = User::query()
            ->where('api_token', $token)
            ->first();

        if (! $user) {
            return response()->json([
                'message' => 'Token tidak valid atau sudah tidak aktif.',
            ], Response::HTTP_UNAUTHORIZED);
        }

        $request->setUserResolver(fn () => $user);

        return $next($request);
    }
}
