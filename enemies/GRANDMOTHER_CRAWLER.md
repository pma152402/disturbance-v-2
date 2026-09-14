# Vieja trepadora

- `church_grandmother.tscn`: vieja original de la iglesia, con su falda, apariencia y animador conservados.
- `grandmother_crawler.tscn`: variante independiente que hereda su IA. Es la instancia utilizada ahora en `levels/test.tscn`, en la misma ubicación y con el mismo nombre de nodo.
- `levels/grandmother_crawler_preview.tscn`: abrir y pulsar **F6** para inspeccionarla. 1 reposo, 2 marcha, 3 ataques alternos, 4 pared/techo; V muestra la original; espacio pausa; arrastrar gira la vista; rueda acerca.

El torso alargado utiliza una zona válida del atlas original de tela. Las piernas tienen cadenas cadera–rodilla–tobillo de longitud fija, con superficies continuas y cerradas hasta los pies. Los brazos conservan las manos originales y su corrección de muñeca. Los arranques de brazos y piernas quedan dentro del volumen del torso; el cuello conecta con la cabeza en cada pose. La geometría de esta variante se construye al ejecutar la escena.

La ampliacion actual alarga el torso entre pelvis y pecho de 61 a 96 cm (aproximadamente un 55%). Los segmentos de pierna pasan de 57 a 73 cm y los brazos reciben otro 20% de longitud. Pelvis y pecho se elevan 8 cm; los apoyos delanteros y traseros se separan para acompañar el cuerpo mas largo. Se reajusta el polo de los codos para evitar doblar las manos contra el antebrazo. El volumen continuo del torso une hombros, cuello y caderas; las manos conservan su escala. La cabeza y el pelo se reducen conjuntamente un 25% para equilibrar la silueta. La escala del pelo sigue automaticamente la de la cabeza, incluidas raices, mechones y su movimiento, y el cuello se estrecha en la union con el craneo. Las comprobaciones de aterrizaje abarcan ahora 75 cm delante y 96 cm detras para cubrir los nuevos apoyos.

El ultimo ajuste acorta el arranque del cuello de 16 a 9 cm y reduce su anchura aproximadamente un 30%, conservando el cierre con la cabeza. La blusa incorpora dos volumenes caidos de pecho dentro de su propia malla continua, sin piezas ni pasadas adicionales. Las piernas ganan otros 5 cm por segmento (68 a 73 cm); la pelvis sube 5 cm y los apoyos traseros retroceden 6 cm para conservar la postura.

La capa de acecho oscurece el personaje entero, incluida cabeza, ojos y pelo, usando solo sus materiales existentes. La linterna directa revela la piel; las luces de habitacion tienen un efecto menor. En oscuridad conserva una atenuacion del 72% incluso de cerca, aumentando gradualmente hasta el 94% a nueve metros. La revelacion es mas rapida que la reaparicion de las sombras. El aura visual se ha eliminado por rendimiento: no se crean planos transparentes, humo ni un shader adicional.

`crawler_light_exposure.gd` conserva exclusivamente el sensor de iluminacion: registro de luces, alcance, energia, cono de foco y obstaculos entre luz y cabeza/cuerpo. Muestrea a 10 Hz con un maximo de doce rayos por muestra. Las luces de otros World3D y las apagadas no cuentan. Reconoce la linterna del jugador y las linternas soltadas. La contribucion de habitacion se limita al 55%; el haz directo puede alcanzar el 100%. El sensor no crea geometria ni materiales.

`crawler_shadow_coat.gd` conserva once materiales locales compartidos entre sus piezas y el material local del pelo. No modifica los recursos de la vieja original, la IA ni la navegación. El aspecto base sigue siendo el original cuando una luz directa despeja la oscuridad; no se conserva el cuerpo negro permanente de la prueba deshecha. Se ajusta en `EditableVisual`, grupo «Acecho en sombras», y en vistas sin jugador se desactiva el efecto para inspeccionar el modelo. La comparativa renderizada oscuridad/habitación/linterna se guarda en `tools/output/crawler_shadow_coat.png`.

