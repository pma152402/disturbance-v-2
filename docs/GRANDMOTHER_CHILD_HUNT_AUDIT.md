# Caza prioritaria de niños

Fecha: 2026-09-06

## Bucle implementado

1. La abuela consulta todos los nodos del grupo `child_target`.
2. Mientras quede algun niño vivo, elige el mas cercano como presa.
3. Actualiza su posicion mundial y sigue el siguiente punto de
   `NavigationAgent3D` con postprocesado `CORRIDORFUNNEL`.
4. Al alcanzarlo ejecuta el ataque. El niño deja de aceptar ordenes, su collider
   se desactiva y el visual cae lateralmente hasta quedar inmovil en el suelo.
5. La abuela entra en `State.EAT`, se arrodilla y reproduce una animacion de
   alimentacion. Durante 20 segundos no persigue, investiga ni ataca.
6. Al terminar selecciona al siguiente niño vivo. Cuando ya no queda ninguno,
   la presa pasa a ser el jugador.

La misma prioridad esta integrada en la abuela base y en la variante importada
fotosensible. Sus reglas de luces vuelven a aplicarse cuando no quedan niños.

## Integracion con el futuro bucle A -> B

- Cada niño emite `killed_by_monster(attacker)` al morir.
- La abuela emite `child_caught(child)` al empezar a comer y
  `finished_eating_child(child)` al terminar.
- `release_after_monster_capture(position)` permite revivir y recolocar al niño
  al reiniciar un trayecto sin reinstanciar su asset.
- `is_dead()` y `can_be_targeted_by_monster()` permiten al controlador de ronda
  contar niños vivos y resolver exito o fracaso.

## Resultados automatizados

- Secuencia con dos niños: `niño A -> comer 20 s -> niño B -> comer 20 s -> jugador`.
- Navegacion de prueba: distancia al niño reducida de 4,78 m a 0,71 m.
- Velocidad maxima de persecucion: 2,75 m/s.
- Ruta obtenida mediante `NavigationAgent3D`: 2 puntos, sin invertir la presa.

Pruebas reproducibles:

- `tools/validate_grandmother_child_priority.gd`
- `tools/validate_grandmother_navigation_priority.gd`
