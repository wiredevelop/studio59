<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PublicEnterEventRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'pin' => ['nullable', 'string', 'regex:/^\\d{4}$/'],
            'password' => ['nullable', 'string', 'regex:/^\\d{4}$/'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $pin = trim((string) $this->input('pin', ''));
            $password = trim((string) $this->input('password', ''));
            if ($pin === '' && $password === '') {
                $validator->errors()->add('pin', 'PIN obrigatório.');
            }
        });
    }
}
