# Studio 59 MVP

MVP completo criado em:
- `backend/` -> Laravel API + Web Admin/Staff
- `mobile/` -> Flutter app (Convidado + Staff)

## Fluxo E2E implementado
1. Web Staff cria/edita evento e define senha/preco.
2. Upload JPEG em batch via Web com upload resumivel por chunks (`resumable.js`).
3. Sistema numera fotos por evento (`0001...`) e gera preview com watermark via job.
4. Convidado no mobile: Eventos de hoje -> senha -> catalogo -> carrinho -> pedido.
5. Staff no mobile/web marca pedido como `paid`.
6. Convidado gera link temporario e faz download do original apenas se `paid`.

## Credenciais seed
- Web/API Staff
  - email: `admin@studio59.local`
  - password: `password`
- Evento demo
  - nome: `Demo`
  - senha: `1234`

## Backend Run
```bash
cd backend
cp .env.example .env   # se necessario
composer install
php artisan key:generate
php artisan migrate:fresh --seed
php artisan storage:link
php artisan serve
```

Noutro terminal:
```bash
cd backend
php artisan queue:work
```

### Notas backend
- Timezone: `Europe/Lisbon`
- Queue: `database`
- Storage local: `storage/app/private`
- Upload resiliente: idempotencia por `upload_id`, validacao final de JPEG e endpoint de status por upload.
- Preview sync opcional: `PREVIEW_FORCE_SYNC=true` no `.env` (quando nao houver worker ativo).
- S3 preparado via variaveis `AWS_*` no `.env` (quando quiser trocar driver)

## Mobile Run
```bash
cd mobile
C:\Users\Win11\flutter\bin\flutter.bat pub get
C:\Users\Win11\flutter\bin\flutter.bat run
```

### Nota Windows
Se aparecer erro de symlink, ativar Developer Mode:
```bash
start ms-settings:developers
```

## API principal
Publico:
- `GET /api/public/events/today`
- `POST /api/public/events/{id}/enter`
- `GET /api/public/events/{id}/photos` (Bearer `event_session_token`)
- `POST /api/public/orders` (Bearer `event_session_token`)
- `GET /api/public/orders/{order_code}`
- `POST /api/public/orders/{order_code}/download-link`
- `GET /api/public/download/{order}/{photo}` (signed url)

Staff (Sanctum):
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET|POST|PUT|DELETE /api/events`
- `GET /api/events/{id}/orders`
- `POST /api/orders/{id}/mark-paid`
- `POST /api/orders/{id}/mark-delivered`

Web Admin/Staff:
- `/login`
- `/events`
- `/events/{event}/uploads`
- `/events/{event}/uploads/status?upload_id=...`
- `/orders`
- `/events/{event}/orders/export`
