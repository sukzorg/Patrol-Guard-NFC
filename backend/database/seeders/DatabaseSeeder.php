<?php

namespace Database\Seeders;

use App\Models\Checkpoint;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $adminRole = Role::query()->updateOrCreate(
            ['slug' => 'admin'],
            [
                'name' => 'Administrator',
                'description' => 'Mengelola master data, user, checkpoint, dan dashboard.',
            ],
        );

        $securityRole = Role::query()->updateOrCreate(
            ['slug' => 'security'],
            [
                'name' => 'Security',
                'description' => 'Petugas lapangan untuk proses patroli harian.',
            ],
        );

        $supervisorRole = Role::query()->updateOrCreate(
            ['slug' => 'supervisor'],
            [
                'name' => 'Supervisor',
                'description' => 'Pemantau operasional dan histori patroli.',
            ],
        );

        $permissions = collect([
            ['name' => 'Manage Users', 'slug' => 'manage-users', 'description' => 'CRUD data user aplikasi'],
            ['name' => 'Manage Checkpoints', 'slug' => 'manage-checkpoints', 'description' => 'CRUD titik checkpoint'],
            ['name' => 'View Dashboard', 'slug' => 'view-dashboard', 'description' => 'Melihat dashboard analitik'],
            ['name' => 'Run Patrol', 'slug' => 'run-patrol', 'description' => 'Menjalankan sesi patroli'],
        ])->map(fn (array $permission) => Permission::query()->updateOrCreate(
            ['slug' => $permission['slug']],
            $permission,
        ));

        $adminRole->permissions()->sync($permissions->pluck('id')->all());
        $securityRole->permissions()->sync(
            $permissions->whereIn('slug', ['run-patrol'])->pluck('id')->all(),
        );
        $supervisorRole->permissions()->sync(
            $permissions->whereIn('slug', ['view-dashboard'])->pluck('id')->all(),
        );

        User::query()->updateOrCreate(
            ['email' => 'admin@patrol.id'],
            [
                'name' => 'Admin Patrol',
                'nik' => '100001',
                'role' => 'admin',
                'role_id' => $adminRole->id,
                'password' => 'patrol123',
            ],
        );

        User::query()->updateOrCreate(
            ['email' => 'guard@patrol.id'],
            [
                'name' => 'Dimas Pratama',
                'nik' => '240001',
                'role' => 'security',
                'role_id' => $securityRole->id,
                'password' => 'patrol123',
            ],
        );

        User::query()->updateOrCreate(
            ['email' => 'supervisor@patrol.id'],
            [
                'name' => 'Rina Supervisor',
                'nik' => '240010',
                'role' => 'supervisor',
                'role_id' => $supervisorRole->id,
                'password' => 'patrol123',
            ],
        );

        Checkpoint::query()->upsert([
            [
                'building_name' => 'Gedung A',
                'name' => 'Lobby Timur',
                'nfc_uid' => 'NFC-A1-7782',
                'qr_code' => 'WTC-QR-001',
                'sort_order' => 1,
            ],
            [
                'building_name' => 'Lantai 2',
                'name' => 'Ruang Server',
                'nfc_uid' => 'NFC-B3-1209',
                'qr_code' => 'WTC-QR-002',
                'sort_order' => 2,
            ],
            [
                'building_name' => 'Basement',
                'name' => 'Koridor Parkir',
                'nfc_uid' => 'NFC-C4-4431',
                'qr_code' => 'WTC-QR-003',
                'sort_order' => 3,
            ],
            [
                'building_name' => 'Area Belakang',
                'name' => 'Loading Dock',
                'nfc_uid' => 'NFC-D7-2290',
                'qr_code' => 'WTC-QR-004',
                'sort_order' => 4,
            ],
            [
                'building_name' => 'Lantai 12',
                'name' => 'Rooftop Access',
                'nfc_uid' => 'NFC-E2-9188',
                'qr_code' => 'WTC-QR-005',
                'sort_order' => 5,
            ],
        ], ['nfc_uid'], ['building_name', 'name', 'qr_code', 'sort_order']);
    }
}
