# Black Ente

Escena independiente: `res://enemies/shadow_crawler.tscn`. Instanciarla en la
zona oscura deseada. `levels/test.tscn` incluye `BlackEnteAtSpawn` dos metros
delante del jugador, en su zona de aparición, conservando la abuela existente.
Hereda de `grandmother_crawler.tscn` la percepción, memoria y puertas. Esta variante
es exclusivamente humanoide y bípeda: no trepa ni salta como araña. Dobla las
rodillas bajo dinteles bajos, manteniendo el torso vertical y las manos libres;
el volumen superior de colisión acompaña esa postura sin desactivarse.
Torso y piernas tienen aproximadamente la mitad del grosor anterior, hombros
más estrechos, manos proporcionadas y brazos finos con uniones continuas.
Es siempre inofensivo y silencioso: no inicia golpes ni tiene vómito. No genera los sonidos
de respiración, pasos o voz de la abuela, ni altera el audio de otros enemigos.

`shadow_crawler_stalking.gd` sustituye la persecución por observación, acecho lento
y retirada. Mantiene unos 7,5 m; solo se acerca a 0,65 m/s cuando queda fuera de
plano. Se retira a 2,5 m/s si el jugador se acerca a menos de 4,5 m o lo encuadra
a menos de 9,5 m, con dos segundos de margen para completar la retirada.
Elige rutas que aumenten la separación y favorece rincones ocultos y oscuros.
Al perder la memoria de la posición del jugador deja de acercarse. Se retira
por rutas del suelo y vuelve a planificarlas si se bloquea.
Las distancias y velocidades se ajustan en «Acecho huidizo» del Inspector.

Mirarlo fijamente durante 4 segundos continuos activa una huida de hasta 3,2 segundos
a seis veces su velocidad normal de retirada: 15 m/s por defecto, el doble del
sprint anterior. Cuenta solo
la cabeza o el torso a un máximo de 4 m de la cámara activa y dentro de 7,5° de
su centro, sin obstáculos. Mirarlo desde el fondo del pasillo no activa la carga.
Apartar la mirada, alejarse fuera del radio o perder visibilidad reinicia el contador.
El radio se ajusta en «Huida al mirarlo fijamente», independientemente de la
distancia de detección de luz. Durante la carga
aparece una sonrisa dentada que se extiende desde el centro hasta ambas mejillas.
Durante toda la carga permanece quieto, incluso si estaba retirándose o cruzando
una puerta; conserva gravedad, colisiones y daño por luz. La boca se abre ampliamente,
el torso se encorva hacia delante, estira ambos brazos y las pupilas negras crecen
hasta ocupar casi todo el ojo. Los ojos aumentan un 45 % de tamaño durante la carga.
La transformación queda completamente abierta durante los últimos 0,25 s antes
de arrancar, al cumplirse los cuatro segundos.
La sonrisa sobresale de la piel y de los dientes originales también al abrirse;
al romper la mirada se apaga en un tercio de segundo. Mantiene la sonrisa durante
la carrera, gira rápidamente hacia la ruta y alcanza su velocidad máxima en 0,1 s.
Busca un destino a 24 m, con alternativas más cercanas si no hay espacio; lo mantiene
hasta llegar o encontrar un bloqueo. Favorece cobertura y sombra, respeta suelo,
puertas y colisiones. Durante el sprint libera los brazos para acompañar la carrera.
El tiempo y multiplicador se ajustan en «Huida al mirarlo fijamente». No añade
daño ni audio. La sonrisa sigue la superficie de la cara y se disuelve con ella.
`tools/validate_black_ente_stare.gd` comprueba continuidad a 30/60/120 Hz, paredes,
interrupción de la mirada, sonrisa, destino y velocidad física de la huida.
`tools/render_black_ente_smile.gd` muestra su progresión durante los cuatro segundos.

Intenta sostener la mirada al jugador visible, incluso retirándose hacia atrás
o de lado. Cabeza y cuerpo giran coordinados, con límites de giro del cuello.
La comprobación de visibilidad se hace a 10 Hz y se interrumpe al quedar oculto
el jugador; no rastrea su posición nueva a través de paredes. Al huir de la mirada
sostenida gira hacia donde corre.

Conserva la máscara/recubrimiento negro sobre el cuerpo y la cabeza; la luz nunca
descubre la piel. Dos puntos blancos emisivos, casi el doble de grandes, ocupan las cuencas de los
ojos y se ven en oscuridad, unidos al giro y escala de la cabeza. No añaden luces
ni aura, y se disuelven junto al cuerpo. Elimina el pelo antes de construirlo.
Los materiales locales mantienen la disolución al animar, sin cambiar la abuela.
El brillo de los ojos está reducido al 25 % (color y emisión), conservando su tamaño.