La marcha alterna cuatro apoyos, calcula la fase a partir del desplazamiento real, conserva apoyos en coordenadas del mundo y termina de apoyar las extremidades al detenerse. Su referencia de movimiento gira con las paredes y el techo. Conserva percepción, memoria, búsqueda, puertas, ataque y comportamiento con presas de la vieja avanzada. No añade un segundo enemigo activo.

El techo es su posición preferida. Busca accesos por paredes cercanas aunque no vea al jugador, se dirige hasta ellos usando navegación y comprueba que haya pared, suelo y techo reales. Descarta temporalmente entradas bloqueadas. Una vez arriba permanece acechando; perder una pista o llegar a un borde no la obliga a bajar. Solo sigue posiciones observadas.

Las hojas, marcos, dinteles y colliders auxiliares de puertas están excluidos como soporte. El filtro revisa el collider y sus ancestros por grupo, interfaz, script y palabras completas del nombre, por lo que tampoco confunde elementos como `OutdoorWall` con una puerta.

Los bordes sólidos permiten transición bidireccional entre techo, pared y superficies superiores. Al acercarse desde debajo de una losa, la trepadora mira más allá del grosor completo del pasamanos, confirma la cara vertical y busca continuidad arriba o abajo. Calcula el giro desde la cara más saliente para que torso y extremidades libren cornisas desiguales. Puede recorrer techo inferior → balaustre → pasamanos y mantiene un avance corto hacia el otro lado hasta alcanzar el suelo del balcón; no vuelve automáticamente por la misma cara. Los adornos pequeños, huecos y puertas no sirven de puente.

Las orientaciones de muñeca se guardan en el espacio local de la criatura. La rotación de 90 grados con la que aparece en la iglesia no se acumula sobre la mano derecha; ambos brazos conservan el mismo IK reflejado y la postura de apoyo original.

La trepadora dispone de un salto de emergencia entre suelo, paredes y techo, limitado a cinco metros entre centros corporales. La búsqueda favorece recorridos de 3,6 metros y comprueba alternativas de 1,2, 2,4 y 4,8 metros: conserva salidas cortas para espacios estrechos. El planificador comprueba la cápsula y su rotación a lo largo de toda la curva; el controlador ejecuta esa misma curva con subpasos. Primero prueba arcos bajos y solo los eleva para librar obstáculos. Se comprime durante 0,42 segundos, vuelve a validar el recorrido antes de despegar y vuela entre 0,28 y 0,68 segundos según la longitud del arco. La rotación termina antes de alcanzar el destino. La IA no utiliza este salto al patrullar, perseguir ni atacar con normalidad.

Si el centro físico permanece en el mismo punto durante cuatro segundos de espera, prepara de uno a seis saltos, con 0,28 segundos de apoyo entre ellos. Si está intentando caminar, el bloqueo se detecta a los 0,8 segundos; dar vueltas sin progresar hacia el siguiente tramo de la ruta se detecta a los 1,5 segundos. Una pausa de ataque no acumula atasco para la marcha siguiente, y alejarse de la presa siguiendo un desvío válido o trepando tampoco cuenta como órbita. Cada destino se valida de nuevo y la cadena termina antes si recupera una persecución cercana o se queda sin destinos seguros. Recuerda durante diez segundos los lugares recién visitados o fallidos para evitar idas y vueltas. Los bancos, muebles, bordes estrechos y destinos sin espacio para la cápsula completa quedan descartados. Un objeto que entra durante la preparación cancela el salto; si entra en vuelo, intenta retroceder por las posiciones ya recorridas y comprobadas. Si tampoco puede retroceder, busca espacio para recuperar la vertical. Los estados de giro y caída tienen su propio detector de inmovilidad: ya no están excluidos indefinidamente de la recuperación.

