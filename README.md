# Sistema Distribuido de Coordinación y Gestión de Emergencias
**Proyecto Final — Programación III (Universidad del Quindío)**  
Sistema en Elixir/OTP con arquitectura hexagonal estricta, dominio puro con nombres en infinitivo, concurrencia serializada, tolerancia a fallos e interfaz web en tiempo real con Phoenix LiveView.

## 1. Comandos de Ejecución
```bash
mix compile --warnings-as-errors       # Compilación estricta sin advertencias
mix test                               # Pruebas unitarias, concurrencia, web y persistencia
mix phx.server                         # Servidor web LiveView en http://localhost:4000
mix run priv/simulacion_concurrente.exs# Carrera concurrente real (Task.async_stream)
mix run priv/demostracion.exs          # Flujo completo paso a paso (caso Laura)
mix run priv/main.exs                  # Consola interactiva CLI (1 sola línea)
```

## 2. Comandos CLI y Matriz de Permisos (RBAC)
| Comando | Parámetros | Permiso | Descripción |
| :--- | :--- | :---: | :--- |
| `connect` / `disconnect` | `<usuario> <clave> [rol]` | Todos | Autenticación con SHA-256 + sal / Cierre de sesión |
| `register_zone` / `list_zones` | `<cod> <nom> <gravedad> [personas=N]` | Coord | Registro territorial y listado de zonas |
| `register_sector` / `register_point` | `<zona> <sector> ...` | Coord | Jerarquía: `Zona -> Sector -> PuntoAtencion` |
| `zone_status` | `<zona>` | Coord | Censo territorial consolidado por recursión pura |
| `register_resource` / `list_resources` | `<cod> <nom> <cant> <uni> <ubic>` | Volun | Entrada y consulta de existencias por almacén |
| `transfer_resource` | `<cod> <orig> <dest> <cant>` | Coord | Mueve stock entre ubicaciones/centros de apoyo |
| `register_need` / `list_needs` | `<zona> <rec> <cant> <prio> [desc]` | Ciudad | Solicitud y consulta de necesidades humanitarias |
| `assign_resource` | `<recurso> <necesidad> <cant>` | Coord | Asignación atómica sin sobre-asignación ni compensación |
| `report_person` / `find_person` | `<doc> <nom> <edad> <zona> [est]` | Ciudad | Registro y censo flexible por documento o filtros |
| `update_person` | `<doc> <nuevo_estado>` | Coord | Actualización del estado de personas damnificadas |
| `send_family_message` / `list_family_messages` | `<doc> <contenido>` | Ciudad | Mensajería familiar vinculada a personas censadas |
| `report_pet` / `list_pets` | `<tipo> <esp> <col> <tam> <zona> [nom]`| Ciudad | Reporte de mascotas (`perdida` o `encontrada`) |
| `match_pets` / `confirm_match` | `[umbral]` / `<id_p> <id_e>` | Coord | Algoritmo Jaccard ponderado y cierre de reportes |
| `register_shelter` / `check_shelter` | `<nom> <zona> <cap>` / `<id>` | Coord/Ciu | Registro supervisado y consulta en tiempo real |
| `register_entry` / `register_exit` | `<id_albergue> <doc>` | Volun | Control de aforo estricto sin sobrecupo ($O(1)$) |
| `link_shelter_resource` / `link_shelter_need` | `<id> <ref>` | Coord | Vinculación de insumos y requerimientos a albergue |
| `list_shelters` / `shelter_report` | *ninguno* | Coord | Listado y reporte ordenado por ocupación (Merge Sort) |
| `summary` / `pending_needs` | *ninguno* | Coord | Resumen ejecutivo y necesidades pendientes ordenadas |
| `critical_resources` | `[umbral]` | Coord | Insumos con stock bajo el umbral (por recursión) |
| `help` / `exit` | *ninguno* | Todos | Ayuda interactiva y salida limpia de la consola |

