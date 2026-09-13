# Abuela de la iglesia: auditoría y nueva conducta

`ImportedGrandmotherGroundFloor` de `levels/test.tscn` usa ahora
`enemies/church_grandmother.tscn`, una variante del personaje importado con cerebro
y animación propios. Conserva modelo, materiales, pelo, tamaño y los mecanismos
compartidos de navegación, puertas, escaleras y prioridad de los niños.

## Problemas encontrados

- La persecución se cortaba por distancia incluso viendo al jugador. En oscuridad
  solo conservaba 0,65 s de memoria al ocultarse.
- La búsqueda alternaba un pequeño abanico de destinos con plazos demasiado cortos
  para llegar. No recordaba lugares inspeccionados.
- El revelado periódico obtenía la posición del jugador sin pistas y la predicción
  consultaba la velocidad actual de la presa aunque estuviera oculta.
- El ataque corregía continuamente su dirección hacia el jugador durante el golpe.
- La vuelta a patrulla sobrescribía con 10 s el plazo calculado para viajes largos.
- Las poses eran poco asimétricas y la inspección dependía de la fase de los pasos.
- Se animaba el antiguo `Model` oculto y se recorrían repetidamente los descendientes
  de las lámparas para encontrar su emisión.
- La prueba larga de la nueva búsqueda reveló oscilaciones junto a obstáculos:
  moverse lateralmente bastaba para superar la antigua detección de atasco.

## Cambios

**Percepción:** reconocimiento gradual, cono visual que se ensancha con la alerta,
orientación de cabeza, alcance según iluminación y rayos contra la geometría. Una
primera impresión provoca atención antes de confirmar la persecución. A muy corta
distancia puede percibir desde cualquier dirección.

**Memoria:** solo ver al jugador actualiza su posición y velocidad conocidas. Al
ocultarse, revisa la última pista y utiliza la dirección observada para elegir el
primer sector de búsqueda. Se elimina el revelado periódico de esta variante.
Terminar de comer tampoco revela al jugador: vuelve a percibir antes de perseguirlo.

**Oído:** los pasos se atenúan tras paredes y se localizan con incertidumbre cuando
están ocultos. Una nueva pista sonora puede interrumpir una investigación anterior.
Los pasos repetidos actualizan el destino sin reiniciar continuamente la pausa.
Las lámparas tienen menor prioridad y conservan la protección frente a parpadeos.

**Búsqueda y patrulla:** llegada a la última posición, pausa de inspección, expansión
hasta 6,5 m y penalización de puntos ya revisados. Se comprueban rutas y se calcula
un plazo según distancia. Tras 2,8 s sin mejorar la distancia al destino, la búsqueda
descarta ese punto; un cruce de puerta comprometido no dispara esta regla. Agotado
el tiempo de búsqueda, retoma la patrulla conservando una alerta que decae. La patrulla
recuerda ocho lugares y mantiene el tiempo de viaje calculado.

**Obstáculos bajos y altar:** el controlador compartido sondea la cara, el espacio
superior y la recepción antes de saltar hasta 0,9 m. En el altar prueba varios
ángulos para no aterrizar dentro del propio mueble. Las puertas y paredes altas se
rechazan. Tres muestras de movimiento sin acercarse al destino activan además un
desvío temporal, de modo que desplazarse en círculos ya no oculta un atasco. La
plataforma de 0,62 m tampoco se confunde con la planta superior de la casa.

**Combate:** anticipación de 0,38 s, impacto a los 0,60 s, recuperación hasta 1,32 s
y enfriamiento de 1,85 s. Solo la primera mitad de la anticipación permite corregir
la dirección. Después se puede esquivar lateralmente. El daño se comprueba una vez,
con alcance, ángulo y línea de visión. Alterna el brazo que golpea.

**Animación:** mano de escucha, cabeza orientada hacia pistas, inspección en reposo,
brazos asimétricos, respiración según tensión, transferencia de peso al acelerar y
frenar, torsión al golpear y recuperación gradual. Los pasos dependen del movimiento
real; respiración y atención tienen un reloj independiente. Puertas y alimentación
conservan sus poses específicas.

## Coste medido

Percepción aproximadamente cada 0,1 s; lámparas cada 0,25 s con referencias de emisión
en caché. Máximo cinco candidatos por nueva decisión de búsqueda. Se elimina la
animación del modelo oculto. No se añaden luces, mallas ni texturas al personaje.

Comparación orientativa de 900 pasos de física por variante en el nivel real,
Forward+ y RTX 4090. Tiempos de CPU de las llamadas del NPC:

| Medida | Anterior | Nueva |
|---|---:|---:|
| Controlador, mediana | 0,241 ms | 0,169 ms |
| Controlador, p95 | 0,412 ms | 0,324 ms |
| Controlador, p99 | 0,496 ms | 0,434 ms |
| Animador visible, mediana | 0,199 ms | 0,202 ms |
| Animador visible, p95 | 0,232 ms | 0,241 ms |