Al recibir luz que hace daño, se encoge, retuerce los hombros, levanta los brazos
y sacude la cabeza y las manos. La reacción crece con la disolución y combina
temblores rápidos con seis contorsiones asimétricas: cambia de pose cada 0,2 s,
con un tirón de 0,03 s. Los brazos se levantan sobre la cabeza o se extienden
en direcciones opuestas, sin apoyar las manos en la cintura. Cesa suavemente al ponerse a
salvo; el halo exterior de la linterna no provoca dolor. Es una capa de animación:
mantiene los apoyos, las uniones del cuello y brazos y su capacidad para escapar.
Sigue sin sonidos ni ataques. `tools/validate_shadow_pain.gd` comprueba intensidad,
recuperación, apoyos y continuidad a 30/60/120 Hz; `tools/render_shadow_pain.gd`
muestra la secuencia de reposo, dolor, disolución y recuperación.
Con `-- --snaps` muestra las seis poses separadas por 0,2 s. La validación
comprueba la cadencia y las posiciones reales de las palmas, además de sus objetivos.

La luz directa de habitación lo consume en unos 5 segundos; el centro de la
linterna, en 1,5 segundos de exposición desde sano. Solo daña el círculo central
intenso del proyector: radio normalizado 0,385, igual en mano y al soltarla.
El anillo exterior sigue provocando huida, pero no causa daño. El sensor reutiliza
las mismas comprobaciones de obstáculos para ambos anillos. La luz débil
tarda más. Habitación y linterna tienen contadores separados: combinar ambas no
permite matarlo con un destello. El sensor compartido comprueba
energía, alcance, cono, visibilidad y obstáculos a 10 Hz; detecta también linternas
soltadas. No usa el brillo ambiental de WorldEnvironment ni iluminación indirecta
horneada como daño: cuenta luz de nodos Light3D que llegue a cabeza o torso.

Al recibir luz prioriza escapar a 4,5 m/s por el suelo, con una
aceleración de huida de al menos 12 m/s² en suelo. Compara seis destinos próximos cada medio
segundo, favorece sombra/cobertura y comprueba suelo, espacio y ruta. Conserva
el controlador de colisiones; no se lanza a atacar al huir.
Permanece refugiado al menos tres segundos y hasta curarse antes
de retomar su comportamiento. El destino de huida no reemplaza la memoria del jugador.
Al salir del haz completa 0,65 segundos de retirada hacia el refugio para no
quedarse justo en el borde de luz y volver a exponerse al girar la cabeza.

En oscuridad regenera un 25 % de vida por segundo (hasta cuatro segundos para
recuperarse completamente). Se curan los contadores de habitación y linterna;
cualquier luz por encima del umbral interrumpe la curación. El cuerpo y los ojos
se recomponen con la misma disolución, sin efectos adicionales. Al consumirse
desaparece definitivamente, cancela el ataque y elimina colisiones y procesamiento.
Emite `dissolved` antes de liberarse; no reaparece automáticamente. Los tiempos
y el umbral de luz se ajustan en «Vulnerabilidad a la luz» del Inspector.

Abrir `levels/shadow_crawler_preview.tscn` y pulsar F6: 1 oscuridad, 2 habitación,
3 linterna, R reinicia. Arrastrar gira la vista. La luz ambiente de esta vista
solo permite inspeccionar la silueta; las dos luces interactivas sí hacen daño.

Validación: `godot --headless --path . --script res://tools/validate_shadow_crawler.gd`.
Cubre aislamiento de la abuela, ausencia de pelo, materiales durante las poses,
luces reales, conos, paredes, acumulación, muerte, física y tiempos a 30/60/120 Hz.
También comprueba que no pueda golpear, dañar al saltar ni emitir audio.
`tools/validate_shadow_light_escape.gd` comprueba la duración mínima, exposición
combinada, curación, salida rápida del haz, cobertura, colisiones y pausa en sombra.
`tools/validate_shadow_crawler_spawn.gd` carga el nivel completo y comprueba
distancia al jugador, espacio para el cuerpo, suelo, ausencia de daño y silencio.
`tools/validate_shadow_stalking.gd` comprueba retirada, distancia de observación,
acecho fuera de plano, memoria, postura, manos libres y altura disponible
a 30/60/120 pasos por segundo. `tools/validate_shadow_humanoid.gd` comprueba grosor,
unión del cuello, ojos grandes, mirada y retirada sin dar la espalda.
`tools/render_shadow_humanoid.gd` muestra frente, perfil, flexión de rodillas y oscuridad.
