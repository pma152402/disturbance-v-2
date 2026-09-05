# Sounds

Organizacion de audio del proyecto:

- `ambient/`: lluvia, tormenta y ambientes continuos o espaciales.
- `interactions/`: clics ya recortados para acciones inmediatas.
- `footsteps/`: reservado para posibles muestras futuras. Los pasos del juego se sintetizan por impacto y superficie desde `gameplay_sound_factory.gd`.
- `objects/`: sonidos propios de muebles, luces, maquinas y decoracion.

Los ambientes deben exponerse como escenas reutilizables para poder cambiar su
archivo o generador sin modificar la escena principal.

## Integraciones actuales

- `ambient/darkroom_sound.mp3`: bucle espacial con fundido cruzado en una sola luz del cuarto oscuro; las otras dos no duplican el ambiente.
- `ambient/wood_cracking_sound.mp3`: banco de crujidos; cada evento escoge y recorta un único crack de 0,34–0,55 s en la planta opuesta al jugador.
- Pasos procedurales: cuatro variantes del paso exterior se usan en todo el mapa. Dos voces alternas conservan las colas; la cadencia cambia al caminar, correr, agacharse y arrastrarse.
- Las cuatro variantes se precalientan al cargar al jugador para que el primer paso no produzca un tirón.
- `interactions/camera_zoom.mp3`: primer tramo para zoom in y segundo tramo desde 1,55 s para zoom out; se corta con un fundido al terminar el movimiento del FOV.
- `interactions/door_open_close_sound.mp3`: apertura desde 0 s hasta 3,66 s y cierre desde 3,72 s.
- `interactions/screwdriver_sound.mp3`: sólo gana volumen mientras el ratón está haciendo girar realmente un tornillo.
- `npcs/npc_rat_sound.mp3`: primer susto un segundo después de que la rata empiece a salir; repeticiones posteriores muy espaciadas.
- `objects/camera_background_noise.mp3`: ruido electrónico permanente de la videocámara durante toda la partida. No es un sonido de vela y no depende de llevarla ni encenderla.
- `objects/clock_tickling_sound.mp3`: activo en los relojes del salón y del despacho. Comienza desde el principio y usa atenuación 3D inversa para que la lluvia no oculte el tic. Cada reloj expone `Volumen tictac`, `Tamaño fuente tictac` y `Distancia máxima tictac` en el Inspector; los valores base son 0 dB, 4 m y 16 m.

`seamless_spatial_loop.gd` evita el corte de los MP3 continuos solapando el final de una voz con el inicio de otra.
Además detiene por completo los decodificadores 3D que quedan fuera de alcance y actualiza los fundidos a 30 Hz.

El ruido permanente de cámara está fijado a `-40 dB` mediante `seamless_global_loop.gd`. Usa reproductores 2D sin ganancia, distancia ni paneo 3D, por lo que su nivel no cambia al ponerse de pie, agacharse o tumbarse. En el Inspector aparece como `Audio - Ruido permanente de cámara > Volumen ruido cámara`. Los crujidos esperan mediante un temporizador y sólo procesan durante su fragmento; la acústica meteorológica tampoco vuelve a escribir valores que no han cambiado.

`camera_audio_filter.gd` recorta subgraves y el extremo agudo directamente en el bus Master. Por tanto procesa pasos, objetos, luces, voces, lluvia y cualquier bus secundario antes de llegar a la salida. No crea voces ni ejecuta lógica por fotograma; se ajusta en `Player/CameraAudioFilter`.