No representan una mejora de FPS del juego entero. Las decisiones y duraciones
producen recorridos/estados ligeramente distintos. Se congelaron otros actores y
meteorología, y se desactivó la prioridad infantil solo en el banco de medidas.
No incluyen trabajo diferido del renderizador. La medición de persecución precede
al último ajuste de descarte de sectores bloqueados; este solo afecta a búsqueda.
JSON y trazas: `tools/output/church_runtime_*.json`.

## Validación

- `validate_church_grandmother.gd`: **31 comprobaciones**, entre ellas visión tras
  paredes, silencio detrás, reconocimiento, persecución visible a 11 m, memoria de
  posición y velocidad, oído amortiguado, búsqueda por llegada, descarte de bloqueo,
  presupuesto de rutas, patrulla, esquiva, impacto único, recuperación, persecución
  con física real y atención visual en reposo.
- `validate_grandmother_obstacle_jump.gd`: supera un obstáculo de 0,62 m y no
  intenta atravesar una pared de 2,4 m.
- `validate_church_grandmother_altar_jump.gd`: reproduce el acceso frontal en la
  iglesia real, verifica el salto, el aterrizaje y que no active la escalera de casa.
- `validate_grandmother_arm_continuity.gd -- --church`: 840 fotogramas, siete poses,
  articulaciones y costuras continuas; error máximo 0,000001 m.
- `validate_grandmother_door_traversal.gd -- --church`: puerta normal y doble.
- `validate_grandmother_child_priority.gd -- --church`: prioridad, caída, dos comidas
  completas de 20 s y vuelta al jugador como presa disponible.
- `validate_imported_grandmother_eating.gd -- --church`: postura y transferencia de mano.
- `validate_grandmother_intelligence.gd`: regresiones de la variante anterior.
- `audit_church_grandmother_runtime.gd`: recorrido real de 13,47 m, adquisición,
  persecución por la iglesia, ataques y continuación hacia el exterior.
- Variante `--search`: 40 s en el nivel real. Tras ocultarse el jugador, mantiene
  su última posición conocida, revisa cinco sectores con cinco consultas de ruta
  y vuelve a patrulla en el segundo 36; los puntos bloqueados no la retienen.
- `render_church_grandmother.gd`, también con `--back`: seis poses renderizadas y
  revisadas por delante y por detrás.

Ejecutar desde la raíz, por ejemplo:

```powershell
godot.exe --headless --path . --script tools/validate_church_grandmother.gd
godot.exe --path . --script tools/audit_church_grandmother_runtime.gd
godot.exe --path . --script tools/audit_church_grandmother_runtime.gd -- --legacy
godot.exe --headless --path . --script tools/audit_church_grandmother_runtime.gd -- --search
godot.exe --path . --script tools/render_church_grandmother.gd
```

Controles nuevos en `Church cognition` del inspector. Las velocidades ya ajustadas
en el nivel (1,4 / 1,78 / 3,55 m/s) siguen vigentes. La escena nueva define los tiempos
del ataque. Los antiguos controles de memoria fotosensible/revelado pertenecen al
controlador heredado y no dirigen el nuevo cerebro de iglesia.

La dificultad y sensación de naturalidad deben valorarse jugando. Las pruebas
verifican reglas y regresiones, no garantizan la calidad subjetiva de cada encuentro.
La navegación sigue dependiendo de la malla y los portales del nivel.

## Ajuste de saltos y recuperación — 14/09/2026

La variante original conserva el salto de obstáculos bajos con un máximo de seis
saltos seguidos. Calcula el tiempo balístico de recepción y barre doce segmentos
del arco con la cápsula completa. El movimiento horizontal converge al apoyo
validado; desactiva temporalmente el ajuste al suelo y mantiene vertical el cuerpo
durante el vuelo. La escalada y los cambios de percepción no interrumpen ese
control. La pose recogida desaparece antes del aterrizaje.

El muestreo de atasco pasa a 0,4 s y la corrección lateral a 0,35 s. Los desvíos
incluyen salidas laterales y ligeramente hacia atrás, comprobadas con navegación
y volumen físico. Una persecución cercana respeta el desvío ya comprometido.

Validación: siete gradas, máximo de seis saltos seguidos y error de recepción
inferior a 1 mm; salto y aterrizaje sobre la plataforma real de 0,62 m junto al
mueble del altar con IA completa; rechazo de paredes altas; 31 comprobaciones de
cognición y ensayo de locomoción sin fallos. La prueba del altar instancia
explícitamente esta variante, porque el nivel utiliza ahora la trepadora.

La trepadora usa su propio planificador entre superficies y desactiva el salto
bípedo heredado. Sus resultados están en `CRAWLER_STABILITY_AUDIT_2026-09-13.md`.
