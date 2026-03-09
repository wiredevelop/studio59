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

        if ($this->role === 'admin' && $permissions === []) {
            return true;
        }

        if ($this->role === 'photographer') {
            $allowed = [
                'dashboard.view',
                'events.read',
                'uploads.manage',
                'orders.read',
                'orders.write',
            ];

            return in_array($permission, $allowed, true);
        }

        return in_array($permission, $permissions, true);
    }

    public function permissionsList(): array
    {
        $permissions = $this->permissions ?? [];
        return is_array($permissions) ? $permissions : [];
    }
}
