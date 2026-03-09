<?php

namespace App\Jobs;

use App\Models\Photo;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Storage;
use Throwable;

class GeneratePhotoPreview implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $photoId)
    {
    }

    public function handle(): void
    {
        $photo = Photo::with('event')->find($this->photoId);

        if (! $photo || ! Storage::disk('local')->exists($photo->original_path)) {
            return;
        }

        if ($photo->preview_path && Storage::disk('local')->exists($photo->preview_path)) {
            if ($photo->preview_status !== 'ready') {
                $photo->update(['preview_status' => 'ready', 'preview_error' => null]);
            }
            return;
        }

        $photo->update(['preview_status' => 'pending', 'preview_error' => null]);

        try {
            $sourcePath = Storage::disk('local')->path($photo->original_path);
            $src = @imagecreatefromjpeg($sourcePath);

            if (! $src) {
                throw new \RuntimeException('Could not read JPEG source.');
            }

            $srcWidth = imagesx($src);
            $srcHeight = imagesy($src);
            $maxSide = 2000;

            if ($srcWidth >= $srcHeight) {
                $newWidth = min($srcWidth, $maxSide);
                $newHeight = (int) round(($srcHeight / $srcWidth) * $newWidth);
            } else {
                $newHeight = min($srcHeight, $maxSide);
                $newWidth = (int) round(($srcWidth / $srcHeight) * $newHeight);
            }

            $canvas = imagecreatetruecolor($newWidth, $newHeight);
            imagecopyresampled($canvas, $src, 0, 0, 0, 0, $newWidth, $newHeight, $srcWidth, $srcHeight);
            imagedestroy($src);

            $wmText = sprintf(
                'STUDIO 59 | %s | %s | %s',
                $photo->event->name,
                $photo->event->event_date->format('Y-m-d'),
                $photo->number
            );

            $fontPath = $this->resolveFontPath();

            if ($fontPath) {
                $colorLight = imagecolorallocatealpha($canvas, 255, 255, 255, 100);
                for ($x = -300; $x < $newWidth + 300; $x += 280) {
                    for ($y = -100; $y < $newHeight + 200; $y += 180) {
                        imagettftext($canvas, 18, -30, $x, $y, $colorLight, $fontPath, $wmText);
                    }
                }

                $shadow = imagecolorallocatealpha($canvas, 0, 0, 0, 55);
                $strong = imagecolorallocatealpha($canvas, 255, 255, 255, 20);
                $boxPadding = 16;
                $fontSize = 20;
                $bbox = imagettfbbox($fontSize, 0, $fontPath, $wmText);
                $textW = abs($bbox[2] - $bbox[0]);
                $textH = abs($bbox[7] - $bbox[1]);
                $x1 = $newWidth - $textW - ($boxPadding * 2) - 20;
                $y1 = $newHeight - $textH - ($boxPadding * 2) - 20;
                imagefilledrectangle($canvas, $x1, $y1, $newWidth - 20, $newHeight - 20, $shadow);
                imagettftext($canvas, $fontSize, 0, $x1 + $boxPadding, $newHeight - 20 - $boxPadding, $strong, $fontPath, $wmText);
            } else {
                $color = imagecolorallocatealpha($canvas, 255, 255, 255, 75);
                imagestring($canvas, 5, 20, $newHeight - 30, $wmText, $color);
            }

            $previewPath = 'events/'.$photo->event_id.'/previews/'.$photo->number.'.jpg';
            Storage::disk('local')->makeDirectory(dirname($previewPath));

            $targetPath = Storage::disk('local')->path($previewPath);
            imagejpeg($canvas, $targetPath, 65);
            imagedestroy($canvas);

            $photo->update([
                'preview_path' => $previewPath,
                'preview_status' => 'ready',
                'preview_error' => null,
            ]);
        } catch (Throwable $e) {
            $photo->update([
                'preview_status' => 'failed',
                'preview_error' => $e->getMessage(),
            ]);
        }
    }

    private function resolveFontPath(): ?string
    {
        $candidates = [
            resource_path('fonts/DejaVuSans.ttf'),
            'C:\\Windows\\Fonts\\arial.ttf',
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        ];

        foreach ($candidates as $candidate) {
            if (is_file($candidate)) {
                return $candidate;
            }
        }

        return null;
    }
}
