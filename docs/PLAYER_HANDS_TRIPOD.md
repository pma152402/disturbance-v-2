# Manos y agarre del tripode

- El protagonista usa palmas sin dedos en primera persona, sujeciones,
  animacion corporal, selfie y muerte. Se retiran las piezas de dedos y la
  logica de flexion/visibilidad; los brazos y la IK se conservan.
- El tripode equipado usa `CarryGrip` como contacto con la palma derecha.
  Comparte el balanceo de la mano y no tiene una animacion de escala separada.
- La representacion de mano es solo visual: no participa en la simulacion
  fisica. El tripode colocado o soltado conserva su cuerpo y colisiones.
- La camara externa muestra el tripode en la derecha; en selfie pasa a la
  izquierda porque la derecha sostiene la videocamara.
- Controles: F recoge, LMB coloca abierto en una superficie valida y G suelta.
  Ni F ni RMB colocan el tripode. Un clic en una superficie invalida no lo lanza.

Validaciones: `validate_player_child_avatar.gd`, `validate_player_tripod_grip.gd`,
`validate_camera_tripod.gd`, `validate_camera_modes.gd` y `validate_selfie_grip.gd`.

Resultado: las cinco validaciones pasan, ademas de `validate_two_hand_crowbar.gd`.
El agarre mantiene un error inferior a 0.1 mm en las 60 muestras de movimiento.
Colocacion comprobada con raton capturado y captura visual del agarre revisada.
