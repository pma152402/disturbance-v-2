# Benchmark determinista de rendimiento

El benchmark carga la escena jugable con renderizado real, desactiva VSync,
congela la IA, los cuerpos fisicos, las animaciones ambientales variables y los
relampagos. Mide desde camaras fijas en casa, iglesia, patio, escuela y sotano.

Cada zona hace tres pasadas por defecto. El resultado de la zona es la mediana
de esas tres pasadas; cada pasada contiene a su vez la mediana de sus frames y
el p95 del tiempo de frame. Se registran tiempo total de frame, CPU de proceso,
CPU de fisica, CPU de render, GPU cuando esta disponible, draw calls, objetos y
primitivas.

## Ejecutar

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_performance_benchmark.ps1
```

La primera ejecucion crea automaticamente
`tools/output/performance_baseline.json`. Las siguientes conservan ese baseline
y generan una comparacion antes/despues en:

- `tools/output/performance_current.json`: datos completos y las tres pasadas.
- `tools/output/performance_comparison.md`: resumen legible y diferencias.
- `tools/output/performance_benchmark.log`: salida de Godot para diagnostico.

Para aceptar deliberadamente el estado actual como nueva referencia:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_performance_benchmark.ps1 -SaveBaseline
```

Se pueden ajustar `-Passes`, `-SampleFrames`, `-SettleFrames` y
`-TimeoutSeconds`. `-FailOnRegression` devuelve error si una zona empeora al
menos un 10 % en frame, GPU o draw calls.

El script tiene dos cierres de seguridad: un watchdog interno de Godot y otro
externo. Si se supera el tiempo, el wrapper mata exclusivamente los procesos de
Godot que aparecieron despues de comenzar la prueba, sin cerrar el editor que
ya estuviera abierto.
