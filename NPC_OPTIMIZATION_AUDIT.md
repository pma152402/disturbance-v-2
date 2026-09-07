# Auditoría de NPC, comportamiento y animación

Fecha: 2026-09-06

## Alcance

La revisión cubre el componente reutilizable del niño, la abuela normal y la variante importada. El objetivo ha sido reducir trabajo de física innecesario sin bajar la frecuencia del movimiento visible, conservar una navegación estable en puertas y mejorar las posturas del niño y la secuencia de alimentación de la abuela.

## Resultado de rendimiento

Las decisiones de movimiento y las animaciones siguen actualizándose en cada fotograma de física. Únicamente se han espaciado las consultas costosas cuyo resultado no necesita renovarse 60 veces por segundo.

| Consulta por NPC | Antes a 60 Hz | Ahora | Reducción aproximada |
| --- | ---: | ---: | ---: |
| Altura del mapa de navegación del niño | 60/s | 5,6/s | 90,7 % |
| Búsqueda de puertas del niño | 60/s | 8,3/s | 86,1 % |
| Percepción visual/auditiva de la abuela | 60/s | 10/s | 83,3 % |
| Tres sondas de altura de la abuela | 180/s | 30/s | 83,3 % |
| Búsqueda de puertas de la abuela | 60/s | 8,3/s | 86,1 % |
| Revisión de prioridad de presas | 5/s | 5/s | Sin cambio intencionado |

Los `RayCast3D` espaciados permanecen desactivados entre consultas y se actualizan de manera explícita cuando vence su temporizador. Esto evita tanto la evaluación automática por fotograma como duplicar una evaluación con `force_raycast_update()`.

Los intervalos son propiedades exportadas y se pueden afinar por escena:

- Niño: `navigation_height_probe_interval = 0.18 s` y `door_scan_interval = 0.12 s`.
- Abuela: `perception_interval = 0.10 s`, `clearance_probe_interval = 0.10 s` y `door_scan_interval = 0.12 s`.

## Niño: locomoción y comportamiento

El controlador conserva la ruta calculada por `NavigationAgent3D`, usa embudos de corredor para reducir zigzag y mantiene histéresis en las distancias de seguimiento. La dirección no se invierte al entrar y salir repetidamente del umbral de parada. En puertas se conserva un portal temporal hasta completar el cruce, en lugar de volver a elegir el lado de la puerta cada fotograma.

La postura visual ahora interpola con una curva suave entre de pie, agachado y a cuatro patas. El agachado incluye:

- zancada más corta y cadencia reducida;
- flexión alterna de rodillas y elevación de pies;
- transferencia vertical del peso y balance corporal contenido;
- velocidad real reducida a `0.72` de la marcha normal.

La postura X/a cuatro patas incluye:

- patrón diagonal brazo-pierna propio del gateo;
- apoyo alterno de manos, flexión de codos y apertura de hombros;
- avance de cadera, oscilación lateral y cabeceo estabilizado;
- velocidad real reducida a `0.42` de la marcha normal.

La transición no cambia bruscamente la velocidad ni reinicia la fase de la animación. También respeta el estado muerto: una vez caído, el ciclo de locomoción deja de modificar el cuerpo.

## Abuela: prioridad, navegación y alimentación

La selección de objetivo mantiene una prioridad estricta: primero el niño vivo más cercano y sólo después el jugador. La variante importada utiliza la misma prioridad antes de aplicar sus reglas especiales de luz.

Al alcanzar a un niño, la secuencia es:

1. ejecuta el ataque y el niño pasa a su pose de caída;
2. se aproxima suavemente al cuerpo hasta `0.72 m`, con límite de dos segundos para no quedar bloqueada;
3. se orienta hacia el cuerpo y mezcla progresivamente una postura arrodillada;
4. alterna ambas manos entre el cuerpo y la boca mediante una pose procedural dirigida al objetivo;
5. sincroniza inclinación de cabeza, torso y apertura de boca con el ciclo de mordida;
6. permanece comiendo 20 segundos completos desde que comienza la animación, no desde el inicio de la aproximación;
7. libera el cuerpo y busca al siguiente niño o, si no queda ninguno, al jugador.

Durante esta secuencia la navegación queda detenida de forma controlada, por lo que el personaje no intenta perseguir y comer simultáneamente.

## Validación automatizada

Resultados obtenidos en Godot 4.7.2 headless:

- Compilación y carga del proyecto: correcta.
- Movimiento del niño: `3.07 m` de progreso, `0` inversiones, `0.000 m` de deriva de giro y `0.000 m` de deriva en espera.
- Distancias de seguimiento: `2.32 m` normal y `0.75 m` en seguimiento cercano.
- Velocidad medida: `0.83 m/s` agachado y `0.48 m/s` a cuatro patas.
- Animación agachada: variación de rodilla `0.41 rad` y transferencia vertical `0.030 m`.
- Animación de gateo: variación de brazos `0.60 rad`, piernas `0.74 rad` y balance lateral `0.024 m`.
- Puertas del niño: un solo cambio de lado, sin rebotes, tanto con orden directa como con apertura automática.
- Puertas de la abuela: puerta simple y doble superadas desde ambos lados.
- Persecución prioritaria: distancia al niño `4.78 -> 0.71 m`, sin desviarse al jugador.
- Ciclo de presas: `niño A -> comer 20 s -> niño B -> comer 20 s -> jugador`.
- Rig importado comiendo: descenso de rodillas `0.54 m`, inclinación `0.83 rad` y recorrido alterno de mano `0.74 m`.

Los avisos de `user://logs` y certificados que aparecen en ejecución headless proceden del entorno aislado de pruebas y no del código de los NPC. La antigua prueba `validate_grandmother_pathfinding.gd` no es válida como prueba de regresión: invoca manualmente física sobre un cuerpo fuera de un `PhysicsSpace`; se ha usado en su lugar la validación de navegación integrada, que instancia el personaje dentro del árbol y sí comprueba avance y ruta reales.

## Archivos principales

- `characters/companion/companion_npc_base.gd`: navegación, temporizadores, puertas, comandos y postura lógica.
- `characters/companion/child_visual.gd`: animación procedural de pie, agachado, gateo y caída.
- `monster_grandmother.gd`: prioridad, percepción, navegación, ataque y alimentación.
- `monster_grandmother_imported.gd`: integración de la prioridad de niños con la variante importada.
- `granny_editable_visual_animator.gd`: versión de la alimentación para el rig importado visible.
- `tools/validate_companion_movement.gd`: estabilidad y movimiento prolongado.
- `tools/validate_companion_postures.gd`: alturas, transiciones y amplitudes de animación.
- `tools/validate_grandmother_child_priority.gd`: muerte, alimentación y orden de objetivos.
- `tools/validate_grandmother_navigation_priority.gd`: persecución real mediante navegación.
- `tools/validate_imported_grandmother_eating.gd`: arrodillado y recorrido de manos del rig importado.
