# Cuerpo infantil del jugador

`child_visual.tscn` es el aspecto canonico del protagonista. La escena se
instancia como `Player/PlayerAvatar`; no contiene navegacion, ordenes, colision,
input ni comportamiento autonomo.

`child_visual.gd` recibe del jugador velocidad local, postura, salto, giro,
mirada, objeto equipado y accion contextual. Su unica responsabilidad es
generar una pose procedural suave para que el cuerpo sea coherente en sombras,
reflejos, camaras externas y durante la muerte.

La locomocion usa un ciclo de apoyo y recuperacion por pie, con IK de dos
segmentos para conservar unidos cadera, rodilla y tobillo. Zapato y suela
articulan talon y punta sobre la cota de apoyo original del modelo. La marcha
estira la pierna de apoyo y recupera el pie a baja altura; la carrera acorta el
apoyo, eleva mas el pie y flexiona los codos. Ctrl mantiene la pelvis baja,
acorta la zancada y alarga el apoyo. La pelvis y el pecho contrarrotan, la cabeza
compensa el balanceo y los cambios de velocidad, giro y postura se suavizan.

`player/locomotion_gait.gd` calcula la fase por distancia recorrida. El jugador
comparte su reloj de pasos/camara con el avatar; las previsualizaciones pueden
avanzarlo de forma independiente. Los apoyos se resuelven sobre el plano local
del avatar, sin consultas fisicas adicionales para cada pie.

Validacion: `tools/validate_player_locomotion.gd` mide penetracion de suelas,
elevacion, deslizamiento durante apoyo, articulacion, parada y sincronizacion.
`tools/render_player_locomotion.gd` genera una hoja de ocho fases de andar,
correr y Ctrl en `tools/output/player_locomotion_contact_sheet.png`.

La camara principal excluye la capa visual 2, donde vive el cuerpo completo,
para que la cabeza no corte la imagen en primera persona. Las manos cercanas a
la camara son una representacion separada con la misma piel y mangas. Todas
las manos conservan solo la palma, sin dedos ni animaciones de dedos.
Al morir, el cuerpo real pasa a la capa normal, se separa del jugador y cae;
no se crea un segundo nino con otro tamano o postura.

`child_companion.tscn` se conserva como marcador retirado para no dejar una
ruta rota en escenas antiguas. Ya no instancia la IA de acompanante.
