Runtime offline para reconhecimento facial no Windows.

Estrutura esperada no bundle final:

- `data/face_runtime/python/python.exe`
- `data/face_runtime/python/Lib/site-packages/...`

Uso local antes de criar instalador:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\face_runtime\prepare_runtime.ps1
```

Depois faz o build Windows normal. O `windows/CMakeLists.txt` já copia esta pasta para `data/face_runtime`.
