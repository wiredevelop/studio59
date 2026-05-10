<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59</title>
</head>
<body style="margin:0; background:#0a0a0a; color:#f3d0c0; font-family:Arial, sans-serif;">
    <div style="padding:32px 16px;">
        <div style="max-width:620px; margin:0 auto; background:#171212; border:1px solid #4a3630; border-radius:20px; overflow:hidden;">
            <div style="padding:28px 28px 20px; text-align:center; border-bottom:1px solid #3a2a25; background:linear-gradient(180deg, #211917 0%, #171212 100%);">
                <div style="font-size:15px; letter-spacing:4px; text-transform:uppercase; color:#dbab97;">Studio 59</div>
                <h1 style="margin:18px 0 8px; font-size:30px; line-height:1.2; color:#f7ddd1;">As suas fotos estão prontas</h1>
                <p style="margin:0; font-size:15px; line-height:1.6; color:#d6b8ab;">Pedido {{ $order->order_code }} do evento <strong style="color:#f7ddd1;">{{ $order->event->name }}</strong>.</p>
            </div>
            <div style="padding:28px;">
                <p style="margin:0 0 18px; font-size:16px; line-height:1.7; color:#efd8cf;">O acesso fica disponível durante 7 dias. Toque no botão abaixo para abrir a página de download.</p>
                <p style="margin:0 0 22px; text-align:center;">
                    <a href="{{ $downloadUrl }}" style="display:inline-block; min-width:180px; padding:14px 26px; border-radius:999px; background:#dbab97; color:#140f0e; text-decoration:none; font-size:15px; font-weight:700; letter-spacing:1px;">ABRIR</a>
                </p>
                <div style="padding:16px 18px; border-radius:14px; background:#211917; border:1px solid #3a2a25; color:#cdaea1; font-size:13px; line-height:1.6;">
                    Se não conseguir abrir, responda a este email e enviamos novo acesso.
                </div>
            </div>
        </div>
    </div>
</body>
</html>