## 3. Interfaz Web (Phoenix LiveView)
### Pantallas del Sistema (http://localhost:4000)
| Ruta | Rol Mínimo | Descripción Operativa |
| :--- | :---: | :--- |
| `/` | Público | Autenticación con selección de rol (`coordinador`, `voluntario`, `ciudadano`) |
| `/resumen` | Coordinador | Tablero de mando global con tarjetas y filtro de recursos críticos |
| `/logistica` | Voluntario | Inventario, solicitudes, asignación atómica y botón de simulación concurrente |
| `/zonas` | Coordinador | Jerarquía territorial y censo consolidado mediante recursión pura |
| `/familiares`| Ciudadano | Censo de personas damnificadas y mensajería familiar bidireccional |
| `/mascotas` | Ciudadano | Búsqueda flexible, similitud de Jaccard ponderada (&ge; 60%) y resolución |
| `/albergues` | Voluntario | Gestión de aforo en tiempo real con ordenamiento por ocupación (Merge Sort) |

### Arquitectura y Tiempo Real Multi-Usuario
- **Adaptador de Entrada Hexagonal:** Las vistas (`lib/emergencias_web/vivo/`) llaman exclusivamente a los casos de uso (`Emergencias.Aplicacion.CasosUso.*`), sin acoplarse a GenServers ni archivos.
- **Sincronización Reactiva (PubSub):** Al completar con éxito una mutación, se difunde un evento al tópico `"emergencias"`. Todas las LiveViews suscritas reciben el mensaje en `handle_info/2` y refrescan sus datos en vivo.
- **Prueba Multi-Pestaña:** Abre una pestaña normal y otra en modo incógnito con distintos usuarios: toda acción en una ventana se refleja de inmediato en la otra sin recargar.

## 4. GestorLogistica: Atomicidad sin Rollback
Las necesidades, recursos y movimientos se unificaron en el GenServer `GestorLogistica`. Su `handle_call({:asignar, ...})` invoca la función pura `Asignacion.asignar/6`. En un solo paso verifica existencia, estado abierto, cantidad no superior al saldo pendiente, compatibilidad y stock disponible. Al ejecutarse en el buzón FIFO del GenServer, toda asignación concurrente es estrictamente atómica: si algo no cumple, el estado no muta y no se requiere compensación ni rollback.

## 5. Estructuras de Datos Justificadas
- **Map:** Índices asociativos para búsqueda y mutación $O(1)$ por identificador.
- **List:** Colecciones secuenciales para descomposición recursiva cabeza/cola `[cabeza | cola]`.
- **Tupla:** Retornos canónicos atómicos de éxito/error (`{:ok, valor}`, `{:error, razon}`).
- **MapSet:** Verificación de pertenencia e unicidad $O(1)$ en roles RBAC y personas en albergues.
- **Structs anidados:** Modelado estricto e integridad del árbol `Zona -> Sector -> PuntoAtencion`.
- **Keyword:** Lista de opciones y filtros dinámicos opcionales en consultas CLI.

## 6. Algoritmos y Recursión Pura (sin Enum.reduce)
- `contar_puntos_atencion/1`: Base `[] -> acc`, Recursivo `[s | r] -> s.puntos + acc`. Usado en `zone_status`.
- `sumar_personas_afectadas/1`: Base `[] -> acc`, Recursivo suma personas de sectores y puntos. Usado en `zone_status`, `summary`.
- `buscar_punto_atencion/2`: Base `[] -> nil` o `id == p.id`, Recursivo busca en puntos y sectores. Usado en `register_point`.
- `ordenar/2` (Merge Sort): Base `[]` o `[x]`, Recursivo parte en mitades y mezcla ordenado. Usado en `pending_needs`, `shelter_report`.
- `sumar_cantidades/2`: Base `[] -> acc`, Recursivo `[m | r] -> m.cant + acc`. Usado en `critical_resources`.

## 7. Supuestos y Decisiones de Diseño
- **Hexagonal:** Dominio puro sin dependencias; casos de uso como API pública sin acoplarse a `Infraestructura` ni llamar `Process.whereis`.
- **Seguridad:** Contraseñas con `SHA-256` y sal fija (`emergencias_uq_2026_`) en Erlang puro (`:crypto.hash`), sin dependencias C/NIFs.
- **Supervisión:** `max_restarts: 3, max_seconds: 5` para visibilidad inmediata de fallos; albergues supervisados dinámicamente (`DynamicSupervisor` y bucles `receive` puros).
- **Persistencia:** Archivos `.txt` con encabezado UTF-8 (`:file.consult`), tolerante a líneas corruptas sin tumbar los procesos.