El giro termina al 60% del vuelo y los cuatro apoyos están desplegados al 88%, antes del contacto. Selección de destino, despegue y aterrizaje usan la misma orientación de la huella, comprobando las cuatro esquinas de manos y pies además del centro y los extremos longitudinales. Solo se confirma la recepción con el cuerpo y su rumbo alineados. La variante trepadora desactiva explícitamente el salto bípedo heredado en su escena para que no compita con este controlador.

Al acabar conserva la persecución y la última pista observada. No genera pistas ficticias para cambiar de ruta. Cuando no existe un salto válido, limita los reintentos a uno cada 0,8 segundos y calcula un desvío a pie con espacio para la cápsula; si tampoco lo encuentra, prueba una salida lateral corta. Al aterrizar limpia el giro y la evasión anteriores para no retomar una dirección obsoleta. El giro local mantiene brevemente el lado elegido y usa el volumen corporal para no oscilar contra las esquinas de los bancos.

El acecho lento de aproximacion y avance por superficies solo se permite fuera del encuadre de la camara activa. Al entrar en plano cancela inmediatamente la reduccion de velocidad; al salir espera 0,2 s para evitar oscilaciones en los bordes. Se comprueba la envolvente de cabeza, torso y articulaciones, no solo el origen del personaje. Respeta zoom y cambios de camara, incluida la colocada en el suelo; la orientacion del jugador no sustituye al encuadre. Conserva las paradas de contacto, preparacion de ataques y recuperacion de colisiones. La prueba tools/validate_crawler_camera_stalking.gd cubre frente, espalda, borde, zoom, techo y cambio de camara a 30/60/120 FPS.

La persecución a pie adquiere prioridad al confirmar al jugador a menos de seis metros y la mantiene hasta ocho metros para evitar cambios de decisión en el límite. Tolera 1,1 segundos de ocultación breve entre los bancos y calcula la distancia desde la última observación, sin consultar la posición oculta del jugador. Al confirmar una nueva visión cancela inmediatamente los desvíos de navegación hacia una pared.

Al ver al jugador debajo, prepara una emboscada durante 0.55 segundos, fija el destino y salta con una trayectoria balística y colisión barrida. Se puede esquivar después de la preparación: no corrige el destino en el aire. Aplica como máximo un impacto, exige contacto/proximidad y una línea despejada desde su cuerpo. Después de aterrizar puede perseguir en el suelo; a los 2 segundos vuelve a priorizar una subida. El rig comprime el torso antes del salto, extiende las manos en el aire y amortigua el aterrizaje.

Para volver a la original en el juego, cambiar el recurso `15_imported_grandmother` de `levels/test.tscn` a `res://enemies/church_grandmother.tscn`. Su memoria anterior era de 4.5 segundos; la trepadora usa 6 segundos para completar recorridos más largos.

## Vomito a presion

La variante trepadora desbloquea este ataque cuando causa su primer golpe efectivo
al jugador. La notificacion sale de `receive_monster_attack` despues de aceptar
el dano; un golpe rechazado por invulnerabilidad no lo desbloquea. En una partida
sin golpes previos, el jugador tiene entonces dos vidas restantes.

`crawler_vomit_attack.gd` controla la secuencia: anticipacion corporal de 0,65 s,
chorro durante un tiempo aleatorio entre 6 y 12 s, tres segundos inmovil goteando y
una cadena de 2 o 3 saltos con el planificador existente. Estos saltos no se
cancelan simplemente por tener al jugador cerca; siguen comprobando la capsula,
el recorrido y el apoyo de destino. Si no hay una trayectoria segura, se retoma
la navegacion habitual. La recuperacion intencionada no dispara el detector de
atasco de cuatro segundos.

