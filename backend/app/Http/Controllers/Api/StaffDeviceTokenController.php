<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StaffDeviceToken;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StaffDeviceTokenController extends Controller
{
    public function store(Request $request)
    {
        $user = $request->user();
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', 'string', Rule::in(['android', 'ios'])],
            'device_id' => ['nullable', 'string', 'max:120'],
        ]);

        $record = StaffDeviceToken::updateOrCreate(
            ['token' => $validated['token']],
            [
                'user_id' => $user->id,
                'platform' => $validated['platform'],
                'device_id' => $validated['device_id'] ?? null,
                'last_seen_at' => now(),
            ]
        );

        return response()->json(['data' => $record], 201);
    }

    public function destroy(Request $request)
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        StaffDeviceToken::where('token', $validated['token'])->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
