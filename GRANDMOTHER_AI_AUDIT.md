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

## Segunda revisión: locomoción, navmesh y parpadeo

11. **Aceleración dependiente del rumbo.** La velocidad se integraba con un `move_toward` por eje. En diagonal los dos ejes avanzaban a la vez, así que aceleraba hasta 1,41x más rápido que en un pasillo recto y la respuesta cambiaba según la orientación. Ahora es un único `move_toward` sobre el plano, con `acceleration` y `braking` separados: arranca con peso y frena antes.
12. **Giro instantáneo y dependiente de los FPS.** Todas las orientaciones usaban `lerp_angle(..., minf(delta * k, 1.0))`, que no es un suavizado exponencial: a 30 FPS gira distinto que a 144, y sin tope el cuerpo encaraba de golpe cada esquina nueva de la ruta. Ahora es `1 - exp(-k·delta)` limitado por `max_turn_speed_degrees`. El ataque queda exento a propósito: ahí el giro rápido es intencionado.
13. **Cadencia de paso desacoplada de la velocidad.** La fase de animación subía por una rampa fija por estado, así que los pies patinaban al acelerar o al frenar contra una pared. Ahora avanza `PI` por cada `stride_length` recorrido: sonido de paso, balanceo de piernas y bob del rig salen de la distancia real.
14. **Dos relojes de animación.** El rig importado llevaba su propio contador de fase, independiente del `_motion_phase` que dispara el sonido de paso. El bob visual y el paso audible iban por libre. Ahora el animador lee la fase del cuerpo.
15. **Silueta sin peso en los giros.** El rig no tiene piernas, así que un cambio de dirección lo hacía rotar sobre su eje como una torreta. Se añade una inclinación hacia el interior del giro tomada de la velocidad angular real.
16. **Navmesh demasiado grueso.** Celda de 0,25 m sobre huecos de puerta de menos de un metro: el borde navegable quedaba a hasta media celda de su sitio y los pasillos salían con dientes de sierra que el agente convertía en zigzag. Se baja a 0,15 m con altura de celda 0,1 m, y se activa `simplify_path` para que el funnel no devuelva ristras de puntos casi colineales.
17. **Rejilla del mapa desalineada.** El `NavigationServer` seguía a 0,25/0,25 mientras el navmesh se horneaba a otra resolución, lo que rompe la fusión de bordes entre regiones vecinas. Se fija la rejilla del mapa en `project.godot`.
18. **Un parpadeo se leía como un interruptor.** `flickering_light.gd` pone la emisión a cero hasta 0,58 s seguidos. Cada apagón se interpretaba como "han apagado la lámpara" y el encendido siguiente como una lámpara nueva, lo que reiniciaba el temporizador de atención: delante de una luz parpadeante nunca perdía el interés. Ahora el interruptor (`is_on`) cuenta al instante y sólo la emisión se filtra con `light_off_confirm_seconds`.

19. **Bloqueo permanente ante un objetivo inalcanzable.** Si la presa se subia a un muro, a una repisa o a cualquier punto fuera del navmesh, la ruta terminaba lejos del destino (o degeneraba en dos puntos sobre la propia abuela cuando el destino caia en una isla de navegacion desconectada). `next_point` colapsaba sobre su posicion, la direccion quedaba a cero y frenaba; ademas `_was_trying_to_move` pasaba a falso, con lo que la recuperacion de atascos se desactivaba justo en el unico momento en que hacia falta. Medido: **inmovil 9,6 s y subiendo**, sin salida. Ahora detecta la inalcanzabilidad comparando el final real de la ruta con el destino pedido, acecha encarando la presa durante `stalk_seconds` y despues se rinde hacia busqueda o patrulla.
20. **Persecucion eterna entre alturas.** La rama `changing_floor` (mas de 1,15 m de diferencia vertical) refrescaba la memoria de persecucion sin limite alguno. Estaba pensada para que la losa de la escalera no le hiciera olvidar al jugador, pero convertia cualquier sitio elevado e inalcanzable en persecucion infinita. Ahora solo insiste mientras gane terreno: si deja de acercarse durante `floor_change_grace_seconds`, la memoria decae y pasa a busqueda.

