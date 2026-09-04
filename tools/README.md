# Herramientas del proyecto

- `generate_catacombs.py`: regenera `church_catacombs.tscn`. La casa lo carga
  al iniciar el minijuego de BoardedLabyrinthAccess (entrada de la iglesia),
  junto con su navegacion. No se instancia al arrancar ni en el editor.
- `validate_deferred_content_and_batching.gd`: valida carga diferida, cancelacion,
  reintento y navegacion, y compara geometria, materiales, transformaciones y
  colisiones antes/despues de agrupar decoracion. Ejecutar sin `--headless`:
  el renderizador dummy no conserva las matrices de MultiMesh.
- `split_graffiti_sheets.py`: recorta las hojas maestras en texturas individuales.
- `validate_catacombs.gd`: comprueba geometria y navegacion hasta la cripta.
- `validate_labyrinth_barricade.gd`: comprueba palanca, tablones e inventario.

Las hojas maestras permanecen en `assets/graffiti_sheets`, ignoradas por Godot
pero accesibles para el script de recorte.

Los modelos que aparecen en las manos del jugador se agrupan en
`player/held_items`, y los scripts de cada objeto permanecen junto a su escena
en `house_props`.
