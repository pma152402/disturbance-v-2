# Auditoría de IA: abuela fotosensible

## Problemas encontrados

1. **Órbita alrededor del jugador.** El sensor local incluía el `CharacterBody3D` del jugador entre los obstáculos. Al acercarse elegía continuamente una salida lateral, mientras la orientación seguía apuntando al jugador.
2. **Ataque difícil de activar.** La distancia se medía en tres dimensiones entre orígenes colocados a alturas diferentes. La separación vertical consumía casi todo el alcance aunque ambos colliders ya estuviesen en contacto.
3. **Rutas demasiado pegadas a las esquinas.** El funnel de navegación acortaba los portales y la cápsula rozaba muebles y marcos.
4. **Waypoints obsoletos.** Después de deslizarse contra una esquina podía quedar al otro lado de un waypoint y tratar de regresar a él indefinidamente.
5. **Movimiento directo sin ruta.** Un resultado vacío del agente se sustituía por una línea recta, incluso con una pared entre el enemigo y el objetivo.
6. **Patrulla inicial antes del horneado.** Los puntos se calculaban dos frames después del arranque, normalmente antes de que la malla asíncrona estuviese disponible.
7. **Pérdida de jugador abrupta.** Al terminar la memoria regresaba directamente a patrulla o permanecía sobre una única posición, sin registrar el entorno cercano.
8. **Lectura visual limitada.** Investigación, búsqueda y persecución compartían prácticamente la misma pose. El golpe no tenía una anticipación clara.
9. **Código de techo residual.** La rama experimental seguía mezclada con la máquina de estados terrestre aunque estuviese desactivada.
10. **Puertas sin compromiso de cruce.** La navegación general recalculaba esquinas mientras la hoja giraba y podía dejarla rozando el marco. La variante fotosensible tampoco ejecutaba el detector de puertas en su bucle propio.

## Comportamiento actual

### Patrulla

- Espera a que la navegación esté lista y reproyecta sus dos puntos sobre la malla.
- Si todavía no existe ruta, sólo avanza directamente cuando un rayo confirma que el recorrido está libre.
- El radio de horneado deja margen entre la cápsula y paredes, muebles o marcos.

### Investigación

- Atiende una luz nueva o un sonido y conserva una posición concreta.
- La pose levanta una mano para tantear el espacio y baja la velocidad respecto a la persecución.
- La proximidad del jugador necesita línea visual; ya no lo detecta a través de una pared delgada.

### Persecución

- Predice ligeramente el movimiento del jugador a media distancia.
- Cerca del jugador abandona el rodeo de obstáculos y realiza una aproximación directa.
- Reduce progresivamente la velocidad durante los últimos 2,1 metros.
- Se detiene a 0,68 metros mientras espera el siguiente ataque, evitando empujar y orbitar.
- La orientación mira al jugador sólo durante la aproximación final; durante la ruta sigue la dirección de locomoción.

### Ataque

- Utiliza distancia horizontal y tolerancia vertical.
- Tiene anticipación, avance corto, instante de impacto y recuperación.
- El tiempo de animación está separado del enfriamiento entre golpes.
- El avance termina al tocar al jugador y no activa el sistema de evasión local.

### Pérdida y búsqueda

- Conserva la última posición confirmada.
- Recorre puntos alrededor de esa posición durante 4,2 segundos.
- La búsqueda cambia la postura de brazos y realiza un barrido contenido de cabeza.
- Agotada la búsqueda, regresa a la patrulla más cercana.

### Recuperación de navegación

- Comprueba progreso cada 0,65 segundos.
- Si avanza menos de 0,12 metros, invalida la ruta y prueba una maniobra lateral.
- Alterna el lado de salida en bloqueos consecutivos.
- Un abanico de rayos permite bordear obstáculos pequeños.
- Puede saltar hasta tres waypoints si existe recorrido directo seguro.
- Localiza scripts de puerta hasta cuatro niveles por encima del collider impactado.

### Cruce de puertas

- Las puertas normales y las dobles publican el centro y el eje estable de su hueco.
- Al abrir una puerta, la abuela centra el cuerpo, espera brevemente a la hoja y cruza en línea recta hasta el otro lado.
- Durante el cruce suspende el recálculo de esquinas, la evasión lateral y la recuperación de atasco.
- Tres rayos de detección cubren el centro y ambas hojas; la junta de una puerta doble ya no queda como punto ciego.
- Las puertas cerradas con llave conservan su bloqueo: sólo inicia el cruce si la hoja confirma que se abrió.
- Una pausa de reentrada impide que vuelva a activar la misma puerta nada más atravesarla.
- La pose recoge brazos y hombros mientras pasa por el marco.

## Parámetros de ajuste

Los controles principales están en el inspector bajo **Navegación y recuperación**:

- `obstacle_probe_distance`: anticipación frente a objetos pequeños.
- `stuck_check_seconds`: frecuencia del detector de bloqueo.
- `stuck_minimum_progress`: desplazamiento mínimo considerado válido.
- `recovery_duration`: duración de la maniobra lateral.
- `chase_prediction_seconds`: anticipación del jugador.
- `chase_slowdown_distance`: inicio del frenado de persecución.
- `chase_stop_distance`: separación estable antes del ataque.

El ataque expone por separado `attack_windup_seconds`, `attack_hit_seconds`, `attack_animation_seconds`, `attack_cooldown` y `attack_vertical_tolerance`.

El grupo **Cruce de puertas** permite ajustar `door_approach_distance`, `door_cross_distance`, `door_cross_speed`, `door_open_wait_seconds`, `door_cross_timeout` y `door_center_tolerance`.

## Validaciones reproducibles

- `tools/validate_grandmother_pathfinding.gd`: recorrido con geometría entre lavandería y cocina.
- `tools/validate_grandmother_close_combat.gd`: tiempo de entrada en ataque y órbita acumulada.
- `tools/validate_grandmother_search_behavior.gd`: última posición, barrido y regreso a patrulla.
- `tools/validate_photosensitive_runtime.gd`: luces, memoria, patrulla y revelado anti-espera.
- `tools/validate_grandmother_door_traversal.gd`: detección, centrado y cruce de puerta normal y doble desde lados opuestos.

Resultados actuales:

- Recorrido con obstáculos: **3,86 m**.
- Bloqueo continuo máximo: **0,15 s**.
- Entrada en ataque: **0,75 s** desde 2,4 m.
- Órbita acumulada antes de atacar: **0°**.
- Búsqueda local: **4,2 s**, seguida de retorno a patrulla.