Hay un minimo de 90 segundos entre comienzos de ataque. No puede iniciarse
durante otro golpe, comida, salto, caida, cambio de esquina o cruce de puerta.
Necesita apoyo real, jugador visible y un objetivo a un maximo de catorce metros para
iniciarse. Funciona en suelo, pared y techo, manteniendo el cuerpo fijo. Durante
la expulsion sigue la posicion actual del jugador cada paso fisico, incluso al
rodearla o pasar tras una cobertura. Esto no actualiza la memoria visual de la
IA normal a traves de paredes; la colision del liquido sigue bloqueando impactos.
El giro central alcanza 7,5 rad/s, sin el antiguo limite lateral de 80 grados.
Una combinacion de oscilaciones irregulares agrega barridos y sacudidas de unos
18 grados alrededor de la direccion perseguida, mas inclinaciones laterales de
la cabeza. Esta eleva ligeramente la boca al mirar atras para librar los hombros;
el cuello generado mantiene conectadas ambas piezas. El giro opuesto de 180
grados dispone de un eje de rotacion estable. Compensa la caida por gravedad y
anticipa 0,07 s de movimiento del jugador.
La visibilidad sale de la boca y prueba torso/cabeza si un banco tapa parte del
jugador. Las envolventes exclusivas de trepa no bloquean la vision ni la salida
del chorro. El tramo corto cuerpo-boca sigue impidiendo disparar con la cabeza
atravesando una pared real.
Perder el apoyo o morir el jugador cancela el ataque.

El chorro sale entre las dos piezas originales de dientes y sigue la cabeza
articulada. El torso se contrae antes y pulsa ligeramente durante la expulsion.
Las gotas caen por gravedad mundial incluso boca abajo. La colision de cada
segmento impide atravesar paredes. El vomito nunca llama al sistema de dano:
cada contacto agrega suciedad a la lente, como maximo 0,09 cada 0,075 s.
El goteo, las salpicaduras y los charcos tampoco hacen dano.

`crawler_vomit_effects.gd` genera una trayectoria balistica continua hasta 14 m
desde la boca. Resuelve el arco bajo con gravedad mundial para no perder alcance
al duplicar la distancia. El frente avanza a 14,5 m/s; no depende de reciclar
particulas antes de alcanzar el destino. Durante la presion, la trayectoria
completa sigue la orientacion actual de la cabeza. Al parar, la columna restante
se vacia desde su ultimo origen, respetando el punto de impacto para que la cola
no reaparezca al otro lado de una pared.
`crawler_vomit_stream.gd` dibuja esa trayectoria como una unica malla opaca cerrada,
con hasta 48 secciones de ocho vertices, bordes unidos y estrias de flujo animadas.
El radio inicial es 0,105 m y aumenta gradualmente hasta 1,95 m: ligeramente mayor
que la envolvente anterior de bolas mas dispersion (aproximadamente 1,8 m).
La colision central detiene el chorro y cada borde se recorta contra el escenario.
Reutiliza la consulta de los bordes y los indices cuando no cambia el numero de
secciones. El roce ancho con la capsula tambien mancha, comprobando antes que
ninguna pared separe el liquido del jugador.
Un MultiMesh de 80 elementos queda reservado a trocitos naranjas/verde oscuro,
goteo y salpicaduras: 56 para inclusiones/goteo, 8 para salpicaduras y 16 para
escurrimientos. Emite 18 trocitos por segundo, sin bolas grandes formando el
chorro. Los impactos amplios depositan hasta tres manchas verificadas a 20 Hz
como maximo, sin crear cuerpos por gota.
`crawler_vomit_puddles.gd` agrega hasta 48 manchas en suelo, paredes, techo y
objetos fisicos, con tres lobulos planos por mancha en otro MultiMesh opaco.
Crecen hasta 0,95 m de radio en suelo y 0,64 m en otras superficies, solo si hay
apoyo bajo el borde. En superficies pequenas reduce la huella inicial. Duran
45 s y se secan al final. El envejecimiento funciona a 4 Hz; las manchas de
puertas y cuerpos moviles actualizan su transformacion con el objeto, y se
retiran si desaparece su soporte. Solo esas manchas moviles precisan actualizacion
fisica continua. Cada lobulo tiene 16 triangulos y normales planas.
No hay luces, sombras, cuerpos rigidos ni transparencias 3D nuevas. Las gotas
desactivan su bucle al terminar; los charcos detienen su temporizador al secarse.
Estos limites no sustituyen una medicion de FPS del nivel completo.

