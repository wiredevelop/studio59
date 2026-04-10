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
            $maxDim = 1600;
            $scale = min(1, $maxDim / max($srcWidth, $srcHeight));
            $targetWidth = max(1, (int) round($srcWidth * $scale));
            $targetHeight = max(1, (int) round($srcHeight * $scale));
            $canvas = imagecreatetruecolor($targetWidth, $targetHeight);
            imagecopyresampled($canvas, $src, 0, 0, 0, 0, $targetWidth, $targetHeight, $srcWidth, $srcHeight);
            imagedestroy($src);

            $wmText = 'STUDIO 59';

            $fontPath = $this->resolveFontPath();

            if ($fontPath) {
                $fontSize = max(24, min(72, (int) round($targetWidth * 0.03)));
                $colorLight = imagecolorallocatealpha($canvas, 255, 255, 255, 100);
                for ($x = -300; $x < $targetWidth + 300; $x += 280) {
                    for ($y = -100; $y < $targetHeight + 200; $y += 180) {
                        imagettftext($canvas, $fontSize, -30, $x, $y, $colorLight, $fontPath, $wmText);
                    }
                }

                $shadow = imagecolorallocatealpha($canvas, 0, 0, 0, 55);
                $strong = imagecolorallocatealpha($canvas, 255, 255, 255, 20);
                $boxPadding = 16;
                $badgeSize = max(26, min(60, (int) round($targetWidth * 0.02)));
                $bbox = imagettfbbox($badgeSize, 0, $fontPath, $wmText);
                $textW = abs($bbox[2] - $bbox[0]);
                $textH = abs($bbox[7] - $bbox[1]);
                $x1 = $targetWidth - $textW - ($boxPadding * 2) - 20;
                $y1 = $targetHeight - $textH - ($boxPadding * 2) - 20;
                imagefilledrectangle($canvas, $x1, $y1, $targetWidth - 20, $targetHeight - 20, $shadow);
                imagettftext($canvas, $badgeSize, 0, $x1 + $boxPadding, $targetHeight - 20 - $boxPadding, $strong, $fontPath, $wmText);
            } else {
                $color = imagecolorallocatealpha($canvas, 255, 255, 255, 75);
                imagestring($canvas, 5, 20, $targetHeight - 30, $wmText, $color);
            }

            $previewPath = $photo->preview_path ?: $this->defaultPreviewPath($photo);
            Storage::disk('local')->makeDirectory(dirname($previewPath));

            $targetPath = Storage::disk('local')->path($previewPath);
            imageinterlace($canvas, true);
            imagejpeg($canvas, $targetPath, 82);
            imagedestroy($canvas);

            $photo->update([
                'preview_path' => $previewPath,
                'preview_status' => 'ready',
                'preview_error' => null,
                'status' => 'active',
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

    private function defaultPreviewPath(Photo $photo): string
    {
        $original = $photo->original_path;
        if (str_starts_with($original, 'EVENTOS/')) {
            $eventDir = dirname(dirname($original));
            return $eventDir.'/galeria/'.$photo->number.'.jpg';
        }

        return 'events/'.$photo->event_id.'/previews/'.$photo->number.'.jpg';
    }
}
