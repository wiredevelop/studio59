<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'username',
        'email',
        'password',
        'role',
        'permissions',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'permissions' => 'array',
        ];
    }

    public function hasPermission(string $permission): bool
    {
        $permissions = $this->permissions ?? [];
        if (! is_array($permissions)) {
            $permissions = [];
        }

        if ($this->role === 'admin') {
            return true;
        }

        $legacyMap = [
            'events.list' => ['events.read', 'events.calendar'],
            'events.view' => ['events.read'],
            'events.create' => ['events.write'],
            'events.update' => ['events.write'],
            'events.delete' => ['events.write'],
            'uploads.list' => ['uploads.manage'],
            'uploads.create' => ['uploads.manage'],
            'photos.list' => ['photos.manage'],
            'photos.update' => ['photos.manage'],
            'photos.delete' => ['photos.manage'],
            'photos.bulk_delete' => ['photos.manage'],
            'photos.original' => ['photos.manage'],
            'orders.list' => ['orders.read'],
            'orders.view' => ['orders.read'],
            'orders.update' => ['orders.write'],
            'orders.bulk' => ['orders.write'],
            'orders.download' => ['orders.download'],
            'orders.export' => ['orders.export'],
            'users.list' => ['users.manage'],
            'users.view' => ['users.manage'],
            'users.create' => ['users.manage'],
            'users.update' => ['users.manage'],
            'users.delete' => ['users.manage'],
            'clients.list' => ['clients.read'],
            'clients.view' => ['clients.read'],
            'clients.create' => ['clients.write'],
            'clients.update' => ['clients.write'],
            'clients.delete' => ['clients.write'],
            'offline.export' => ['events.read'],
            'offline.import' => ['events.write'],
        ];

        if (in_array($permission, $permissions, true)) {
            return true;
        }

        foreach ($legacyMap[$permission] ?? [] as $legacy) {
            if (in_array($legacy, $permissions, true)) {
                return true;
            }
        }

        if ($this->role === 'photographer') {
            $allowed = [
                'dashboard.view',
                'events.list',
                'events.view',
                'uploads.list',
                'uploads.create',
                'orders.list',
                'orders.view',
                'orders.update',
            ];

            return in_array($permission, $allowed, true);
        }

        if ($this->role === 'staff' && $permissions === []) {
            $fallback = [
                'dashboard.view',
                'events.list',
                'photos.list',
            ];
            if (in_array($permission, $fallback, true)) {
                return true;
            }
        }

        return false;
    }

    public function permissionsList(): array
    {
        $permissions = $this->permissions ?? [];
        return is_array($permissions) ? $permissions : [];
    }
}
