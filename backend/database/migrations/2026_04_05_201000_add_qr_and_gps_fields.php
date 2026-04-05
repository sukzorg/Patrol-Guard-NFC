<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('checkpoints', function (Blueprint $table) {
            if (!Schema::hasColumn('checkpoints', 'qr_code')) {
                $table->string('qr_code')->nullable()->unique()->after('nfc_uid');
            }
        });

        Schema::table('patrol_logs', function (Blueprint $table) {
            if (!Schema::hasColumn('patrol_logs', 'gps_latitude')) {
                $table->decimal('gps_latitude', 10, 7)->nullable()->after('scanned_at');
                $table->decimal('gps_longitude', 10, 7)->nullable()->after('gps_latitude');
                $table->text('gps_map_url')->nullable()->after('gps_longitude');
            }
        });
    }

    public function down(): void
    {
        Schema::table('checkpoints', function (Blueprint $table) {
            if (Schema::hasColumn('checkpoints', 'qr_code')) {
                $table->dropUnique(['qr_code']);
                $table->dropColumn('qr_code');
            }
        });

        Schema::table('patrol_logs', function (Blueprint $table) {
            if (Schema::hasColumn('patrol_logs', 'gps_latitude')) {
                $table->dropColumn(['gps_latitude', 'gps_longitude', 'gps_map_url']);
            }
        });
    }
};
