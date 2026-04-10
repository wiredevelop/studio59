<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PublicCreateOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'event_id' => ['required', 'exists:events,id'],
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:50'],
            'customer_email' => ['required', 'email', 'max:255'],
            'payment_method' => ['required', 'in:cash,online'],
            'product_type' => ['required', 'in:digital,paper,both'],
            'delivery_type' => ['nullable', 'in:pickup,shipping'],
            'delivery_address' => ['nullable', 'string', 'max:1000'],
            'wants_film' => ['nullable', 'boolean'],
            'photo_ids' => ['nullable', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'exists:photos,id'],
            'photo_items' => ['nullable', 'array', 'min:1'],
            'photo_items.*.photo_id' => ['required_with:photo_items', 'integer', 'exists:photos,id'],
            'photo_items.*.quantity' => ['required_with:photo_items', 'integer', 'min:1', 'max:50'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            if ($this->input('delivery_type') === 'shipping' && empty($this->input('delivery_address'))) {
                $validator->errors()->add('delivery_address', 'Morada obrigatória para envio.');
            }
        });
    }
}
