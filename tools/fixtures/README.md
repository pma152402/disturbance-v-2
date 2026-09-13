# Datos de referencia

Estas instantáneas son entradas de validación, no resultados desechables:

- `school_collision_baseline.json`: colisiones anteriores a la ampliación; lo usa `validate_school_upper_floor.gd`.
- `school_edit_geometry.json`: geometría de referencia para `check_school_edit_geometry.gd`.
- `stance_indicator_before_optimization.gd`: algoritmo original del HUD, conservado
  como referencia independiente para comparar píxeles y coste de CPU. No actualizar
  al cambiar la implementación optimizada.

Los inspectores escriben en `../output/` para no sobrescribir estas referencias.
