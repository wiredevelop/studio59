<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AuthController extends Controller
{
    public function showLogin()
    {
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $request->validate([
            'login' => ['required_without:email', 'string'],
            'email' => ['required_without:login', 'email'],
            'password' => ['required', 'string'],
        ]);

        $login = $request->input('login', $request->input('email'));
        $password = (string) $request->input('password');

        $authenticated = Auth::attempt(['email' => $login, 'password' => $password], true)
            || Auth::attempt(['username' => $login, 'password' => $password], true);

        if (! $authenticated) {
            Audit::log('auth.login.failed', null, null, ['login' => $login]);
            return back()->withErrors(['login' => 'Credenciais invalidas'])->withInput();
        }

        $request->session()->regenerate();
        Audit::log('auth.login.success');

        return redirect()->route('dashboard');
    }

    public function logout(Request $request)
    {
        Audit::log('auth.logout');

        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
