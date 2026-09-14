# Capa de tablones de la vivienda

`House/HousePlankFloor` es un revestimiento independiente sobre las dos plantas
de la casa. Ocultarlo devuelve el aspecto anterior sin reconstruir el nivel.
El boton **Actualizar capa de tablones** recalcula las huellas tras editar losas.

- Capa de 1 cm, con cantos hasta la base, sin colisiones propias.
- Tablones de 19 cm de ancho y longitudes de 1,45–2,20 m, juntas a contrapeo,
  veta existente `Madera4.jpg`, tonos variables, cantos oscuros y pequenas puntas.
- Acabado mate envejecido. El filtrado reduce los detalles menores que un pixel
  a distancia; no hay texturas nuevas ni un nodo por tabla.
- Las huellas se recortan entre si: no se duplican superficies en las losas
  solapadas y no se rellena el hueco de escalera.
- No se modifican las losas, muebles, colisiones, sonidos ni navegacion.
  Iglesia, escuela y exterior quedan fuera de la seleccion explicita.
- El bano conserva sus azulejos blancos originales; su huella queda excluida
  de la madera. La cocina lleva losas gris claro de 80 cm con manchas oscuras
  irregulares, vetas suaves y acabado satinado
  y juntas finas, delimitadas por las paredes y el umbral de entrada.
- Dos materiales compartidos para distinguir plantas, 10 paneles; el marmol
  se dibuja en las mismas superficies, sin geometria ni colisiones adicionales.
  Se genera al cargar; no procesa frames ni hace consultas fisicas continuas.

## Validacion

`tools/validate_house_plank_floor.gd` verifica las losas reales, colisiones,
cobertura en ambas plantas, hueco de escalera, recorte interior, regeneracion y
5.088 muestras de solapes. `-- --render` guarda una vista del material.

`tools/render_house_plank_floor.gd` abre la casa con sus muebles y optimizadores,
comprueba que conservan la capa y guarda el salon en
`tools/output/house_plank_floor_living_room.png`. Usa iluminacion de revision;
no cambia la iluminacion del juego. Ejecutar los renders sin `--headless`.
