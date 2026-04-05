<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'nik')) {
                $table->string('nik')->nullable()->unique()->after('name');
            }
        });

        DB::table('users')->where('role', 'guard')->update(['role' => 'security']);
        DB::table('roles')->where('slug', 'guard')->update([
            'slug' => 'security',
            'name' => 'Security',
            'description' => 'Petugas lapangan untuk proses patroli harian.',
        ]);
    }

    public function down(): void
    {
        DB::table('users')->where('role', 'security')->update(['role' => 'guard']);
        DB::table('roles')->where('slug', 'security')->update([
            'slug' => 'guard',
            'name' => 'Guard',
            'description' => 'Petugas lapangan untuk proses patroli harian.',
        ]);

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'nik')) {
                $table->dropUnique(['nik']);
                $table->dropColumn('nik');
            }
        });
    }
};
