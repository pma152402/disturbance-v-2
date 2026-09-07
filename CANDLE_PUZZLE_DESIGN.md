# Puzzle de velas de la iglesia

La mesa de ofrendas está frente al altar y reproduce literalmente las tres referencias: `A` (3 columnas por 4 filas), `B` (6 por 2) y `C` (2 por 3). Todos usan el mismo aro circular visible del patrón B; solo cambia su distribución. Cada aro es una posición real donde se puede encajar una vela.

## Lectura del patrón

Las filas corresponden a tres espacios del colegio y las columnas a sus dos lados. El jugador obtiene la información de dónde estaba cada niño mediante pupitres, camas, bancos del comedor y notas. Un recorte de periódico puede separar supervivientes de desaparecidos; solo se encienden/colocan velas para estos últimos.

La solución marcada en la referencia contiene ocho posiciones: A (`6, 9, 10`), B (`12, 20, 22`) y C (`24, 25`).

Está en `solution_slots` de `house_props/candle_offering_table.tscn`, por lo que se puede cambiar desde el inspector sin tocar código. La mesa comienza con cuatro velas recolocables, algunas encendidas y con alturas de cera diferentes.

## Relación narrativa

La mesa era el antiguo registro nocturno de ausencias de la escuela. Sus tres patrones copiaban los planos del aula, el comedor y el dormitorio. Si un alumno faltaba al recuento, el prefecto encendía una vela en la posición que tenía asignada; la apagaba cuando regresaba. Después de la evacuación quedaron registros abiertos. El jugador cruza planos, documentos y la lista de supervivientes para reconstruirlos. No es un memorial: las luces significan que todavía se sigue buscando a esas personas.

Hay tres cuadros editables para repartir la explicación por el escenario: `school_clue_frame_places.tscn`, `school_clue_frame_return.tscn` y `school_clue_frame_motto.tscn`.

## Flujo jugable

1. Recoger velas y una caja de cerillas.
2. Encender la vela y pulsar `G` para activar su colocación.
3. Al apuntar a un hueco libre de la mesa, la previsualización se ajusta al centro; fuera de un hueco la colocación se rechaza.
4. Cada vela queda bloqueada en su hueco. Cuando el patrón coincide, la mesa gana una luz cálida y emite `puzzle_completed` para conectar una puerta, evento o recompensa posterior.

Por ahora no se ha bloqueado contenido del colegio ni una puerta: el asset queda autocontenido y el resultado se puede conectar cuando se decida qué desbloquea.
