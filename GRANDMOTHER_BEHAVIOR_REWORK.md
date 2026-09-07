# Abuela: comportamiento, movimiento y auditoría

Revisión del 6 de septiembre de 2026.

## Escena activa

Se ha retirado la instancia de Nico y su referencia de `test.tscn`. Sus recursos
siguen disponibles para futuras escenas. La abuela importada se activa mediante
`process_mode = 0` y `remain_still = false`; ambos ajustes impedían ejecutar su
comportamiento. Se conserva su colocación actual y la otra variante desactivada.

## Puertas: causa comprobada

La auditoría inicial del niño sobre las puertas reales encontró ocho bloqueos
en 22 intentos. Varios correspondían a normales de suelo de 0,87–0,98 en el eje
vertical: el detector confundía superficies transitables con paredes.

Para la abuela se introduce `npc_passage_probe.gd`, que distingue contactos de
suelo según `floor_max_angle` de obstáculos reales. La colisión efectiva sigue
resuelta por `move_and_slide`; no se desactivan muros ni hojas.

El cruce usa entrada a un mínimo de 0,60 m del portal, dirección comprometida,
confirmación de apertura real, barrido de cápsula, espera ante cuerpos y
reintento limitado. No retrocede para buscar la entrada si ya la ha superado.
Filtra puertas de otras plantas y entradas detrás de paredes. Si una presa
bloquea el paso y está al alcance, puede abandonar el cruce para atacar; atacar
o comer siempre cancela la maniobra de puerta.

## Inteligencia y lógica

- El ataque exige línea libre tanto al iniciarse como al aplicar el impacto.
  Una vez comprometido, termina su secuencia antes de aceptar distracciones.
- La búsqueda primero intenta alcanzar la última posición conocida, hace una
  pausa de inspección y explora puntos cercanos alcanzables en su planta.
  Los puntos no cambian cada fotograma al llegar. El presupuesto pasa a 8 s.
- El revelado automático del jugador queda desactivado por defecto. Puede
  recuperarse explícitamente con `supernatural_player_reveal` en el inspector.
- Los pasos lejanos se amortiguan por paredes. El tiempo para investigarlos
  depende de la distancia; al llegar inspecciona, en lugar de olvidarlos de golpe.
- La percepción fotosensible se consulta cada `perception_interval` (0,1 s),
  manteniendo movimiento e impacto físico por fotograma.

## Movimiento y actitud

La dirección interpola ángulos, evitando el caso degenerado de dos vectores
opuestos. Reduce velocidad en giros pronunciados y mira en la dirección de la
ruta salvo en aproximación visible a la presa. El rig dirige la cabeza al punto
de atención con límites y transición suave, conserva el barrido de búsqueda y
recoge los brazos al cruzar. La mezcla de marcha usa velocidad física real.

La prueba en la escena completa descubrió otra inmovilización: destinos de
patrulla proyectados antes del horneado válido y altura de ruta separada de los
pies. Ahora comprueba que exista una superficie navegable, detecta revisiones,
reconstruye los destinos y compensa el desfase de altura. La medición pasó de
0,00 m a 7,10 m recorridos en una ventana de 15 segundos de simulación.

## Validación

- `audit_real_door_blockers.gd`: 22 intentos con la abuela importada en las
  puertas reales, 20 cruces y 2 detenciones correctas ante BoardedLabyrinthAccess.
  Ningún bloqueo inesperado. La prueba ejercita el cruce con física real;
  posiciona el actor a cada lado, no valida la ruta completa entre habitaciones.
- `validate_grandmother_door_traversal.gd`: puerta simple y doble desde ambos lados.
- `validate_grandmother_intelligence.gd`: pared sin daño, ataque con un único
  impacto, búsqueda de la última posición, inspección, ausencia de revelado
  automático, regreso a patrulla y audición con obstáculos.
- `audit_grandmother_live.gd`: IA activa sin Nico en la escena, 7,10 m de
  desplazamiento y velocidad máxima de 1,28 m/s en la prueba registrada.
- `validate_grandmother_navigation_priority.gd`: navegación y persecución
  conservadas en una escena aislada de regresión.
- `validate_imported_grandmother_eating.gd`: postura de alimentación conservada.
- `validate_grandmother_search_behavior.gd` y
  `validate_photosensitive_grandmother.gd`: configuración y búsqueda correctas.

La prueba antigua de configuración exigía una posición en el salón incompatible
con la escena actual. Se sustituye esa condición por IA activa y ausencia de Nico.
La prueba de búsqueda se ajusta a llegada, inspección y nuevo presupuesto temporal.

No se ha hecho una sesión manual completa de juego ni medido FPS. Algunos
validadores antiguos dejan recursos pendientes al salir; el entorno restringido
también emite avisos de logs y certificados. Los cambios se han mantenido sobre
las modificaciones locales anteriores, sin descartarlas.