`systems/camera_lens_grime.gd` mantiene suciedad persistente sin bucles por frame.
Una pasada 2D dibuja manchas verdes y motas naranjas con opacidad limitada al 70 %;
desaparece por completo del render cuando la lente esta limpia. V anima la mano
durante 0,9 s y despeja parcialmente un ovalo central: conserva un velo visible
del 18-28 % de la mancha original incluso por donde pasa la mano. Repetir V no limpia los bordes; nuevos impactos
vuelven a manchar el centro. F sobre un lavabo de pedestal, fregadero de cocina
o lavadero fotografico lava toda la lente durante 2,4 s. Hay que permanecer a
menos de 2,2 m y sin una pared de por medio. Alejarse o cambiar de camara
interrumpe la limpieza; el vomito recibido durante ella conserva suciedad nueva.
La camara colocada en el suelo no se puede limpiar a distancia y un impacto
contra el avatar separado de ella no ensucia esa lente remota.
Al ensuciarse aparece "V  LIMPIAR LA CAMARA"; tras la pasada cambia a "BUSCA UNA
FORMA DE LAVAR LA CAMARA". El aviso se oculta durante la animacion, con la camara
colocada, fuera del juego activo y al lavar. Su temporizador se detiene al quedar
limpia. Los avisos son del HUD; no se incorporan a las cintas.

El viewport del grabador comparte el material, por lo que la suciedad queda
incorporada en los fotogramas JPEG. Limpiar despues no altera cintas guardadas.

`tools/validate_crawler_vomit.gd` pasa 83 comprobaciones: desbloqueo por dano real,
tiempos, seguimiento lateral y cabeza alineada en las tres superficies, salud
intacta, suciedad, obstaculos, saltos posteriores, enfriamiento, bordes de charcos
y desactivacion, seguimiento sobre bancos y a traves de envolventes de trepa,
impactos en pared y manchas que siguen una puerta. `tools/validate_camera_lens_grime.gd` pasa 42 comprobaciones de
acumulacion, V, F en los tres lavabos, interrupciones, nuevos impactos y camara
remota y avisos. Con Vulkan pasa 44: ademas mide el alfa renderizado para verificar
el limite del 70 % y el residuo central tras V, con entrada por el viewport real.
`tools/validate_vomit_church_tracking.gd` pasa 8 comprobaciones en el nivel completo,
con la vieja sobre los escalones reales de la iglesia y el jugador moviendose
a ambos lados mientras sigue funcionando la fisica y la animacion normales.
`tools/validate_vomit_chaotic_spray.gd` pasa 48 comprobaciones: recorridos completos
alrededor de la vieja en suelo/techo, ambos extremos desde pared, con pasos de
30/60/120 FPS, cuerpo fijo, oscilacion caotica acotada, alineacion de la boca,
impactos desde las cuatro zonas, expansion desde el grosor inicial y roces del
chorro ancho bloqueados correctamente por paredes.
`tools/validate_vomit_continuous_stream.gd` pasa 28 comprobaciones: impacto real
a 13,5 m con pasos de 30/60/120 FPS, frente con tiempo de viaje, extremo a 14 m,
anchura progresiva, topologia cerrada, boca unida, salud intacta, limites del
efecto y recorte frontal/lateral. Comprueba tambien que la cola del chorro no
reaparezca tras una pared cuando termina la expulsion.
`tools/validate_lens_recording.gd` pasa 6 comprobaciones con dos cintas capturadas
en el nivel completo. La regresion del salto y el arranque del nivel pasan.
`tools/render_crawler_vomit.gd` genera `tools/output/crawler_vomit.png`.
Con `-- --long` genera `tools/output/crawler_vomit_long.png`, con el recorrido
largo visible desde suelo, pared y techo.
Con `-- --rear` genera `tools/output/crawler_vomit_rear.png` para revisar la boca
y el cuello al seguir al jugador por detras sin desplazar el cuerpo.
`tools/render_camera_lens_grime.gd` genera `tools/output/camera_lens_grime.png`.
`tools/render_vomit_surface_stains.gd` genera `tools/output/vomit_surface_stains.png`.

