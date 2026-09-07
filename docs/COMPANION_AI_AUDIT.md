# Auditoria del acompanante infantil

Fecha: 2026-09-06

## Sintoma reproducido

En la escena real `test.tscn`, Nico recibia una orden y parecia no moverse o
avanzaba unos centimetros antes de quedarse bloqueado. La prueba inicial sobre
un plano aislado no reproducia el problema porque su malla navegable estaba a
la misma altura y contenia una sola isla.

## Causas encontradas

1. La casa publica una iteracion preliminar del mapa antes de terminar su bake.
   Nico aceptaba esa version y conservaba una ruta parcial despues del bake real.
2. Los puntos de la malla de la casa estan aproximadamente 0,5 m por encima del
   origen fisico del acompanante. El primer waypoint coincidia en X/Z, pero no en
   Y, y `NavigationAgent3D` nunca lo consideraba alcanzado.
3. Perseguir un hueco exacto detras del jugador convertia cualquier giro de
   camara en un destino nuevo. Nico intentaba orbitar y recolocarse sin parar.
4. Ese hueco tambien podia atravesar una pared. La proyeccion al NavMesh podia
   desplazar el destino varios metros y colocarlo en otra isla.
5. La distancia de seguimiento original no tenia histéresis, causando ciclos de
   arranque/parada y cambios de direccion cerca del umbral.
6. La animacion usaba el tiempo global para la zancada. Cada transicion de
   movimiento podia comenzar en una fase arbitraria y producir un salto visual.
7. `PATH_POSTPROCESSING_EDGECENTERED` generaba rodeos y bucles en algunos
   corredores estrechos. Al actualizar el destino podia parecer que el NPC
   orbitaba aunque el jugador estuviera quieto.
8. Una puerta abierta giraba su hoja fuera del rayo frontal. El NPC llegaba al
   limite de la ruta horneada, dejaba de detectar la puerta y la recuperacion de
   atasco alternaba izquierda/derecha delante del marco.
9. Durante un cruce se recalculaba el lado del portal. Al cambiar de signo justo
   en el umbral, el punto de salida podia reinterpretarse y provocar vueltas.
10. El acompanante no conocia la postura del jugador: su visual, capsula y
    velocidad permanecian de pie aunque el jugador se agachase o reptase.

## Correcciones

- Monitor continuo del identificador de iteracion del mapa y descarte de rutas
  cuando cambia el bake.
- `path_height_offset` calculado desde la superficie navegable bajo el NPC.
- Objetivo del jugador calculado desde la base real de su capsula, no desde el
  origen del torso, para no seleccionar otra planta en escaleras o desniveles.
- Validacion de accesibilidad y del error de proyeccion de cada destino.
- Ruta parcial controlada para aproximarse a limites y puertas.
- Apertura y cruce manual de portales de puerta, incluso cuando una puerta
  separa dos islas de navegacion.
- Registro de portales fijos para detectar tambien puertas ya abiertas, aunque
  su hoja haya desaparecido del rayo frontal.
- Cruce monotono: la direccion entrada-salida se bloquea al iniciar y la misma
  puerta no puede reactivarse durante 1,6 segundos tras salir.
- Ruta `CORRIDORFUNNEL`, siguiendo el siguiente punto de `NavigationAgent3D`
  hacia la posicion mundial actual del jugador, como en el mecanismo del video
  de referencia. Elimina los zigzags artificiales de `EDGECENTERED`.
- Radios independientes para comenzar y terminar el seguimiento.
- Seguimiento radial: Nico respeta una zona personal y no intenta ocupar un
  punto exacto detras del jugador. Girar sobre uno mismo no genera movimiento.
- Direccion suavizada, frenado separado y recuperacion lateral persistente.
- Aceleracion vectorial de 2,6 m/s2 y frenado de 3,8 m/s2, sin modificar cada
  eje de forma independiente.
- Curva de llegada progresiva: reduce la velocidad antes de entrar en la zona
  personal en lugar de caminar a maxima velocidad y detenerse en seco.
- Mensaje explicito cuando AVANZA o VE ALLI apunta a un lugar inaccesible.
- Fase de pasos acumulada segun velocidad real, entrada/salida suavizada,
  rodillas articuladas, elevacion alterna de pies, balance de brazos reducido,
  respiracion, inclinacion y mirada.
- Imitacion completa de postura: de pie, agachado y cuerpo a tierra. Cada estado
  tiene transicion suave, capsula y altura de navegacion propias.
- Marcha agachada al 72 % de la velocidad normal y gateo al 42 %, con zancada,
  rodillas, torso, brazos y cabeza adaptados a cada postura.
- Comprobacion de espacio antes de levantarse: Nico conserva la postura baja si
  tiene un techo u obstaculo encima, aunque el jugador ya pueda ponerse de pie.

## Resultados automatizados

Prueba dentro de `test.tscn`:

- Desplazamiento observado en dos rutas consecutivas: 1,518 m y 2,067 m.
- Velocidad maxima en seguimiento normal: 1,15 m/s.
- Inversiones bruscas de direccion: 0.
- Distancia final natural al jugador: 2,048 m.
- Deriva al girar el jugador durante cuatro segundos: 0,000 m.
- Fotogramas intentando orbitar: 0.
- Mezcla de animacion de caminar en reposo: 0,000.
- Agente sobre el suelo y mapa de navegacion en iteracion 3.

Prueba automatica de puerta abierta dentro de `test.tscn`:

- Activaciones de la maniobra de cruce: 1.
- Cambios de lado del portal: 1.
- Distancia final natural al jugador: 2,05 m.
- Giro acumulado durante el cruce automatico: 0,07 rad.
- Maniobra terminada y sin reentrada en la misma puerta.

Prueba de imitacion de postura dentro de `test.tscn`:

- Altura de capsula de pie: 1,280 m.
- Altura agachado: 0,860 m.
- Altura cuerpo a tierra: 0,520 m.
- Ciclo completo de regreso a pie: 1,280 m, sin residuo de animacion.
- Velocidad maxima observada agachado: 0,83 m/s.
- Velocidad maxima observada a cuatro patas: 0,48 m/s.

Prueba aislada de seguimiento, CERCA y QUIETO:

- Recorrido: 3,08 m.
- Inversiones bruscas: 0.
- Distancia final de seguimiento: 2,36 m.
- Deriva al girar: 0,000 m.
- Distancia final en CERCA: 0,70 m.
- Deriva en QUIETO: 0,000 m.

Los scripts reproducibles son `tools/audit_companion_in_game.gd`,
`tools/audit_companion_doors.gd`, `tools/validate_companion_postures.gd`,
`tools/validate_companion_movement.gd` y `tools/validate_companion_npc.gd`.
