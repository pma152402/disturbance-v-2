# Herramientas del proyecto

- `generate_catacombs.py`: regenera `church_catacombs.tscn`. La casa lo carga
  solamente al ejecutar el juego, por lo que no aparece al editar `house_baked`.
- `split_graffiti_sheets.py`: recorta las hojas maestras en texturas individuales.
- `validate_catacombs.gd`: comprueba geometria y navegacion hasta la cripta.
- `validate_labyrinth_barricade.gd`: comprueba palanca, tablones e inventario.

Las hojas maestras permanecen en `assets/graffiti_sheets`, ignoradas por Godot
pero accesibles para el script de recorte.

Los modelos que aparecen en las manos del jugador se agrupan en
`player/held_items`, y los scripts de cada objeto permanecen junto a su escena
en `house_props`.
