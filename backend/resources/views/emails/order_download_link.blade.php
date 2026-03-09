<!doctype html>
<html lang="pt">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Studio 59</title>
</head>
<body style="font-family: Arial, sans-serif; background:#f6f6f6; padding:20px;">
    <div style="max-width:620px; margin:0 auto; background:#ffffff; border:1px solid #e5e5e5; border-radius:8px; padding:24px;">
        <h2 style="margin:0 0 12px;">Pedido {{ $order->order_code }} pago</h2>
        <p style="margin:0 0 10px;">O seu pedido no evento <strong>{{ $order->event->name }}</strong> já está pronto para download.</p>
        <p style="margin:0 0 16px;">Clique no botão abaixo para aceder à página de download dos JPEG originais:</p>
        <p style="margin:0 0 16px;">
            <a href="{{ $downloadUrl }}" style="display:inline-block; background:#000; color:#fff; text-decoration:none; padding:12px 18px; border-radius:6px;">Abrir downloads</a>
        </p>
        <p style="margin:0 0 10px; font-size:13px; color:#555;">Se o botão não funcionar, use este link:</p>
        <p style="margin:0; font-size:13px; word-break:break-all;"><a href="{{ $downloadUrl }}">{{ $downloadUrl }}</a></p>
    </div>
</body>
</html>
