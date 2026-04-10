<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ChunkUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'upload_id' => ['required', 'string', 'max:100'],
            'file_name' => ['required', 'string', 'max:255'],
            'chunk_index' => ['required', 'integer', 'min:0'],
            'total_chunks' => ['required', 'integer', 'min:1', 'max:40000'],
            'chunk' => ['required', 'file', 'mimes:jpg,jpeg', 'max:102400'],
        ];
    }
}
