# Planos de trabajo

Las cinco imagenes se generan directamente desde las escenas 3D actuales. No son
planos constructivos: sirven para colocar mobiliario, pistas, enemigos, luces y
recorridos respetando la distribucion existente.

Cada cuadricula pequena representa **1 metro** y el norte queda hacia arriba.

## Llaves y puertas

Los marcadores `L` indican una llave y los marcadores `P` una puerta. El numero y
el color emparejan cada llave con todas las puertas que abre.

| Codigo | Llave | Resultado actual |
| --- | --- | --- |
| 1 | Trastero | Abre cinco puertas de almacenamiento |
| 2 | Diogenes | Abre la puerta del dormitorio de Diogenes |
| 3 | Puerta principal | Hay dos copias; ambas abren la entrada principal |
| 4 | Dormitorio | Aparece desde el inodoro y abre el dormitorio principal |
| 5 | Ala norte | Abre el acceso superior al ala norte |
| 6 | Iglesia | Abre la puerta de la iglesia |
| 7 | Sotano | Hay dos copias, pero ninguna puerta exige actualmente esta llave |
| 8 | Azotea | Esta en el sotano y abre la escalera de la azotea |

El asterisco de `L4*` indica que la llave empieza oculta. La exclamacion de
`L7a!` y `L7b!` marca las dos llaves sin puerta vinculada.

| Imagen | Contenido |
| --- | --- |
| `01_conjunto_planta_baja.png` | Iglesia, escuela, casa y conexiones en planta baja |
| `02_primera_planta_casa_escuela.png` | Primera planta de la casa, escuela y puente |
| `03_segunda_planta_escuela.png` | Segunda planta de la escuela |
| `04_sotano_caldera.png` | Sotano, caldera, servicio y acceso al tunel |
| `05_catacumbas.png` | Recorrido completo de las catacumbas |

Para regenerarlos despues de mover geometria:

```powershell
& "C:\Users\papar\Desktop\godot.exe" --path . --script res://tools/render_project_plans.gd
```
