# Kit de reparación

Componente reutilizable: `res://house_props/camera_repair_kit.tscn`.
Arrastrar la escena al nivel donde se quiera colocar. No añade puntos de aparición
automáticos ni modifica la distribución de la casa.

- **F:** recoger (ocupa una ranura del inventario).
- **1 / 2 / 3:** equipar; **clic izquierdo:** reparar; **G:** soltar.
- Debe haber grietas o suciedad, la cámara debe estar en las manos y el jugador
  debe estar apoyado en el suelo, sin otra interacción activa.
- La reparación inmoviliza al jugador durante **11 segundos**, sin pausar enemigos
  ni conceder invulnerabilidad. Desde selfie pasa a primera persona.
- **Esc**, un golpe o una nueva salpicadura interrumpen la reparación: se devuelve
  la lente anterior y se conserva el kit. La nueva agresión se aplica normalmente.
- El kit se consume solo al terminar. No cura la salud ni elimina la sangre del
  personaje. La siguiente agresión puede romper la lente nueva.

## Secuencia

La mano es una sola bola, sin dedos ni antebrazo. El kit y la animación de cambio
de lente se muestran en primer plano, un 38 % más cerca de la cámara.

| Tiempo | Acción |
| --- | --- |
| 0–1,25 s | La mano izquierda alcanza y pulsa el encendido. |
| 1,25 s | Desaparece el layout. Permanecen el filtro PS2 y los ajustes de imagen. La grabación y el temporizador se detienen. |
| 1,65–4,4 s | La mano agarra, gira y desenrosca la lente vieja. |
| 4,4 s | Al retirarla desaparecen las grietas y el vómito; la imagen pasa a blanco y negro. |
| 5,8–8,1 s | Se introduce y enrosca la lente nueva; al encajar vuelve el color. |
| 10,05 s | La mano pulsa el encendido y vuelve el layout. |
| 11 s | La mano se retira y se consume el kit. REC no se reinicia automáticamente. |

La suciedad ya grabada en las cintas no se modifica retroactivamente.

## Verificación

- `tools/validate_camera_repair.gd`: inventario, secuencia, filtros, cancelación,
  salud, nueva suciedad y recogida tras soltar.
- `tools/render_camera_repair.gd`: seis capturas del sistema real en un escenario
  de contraste; resultado en `tools/output/camera_repair_sequence.png`.
