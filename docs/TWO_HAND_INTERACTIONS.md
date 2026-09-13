# Interacciones con dos manos

La palanca se recoge, transporta y equipa desde el inventario como antes. Para quitar los tablones, coloca la cámara con **O**, confirma su posición con el control habitual y usa **F** delante de la puerta con la palanca equipada. La cámara conserva su posición y su modo de grabación durante el trabajo.

El primer clavo pendiente se selecciona al entrar. **Intro** (también el teclado numérico) cambia entre clavos pendientes; **Espacio** cuenta una pulsación por accionamiento, hasta **8** por clavo. Mantener una tecla pulsada no cuenta repeticiones. Cambiar de clavo conserva el progreso parcial durante esa sesión. **Esc** cancela: se conservan los clavos extraídos, mientras los parcialmente extraídos vuelven a su posición inicial. La cámara se recupera con O después de salir.

## Reutilización

El jugador expone `can_begin_two_hand_interaction(item_type)`, `begin_two_hand_interaction(owner, item_type)`, `is_two_hand_interaction_active()` y `end_two_hand_interaction(owner)`. Un `item_type` vacío permite una futura interacción sin herramienta. El propietario debe liberar las manos al terminar, cancelar o abandonar el árbol. La reserva impide iniciar otra interacción y recuperar la cámara simultáneamente.

`BoardedLabyrinthDoor.requires_two_hands` controla el requisito en el Inspector. Los marcadores `HookContact`, `SupportGrip` y `PowerGrip` de `player/held_items/crowbar.tscn` definen el contacto y los agarres. El controlador ajusta la orientación y la posición de las manos a la altura del clavo; el avatar resuelve ambos brazos conservando sus longitudes y limita el giro del cuello. El acercamiento usa colisiones y se cancela si un obstáculo impide alcanzar la posición.

## Verificación

- `tools/validate_two_hand_crowbar.gd`: requisito de cámara colocada, reserva exclusiva, teclado, ocho pulsaciones, cambio y reanudación de clavo, cancelación, desbloqueo y alcance de manos.
- `tools/render_two_hand_crowbar.gd`: cuatro alturas de trabajo con el jugador y los tablones reales; salida en `tools/output/crowbar_two_hand_poses.png`.

Ejemplo: `godot --headless --path . --script tools/validate_two_hand_crowbar.gd`.
