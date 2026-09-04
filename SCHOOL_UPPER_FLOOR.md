# Segunda planta de la escuela

Escena integrada: `school_upper_floor.tscn`, instanciada en `house_baked.tscn`.
Pavimento a Y=4.16, sobre las losas existentes; techo a Y=8.16.

- Norte oeste: dormitorio con seis literas dobles, doce plazas, escalerillas, barandillas, ropa de cama y cajones.
- Norte este: aula con doce pupitres, sillas, cuadernos, mesa del profesor, pizarra, estantería y radiador.
- Sur: comedor con dos mesas y bancos para doce, vajilla y cocina independiente. La cocina incluye zona de cocción, horno, campana, fregadero, preparación, frigorífico, estantes y ventanilla de servicio.
- Distribuidor: continúa desde la escalera actual, con taquillas, tablón y protección del borde del descansillo.
- Este: puente exterior sobre la conexión existente, con balaustradas del proyecto. El umbral adapta la pequeña diferencia de cota con la casa.

Las puertas se abren con F. Aula y dormitorio abren hacia el distribuidor para dejar libre el recibidor interior. Los assets originales se reutilizan por instancia: no se modifican sus escenas fuente.

El extremo del puente junto a la casa utiliza ahora `push_door.tscn`, la puerta normal del proyecto. La ventana contigua, sus marcos, cortinas y colisiones se desplazaron 65 cm al norte, ajustando los paños de muro para dejar su cristal libre.

`school_rain_shelter.gd` instala protección de partículas en las dos plantas al ejecutar el juego. Los volúmenes siguen las salas y los pasillos; el puente superior permanece al aire libre. La protección original de la casa termina en su fachada oeste, sin cubrir por error el puente.

Farola reutilizable: `house_props/courtyard_streetlamp.tscn`. Se puede arrastrar a cualquier escena; tiene piezas editables, colisiones de base/poste/farol, luz cálida con sombras y desvanecimiento por distancia. En el inspector: `enabled`, `light_color`, `energy` y `light_range`. Altura aproximada: 4.46 m. No se ha colocado automáticamente en el mapa.

La única modificación de una colisión anterior es el hueco del acceso superior en `UpperFloor/ExteriorWalls/Wall_09`. El resto del muro se conserva, repartido alrededor del nuevo portal. La conexión inferior no se modifica. `runtime_house_navigation.tscn` amplía únicamente el volumen de generación para incluir el ala oeste.

## Edición y comprobación

La escena tiene grupos para estructura, techo, cada estancia y puente. `SchoolUpperFloor` tiene los hijos editables habilitados en `house_baked.tscn`. Sus instancias interiores están desplegadas en nodos locales: cada pieza nueva tiene su propia malla, transformación y material. Los cambios en una silla o una litera dentro de la planta no afectan a las demás.

En el árbol puedes mover `Chair`, `Desk`, `Notebook`, `Table`, `BenchLeft`, `BenchRight`, `Fridge`, `Oven`, `Sink`, `PreparationCounter` o `ExtractorHood` por separado. Cada grupo conserva sus colisiones; mueve o escala el grupo para que la colisión acompañe al objeto. Las literas también separan ropa de cama, escalera y cajón. Expande cualquier grupo para editar sus piezas. Las luminarias incluyen su luz y carcasa juntas. Los assets reutilizados mantienen sus mallas originales.

`school_upper_runtime.gd` une las piezas estáticas por habitación y material únicamente al jugar, respetando las posiciones editadas. En el editor permanecen separadas. `house_props/school_furniture_navigation.gd` crea los recortes de navegación al ejecutar: no hay obstáculos de navegación serializados ni sus recuadros amarillos permanentes en el editor.

`tools/build_school_upper_floor.gd` regenera las tres escenas nuevas de mobiliario y la segunda planta. No debe ejecutarse después de editar manualmente esas escenas sin conservar antes esos cambios.

`tools/validate_school_upper_floor.gd` compara las colisiones originales en reposo y comprueba suelo y espacio para una cápsula de 0.68 m de ancho y 2.10 m de alto en los cinco recorridos. `-- --navigation` comprueba rutas desde la casa; `-- --preview` guarda vistas de las salas, puente y plano sin techo en `tools/school_upper_*.png`.

También se ha ejecutado `tools/validate_corridor_stairs_and_tunnels.gd`: ambas rampas, descansillo y túneles mantienen su comprobación física.
