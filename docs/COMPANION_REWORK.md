# Nico: revisión de comportamiento y presentación

Fecha: 2026-09-06. Cambios incrementales sobre el trabajo local existente.

## Intención de diseño

Nico debe acompañar a una persona: conservar distancia, mirar a quien le habla,
reducir el paso al girar y comprometerse con un cruce sin zigzaguear en el marco.
Las órdenes siguen siendo explícitas. No se añaden huidas aleatorias ni pausas
arbitrarias que impidan cumplirlas.

## Puertas

El cruce conserva un portal fijo y tres fases: aproximación, espera de apertura
y salida. La entrada queda al menos a 0,55 m del plano. Se conserva el sentido
del cruce y no se obliga a retroceder si ya se ha superado el punto de entrada.

- Selección: filtrar altura de planta, lado del destino y acceso físico al punto
  de entrada. Esto reduce elecciones de puertas vecinas detrás de una pared.
- Apertura: las puertas simples y dobles exponen `is_npc_passage_ready()`.
  Una puerta abierta no impone una espera artificial; una hoja que aún gira sí.
- Paso: barrer la cápsula del niño hasta 0,3 m por delante. Si hay un obstáculo,
  detenerse. Las recuperaciones laterales generales no actúan dentro del marco.
- Bloqueo: tras 2,5 s comunicar que no puede pasar, liberar el cruce y aplicar
  un segundo de espera antes de reutilizar esa puerta. Un bloqueo transitorio
  permite continuar al despejarse.
- Cierre durante cruce: volver a pedir apertura, sin alternar abrir/cerrar.
- Salida: recuperar el objetivo de navegación sin introducir una parada forzada.
- Cancelación: nuevas órdenes y muerte cancelan la maniobra. La llegada a un
  destino parcial no se declara mientras el cruce esté activo.
- Posturas: respetar la reducción de velocidad completa al gatear; ampliar el
  tiempo máximo en función de la velocidad, evitando abortos prematuros.

Los sensores de puertas mantienen su intervalo de 0,12 s. El barrido inmediato
se reserva para la maniobra de cruce, donde importa responder a cuerpos móviles.

## Movimiento y atención

La animación recibe distancia recorrida por fotograma, velocidad de giro,
objetivo de mirada y estado de cruce mediante el método opcional
`set_motion_context(speed, turn_velocity, gaze, crossing)`.

La aceleración de recuperación se mezcla gradualmente entre 4 y 7 m de
separación. Los giros pronunciados reducen velocidad. La dirección se interpola
como ángulo: interpolar vectores opuestos podía mantener el rumbo anterior.
Hablar con Nico ya no cambia su orientación instantáneamente; la respuesta
orienta el cuerpo progresivamente durante un intervalo breve.

La cabeza mira hacia el recorrido/puerta y hacia el jugador al parar o recibir
órdenes, con límites de giro. Se añaden inclinación de torso en giros, tensión
contenida al cruzar, pequeñas asimetrías de brazos y movimiento de mochila.

## Marcha y aspecto

La fase de pasos avanza con distancia física. Un cuerpo bloqueado no sigue
reproduciendo pasos aunque su controlador quiera avanzar. Para la marcha de
pie, cada pierna usa apoyo del 60 % del ciclo y retorno del 40 %, con elevación
de pie y solución de dos segmentos para cadera/rodilla. Zapato y suela comparten
la compensación de tobillo. Al cambiar de postura se restablecen sus offsets.

El modelo conserva su estilo low-poly editable. Se ajustan cabeza, ojos menos
saltones y menos brillantes, cuello de camisa, volumen del torso, cintura y
bolsillos. El parpadeo cierra también la parte blanca de los ojos.

Al morir se detiene el desplazamiento físico, manteniendo la caída visual. La
cápsula desactivada ya no permite que la gravedad arrastre el cuerpo bajo el suelo.

## Evidencia de validación

- `validate_companion_door_matrix.gd`: diez cruces automáticos; puertas simples
  y dobles, ambos lados, aproximaciones frontales y oblicuas, agachado y gateo.
  Incluye cancelación por QUIETO, bloqueo/desbloqueo del paso y muerte estable.
- `audit_companion_doors.gd`: puerta real de la casa, cruce manual y automático;
  un cambio de lado, un inicio automático, sin rebotes. Giro automático 0,07 rad.
- `validate_companion_movement.gd`: avance 3,07 m, cero inversiones, distancias
  2,32 m / 0,75 m, deriva cero al esperar y al girar el jugador sobre sí mismo.
- `validate_companion_motion_context.gd`: suela entre 0,002 y 0,077 m en un ciclo;
  fase detenida al bloquearse, cambio de mirada y caída conservados.
- `validate_companion_postures.gd`: alturas y transiciones conservadas;
  movimiento articulado agachado y diagonal en gateo.
- `validate_grandmother_child_priority.gd`: ciclo de prioridad y alimentación
  conservado.
- Vista y cuatro fases de marcha renderizadas con Godot/OpenGL e inspeccionadas.

El test de posturas se ha adaptado para suministrar velocidad física explícita
cuando simula movimiento de la animación sin desplazar el actor.

## Límites

La solución de piernas es procedural sobre suelo plano, no IK de terreno con
sondas individuales ni un rig orgánico con animaciones capturadas. No se ha
recorrido manualmente cada puerta del mapa ni medido la ganancia de FPS. Algunas
pruebas existentes dejan recursos pendientes al salir; el entorno headless
también emite avisos de logs y certificados.

Previsualizaciones: `tools/companion_preview.png` y
`tools/companion_motion_preview.png`.