```powershell
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/vomit_validation.log --script tools/validate_crawler_vomit.gd --quit-after 5000
..\godot.exe --fixed-fps 60 --path . --log-file tools/output/vomit_render.log --script tools/render_crawler_vomit.gd --quit-after 2500
```

## Comprobaciones

```powershell
..\godot.exe --headless --path . --log-file tools/output/crawler_validation.log --script tools/validate_grandmother_crawler.gd --quit-after 2400
..\godot.exe --headless --path . --log-file tools/output/crawler_church_validation.log --script tools/validate_grandmother_crawler.gd --quit-after 2400 -- --church
..\godot.exe --headless --path . --log-file tools/output/crawler_cognition.log --script tools/validate_church_grandmother.gd --quit-after 1200 -- --crawler
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_ceiling_hunt.log --script tools/validate_crawler_ceiling_hunt.gd --quit-after 12000
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_ceiling_high.log --script tools/validate_crawler_ceiling_hunt.gd --quit-after 12000 -- --high
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_ceiling_runtime.log --script tools/audit_crawler_ceiling_runtime.gd --quit-after 12000
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/granny_no_door_climb.log --script tools/validate_granny_no_door_climb.gd --quit-after 1200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_corners.log --script tools/validate_crawler_corner_transitions.gd --quit-after 2400
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_church_balustrade.log --script tools/validate_crawler_church_balustrade.gd --quit-after 2400
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_church_gameplay.log --script tools/validate_crawler_church_gameplay_climb.gd --quit-after 1200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_arm_symmetry.log --script tools/validate_crawler_arm_symmetry.gd --quit-after 1200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_spider_jump.log --script tools/validate_crawler_spider_jump.gd --quit-after 2200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_church_spider_escape.log --script tools/validate_crawler_church_spider_escape.gd --quit-after 4200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_jump_safety.log --script tools/validate_crawler_jump_safety.gd --quit-after 3600
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_pursuit_stability.log --script tools/audit_crawler_pursuit_stability.gd --quit-after 5000
..\godot.exe --path . --log-file tools/output/crawler_spider_render.log --script tools/render_crawler_spider_jump.gd --quit-after 1200
..\godot.exe --path . --log-file tools/output/crawler_render.log --script tools/render_grandmother_crawler.gd --quit-after 1200
..\godot.exe --headless --fixed-fps 60 --path . --log-file tools/output/crawler_shadow_coat_test.log --script tools/validate_crawler_shadow_coat.gd --quit-after 1200
..\godot.exe --path . --log-file tools/output/crawler_shadow_render.log --script tools/validate_crawler_shadow_coat.gd --quit-after 1200 -- --render
```

La validación comprueba marcha, persecución a 3.55 m/s y parada a 30/60/120 FPS, longitud de huesos, coincidencia de codos/manos/rodillas/tobillos con su malla, anclajes dentro del torso, cierre topológico de superficies, ataques y recorrido suelo–pared–techo–suelo. El segundo recorrido utiliza las colisiones reales de la bóveda de la iglesia. La prueba de cognición comprueba 31 condiciones de percepción, memoria, búsqueda, ataque y persecución integrada. La lámina visual se guarda en `tools/output/grandmother_crawler_poses.png`.
