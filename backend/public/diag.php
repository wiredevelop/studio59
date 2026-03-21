<?php
declare(strict_types=1);

function bytesToHuman(int $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $i = 0;
    $value = $bytes;
    while ($value >= 1024 && $i < count($units) - 1) {
        $value /= 1024;
        $i++;
    }
    return sprintf('%.2f %s', $value, $units[$i]);
}

function iniToBytes(string $val): int
{
    $val = trim($val);
    if ($val === '') return 0;
    $last = strtolower($val[strlen($val) - 1]);
    $num = (int) $val;
    switch ($last) {
        case 'g': return $num * 1024 * 1024 * 1024;
        case 'm': return $num * 1024 * 1024;
        case 'k': return $num * 1024;
        default: return (int) $val;
    }
}

function check(string $label, bool $ok, string $detail = ''): string
{
    $status = $ok ? 'OK' : 'FALTA';
    $color = $ok ? '#1f7a1f' : '#b00020';
    $detail = $detail ? " — {$detail}" : '';
    return "<div style=\"margin:6px 0\"><strong>{$label}</strong>: <span style=\"color:{$color}\">{$status}</span>{$detail}</div>";
}

$basePath = dirname(__DIR__);
$storagePath = $basePath.'/storage/app/private';
$eventsPath = $storagePath.'/EVENTOS';

$phpVersion = PHP_VERSION;
$uploadMax = ini_get('upload_max_filesize') ?: '';
$postMax = ini_get('post_max_size') ?: '';
$memoryLimit = ini_get('memory_limit') ?: '';
$maxExec = ini_get('max_execution_time') ?: '';
$gd = extension_loaded('gd');
$exif = extension_loaded('exif');
$mb = extension_loaded('mbstring');
$pdo = extension_loaded('pdo_mysql');
$diskFree = @disk_free_space($storagePath);
$diskTotal = @disk_total_space($storagePath);
$eventsWritable = is_dir($eventsPath) ? is_writable($eventsPath) : is_writable($storagePath);
$storageReadable = is_readable($storagePath);
$eventsReadable = is_readable($eventsPath);

$needsUpload = 200 * 1024 * 1024;
$needsPost = 200 * 1024 * 1024;
$needsMem = 512 * 1024 * 1024;

?>
<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <title>Diagnóstico Studio59</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; color:#222; }
        h1 { margin-bottom: 10px; }
        .box { border:1px solid #ddd; padding:12px; border-radius:8px; margin-bottom:12px; }
        .muted { color:#666; font-size:13px; }
    </style>
</head>
<body>
    <h1>Diagnóstico do Servidor</h1>
    <div class="box">
        <div><strong>PHP</strong>: <?php echo htmlspecialchars($phpVersion, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>upload_max_filesize</strong>: <?php echo htmlspecialchars($uploadMax, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>post_max_size</strong>: <?php echo htmlspecialchars($postMax, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>memory_limit</strong>: <?php echo htmlspecialchars($memoryLimit, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>max_execution_time</strong>: <?php echo htmlspecialchars($maxExec, ENT_QUOTES, 'UTF-8'); ?></div>
    </div>

    <div class="box">
        <div><strong>Storage</strong>: <?php echo htmlspecialchars($storagePath, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>EVENTOS</strong>: <?php echo htmlspecialchars($eventsPath, ENT_QUOTES, 'UTF-8'); ?></div>
        <div><strong>Espaço livre</strong>: <?php echo $diskFree !== false ? bytesToHuman((int) $diskFree) : '— (sem permissões)'; ?></div>
        <div><strong>Espaço total</strong>: <?php echo $diskTotal !== false ? bytesToHuman((int) $diskTotal) : '— (sem permissões)'; ?></div>
    </div>

    <div class="box">
        <div class="muted">Requisitos mínimos</div>
        <?php echo check('GD (watermark)', $gd); ?>
        <?php echo check('EXIF (leitura jpeg)', $exif); ?>
        <?php echo check('mbstring', $mb); ?>
        <?php echo check('pdo_mysql', $pdo); ?>
        <?php echo check('Storage legível', $storageReadable); ?>
        <?php echo check('EVENTOS legível', $eventsReadable); ?>
        <?php echo check('Pasta EVENTOS gravável', $eventsWritable); ?>
        <?php echo check('upload_max_filesize >= 200MB', iniToBytes($uploadMax) >= $needsUpload, $uploadMax); ?>
        <?php echo check('post_max_size >= 200MB', iniToBytes($postMax) >= $needsPost, $postMax); ?>
        <?php echo check('memory_limit >= 512MB', iniToBytes($memoryLimit) >= $needsMem, $memoryLimit); ?>
    </div>

    <div class="box">
        <div class="muted">Notas</div>
        <div>Se estiver tudo OK, o servidor está pronto para uploads grandes e watermark.</div>
        <div>Se houver FALTA, ajusta o `php.ini` e reinicia o serviço.</div>
    </div>
</body>
</html>
