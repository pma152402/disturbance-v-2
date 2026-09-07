# Revisión incremental — 2026-09-06

Se han conservado los cambios locales existentes. Esta revisión añade:

- Sombras: aplicar solamente cambios de estado, sin apagar y encender las mismas luces cada 0,18 s. Las luces ocultas por sus padres o con energía cero no consumen los tres puestos disponibles. Distancias comparadas al cuadrado.
- Compañero: WAIT no solicita rutas; el seguimiento reutiliza la proyección y ruta del jugador en su alternativa de ruta parcial, eliminando una segunda consulta idéntica.
- Abuela: solicitar el siguiente punto antes de inspeccionar la ruta recién asignada. Invalidar percepción al cambiar de presa. Limitar la consulta de visión para aproximación directa al radio en que se utiliza; conservar percepción y comprobaciones de ataque independientes.

## Comprobaciones ejecutadas

Godot 4.7.2, headless:

- Carga de scripts en editor: sin errores de análisis.
- validate_shadow_budget.gd: correcto, incluyendo padres ocultos, energía cero, actualizaciones repetidas y eliminación de luces.
- validate_companion_movement.gd: correcto; avance 3,07 m, cero inversiones, deriva en espera cero, seguimiento 2,32 m y cercano 0,75 m.
- validate_grandmother_navigation_priority.gd: correcto; distancia al niño 4,78 → 0,71 m, ruta de dos puntos.
- validate_grandmother_child_priority.gd: correcto; niño A → alimentación → niño B → alimentación → jugador.

La prueba antigua validate_grandmother_close_combat.gd no valida combate en este entorno: emite body->get_space() null durante movimiento manual y termina sin ataque. No se considera aprobada. Algunas pruebas también avisan de recursos pendientes al salir. El entorno restringe logs, certificados y guardado de ajustes del editor.

No se ha medido mejora de FPS ni realizado revisión visual con GPU. Los resultados anteriores comprueban comportamiento y eliminación de trabajo redundante; no constituyen un benchmark gráfico.