21. **Un saliente la neutralizaba por completo.** Todas las reglas fotosensibles exigen estar dentro de `same_floor_player_tolerance` (1,35 m), asi que un jugador subido a un muro desaparecia de su radar: no era que no supiese llegar, es que no lo detectaba. Ahora `_is_player_on_reachable_ledge()` lo trata como estimulo propio, se planta debajo y sacude hacia arriba con el mismo `receive_monster_attack` del resto de golpes, que ya aplica empuje horizontal y vertical: el muro deja de ser refugio porque te tira de el. El zarpazo se comprueba en cada frame de `_update_movement` y no en la rama de "sin direccion de avance": a medio metro del muro todavia le queda rumbo hacia el punto de debajo, y aquella rama no llegaba a ejecutarse nunca.
22. **Patrulla clavada en el punto de aparicion.** Eran dos puntos fijos relativos al spawn, unos 6 m en total, asi que se pasaba la partida rondando la misma esquina. Con `patrol_roams_house` elige destinos al azar por toda la malla. Detalle que costo encontrar: **las puertas cerradas no se hornean, asi que cada habitacion es una isla de navegacion independiente** y practicamente ningun destino "se alcanza" segun el mapa. Exigir que la ruta terminase en el destino la dejaba encerrada donde apareciese; basta con exigir que la ruta avance de verdad, porque el borde de la isla es justo donde esta la puerta y alli el sistema de travesia la abre y continua. Medido: **43,4 m y 14 celdas de 3 m en 60 s**, frente a 6 celdas antes.

Coste medido del horneado más fino: **48 ms → 76 ms**, absorbido por la pantalla de carga.

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

El grupo **Suavizado de movimiento** gobierna la sensación de peso:

- `acceleration` / `braking`: arranque y frenada, en m/s². Subir `acceleration` la hace más nerviosa; bajarla, más pesada.
- `max_turn_speed_degrees`: tope de velocidad angular. Es el control que impide el giro de torreta.
- `heading_smoothing`: suavizado del rumbo antes de aplicar el tope.
- `stride_length`: metros por zancada. Gobierna a la vez el ritmo del sonido de paso y el bob del rig.

En la variante fotosensible, **Patrulla alterna** gobierna el paseo: `patrol_roams_house`, `roam_radius` y `roam_minimum_distance`. `ledge_detection_distance` es a que distancia nota a un jugador encaramado.

El grupo **Objetivos inalcanzables** decide que hace cuando no hay ruta hasta la presa: `unreachable_tolerance` (cuanto puede quedarse corta la ruta antes de darla por imposible), `stalk_seconds` (cuanto acecha antes de rendirse) y `floor_change_grace_seconds` (cuanto insiste al perseguir entre alturas sin ganar terreno). `ledge_reach_height` y `ledge_reach_radius` definen el alcance del zarpazo hacia arriba.

En el animador visual, `turn_lean` regula cuánto se inclina hacia el interior del giro.

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

- `tools/validate_grandmother_roaming_and_ledge.gd`: paseo por la casa y zarpazo con empuje a un saliente.
- `tools/validate_grandmother_unreachable_target.gd`: presa sobre un saliente; acecho acotado y regreso a la actividad.
- `tools/validate_grandmother_locomotion.gd`: aceleración isótropa, tope de giro y zancada por distancia.
- `tools/validate_grandmother_pathfinding.gd`: recorrido con geometría entre lavandería y cocina.
- `tools/validate_grandmother_close_combat.gd`: tiempo de entrada en ataque y órbita acumulada.
- `tools/validate_grandmother_search_behavior.gd`: última posición, barrido y regreso a patrulla.
- `tools/validate_photosensitive_runtime.gd`: luces, memoria, patrulla y revelado anti-espera.
- `tools/validate_grandmother_door_traversal.gd`: detección, centrado y cruce de puerta normal y doble desde lados opuestos.

Resultados actuales:

- Recorrido con obstáculos: **3,71 m**.
- Bloqueo continuo máximo: **0,28 s** (sube desde 0,15 s: la salida es más lenta a propósito).
- Entrada en ataque: **0,78 s** desde 2,4 m.
- Órbita acumulada antes de atacar: **0°**.
- Búsqueda local: **4,2 s**, seguida de retorno a patrulla.
