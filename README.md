# Disturbance V2

Juego de terror en primera persona hecho con Godot 4 y renderer Forward+.

## Escenas principales

- `test.tscn`: escena de arranque; integra casa, jugador, exterior, clima y postprocesado.
- `house_baked.tscn`: mapa editable y decoracion de la casa.
- `player/player.tscn`: personaje, camara, manos, interaccion y audio de movimiento.

## Organizacion

- `house_props/`: componentes reutilizables de mobiliario, luces e interacciones.
- `sounds/`: ambientes, interacciones y sonidos localizados de objetos.
- `assets/`: imagenes, fuentes y recursos propios del juego.
- `ps2_house/` y `ps2_objects/`: paquetes externos conservados con sus rutas originales.

La carpeta `.godot/` es cache local y no se versiona.
