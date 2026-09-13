# Escuela: tercera planta y dependencias

La escena `levels/house_baked.tscn` incorpora `SchoolCompletion`, una ampliación
editable y cargada desde el inicio junto a `SchoolUpperFloor`.

| Planta / cota | Habitaciones del pasillo de escaleras | Otros espacios |
| --- | --- | --- |
| Baja / 0 m | Secretaría; sala de profesores | Escuela existente conservada |
| Intermedia / 4,16 m | Enfermería; reunión de profesores | Aula, dormitorio, cocina y comedor existentes |
| Tercera / 8,40 m | Mantenimiento; materiales y juegos | Salón de actos, música y lectura |

Las seis dependencias forman un ala de 3,45 m de ancho al oeste del pasillo,
dentro del vallado. Cada habitación tiene puerta propia, ventana, iluminación,
suelo, techo y tabiques. Mobiliario de oficina reutilizado; camilla y botiquín,
banco con herramientas, estanterías con cajas y juegos según el uso de la sala.

El salón de actos tiene 24 butacas, pasillo central y circulación lateral,
escenario con escalones, atril, micrófono y cortinas. Música contiene piano,
asientos y atriles; lectura, librerías y mesa. Se conservan las texturas de suelo
y madera y el material de paredes del colegio.

## Acceso y envolvente

- Dos tramos nuevos con descansillo, barandillas y colisión continua unen las
  cotas 4,16 y 8,40. Se cierra la caja de escalera hasta la cubierta.
- Los antiguos paños occidentales se sustituyen por paredes con huecos reales.
  Se retiran las dos barreras que cerraban el arranque de la escalera superior.
- Se completa el suelo junto a la entrada de la calle, el remate posterior y
  las cubiertas. Las juntas de los marcos encajan con los huecos.
- Las hojas nuevas se dimensionan respecto a sus bisagras; conservan su ancho
  al girar, sin deformarse por la escala del marco.
- La navegación incluye la tercera planta y el ala oeste. Se corrige el sentido
  de las caras de las rampas originales para incluirlas en el horneado. Un enlace
  horizontal cruza el paso real del descansillo antiguo, cuya rasterización
  quedaba cortada alrededor de la barandilla; probado físicamente con radio 0,45 m.
- Los refugios de lluvia y la exclusión de vegetación cubren la ampliación.

## Rendimiento y comprobación

La decoración estática usa la agrupación de mallas existente por materiales;
las puertas siguen animadas e interactivas. Las 16 luces añadidas no generan
sombras dinámicas. No hay sondeo ni generación de salas por fotograma.

`tools/validate_school_completion.gd -- --navigation` comprueba pasos, escaleras
en ambos sentidos, escenario, cerramientos y rutas a las nueve salas. La opción
`--preview` genera vistas con GPU. Las pruebas de lluvia y visibilidad de inicio
incluyen también la ampliación. Estas comprobaciones no sustituyen una medición
de FPS en el equipo y configuración de juego del usuario.

`tools/build_school_completion.gd` reproduce la ampliación. Su ejecución vuelve a
generar esa escena y puede sobrescribir ediciones manuales dentro de ella. No se
ejecuta durante el juego ni reconstruye el mobiliario de las salas existentes.
