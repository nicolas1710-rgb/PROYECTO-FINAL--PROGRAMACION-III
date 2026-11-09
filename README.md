# Sistema Distribuido de Coordinación y Gestión de Emergencias

**Proyecto Final — Programación III**  
**Universidad del Quindío**  
**Tecnología:** Elixir / Erlang/OTP  
**Arquitectura:** Hexagonal Estricta (Ports and Adapters)  
**Calidad:** 100% de Pruebas ExUnit Exitosas (74/74), Cero Advertencias (`--warnings-as-errors`)

---

## 1. Visión General del Sistema

Tras un terremoto devastador, las comunicaciones y la logística colapsan. Este sistema distribuido y concurrente permite coordinar en tiempo real la ayuda humanitaria, el inventario de suministros críticos, el censo y localización de personas damnificadas, la mensajería familiar, el emparejamiento inteligente de mascotas extraviadas y el control estricto de aforo en albergues temporales.

El sistema fue diseñado y construido bajo las siguientes **reglas innegociables**:
- **Nombres de funciones en infinitivo en español:** (`registrar/2`, `asignar/3`, `contar_puntos_atencion/1`, `poder_transitar?/2`, etc.). Todos los callbacks exigidos por OTP (`init/1`, `handle_call/3`, `handle_cast/2`, `child_spec/1`) delegan de inmediato a funciones propias en infinitivo.
- **`priv/main.exs` de exactamente 1 línea:** No contiene definiciones `def`/`defp` ni lambdas. Ejecutable con `mix run priv/main.exs`.
- **Arquitectura Hexagonal Estricta:** La capa de aplicación (`lib/emergencias/aplicacion/`) tiene **0 referencias** a la infraestructura (`Emergencias.Infraestructura.*`) y **0 llamadas** a `Process.whereis`. La interacción se realiza mediante 7 puertos de salida especializados basados en `@behaviour`.
- **Funciones puras de dominio sin excepciones:** Retornos canónicos `{:ok, resultado}` y `{:error, razon_atom}` usando pattern matching, guards y `with`.
- **Validación previa de toda entrada:** Tipos, rangos, documentos, enums y permisos validados antes de tocar el estado o la memoria.
- **Concurrencia segura y serialización atómica:** Resolución determinista de condiciones de carrera mediante `GenServer` (buzón FIFO) y procesos puros con bucle `receive` recursivo.

---

## 2. Arquitectura del Proyecto

```
emergencias/
├── mix.exs                                              # Configuración del proyecto Mix
├── README.md                                            # Documentación técnica, justificaciones y guion
├── config/                                              # Inyección de dependencias de puertos
│   └── config.exs
├── priv/
│   ├── main.exs                                         # Entrada de producción: exactamente 1 línea
│   └── demostracion.exs                                 # Script de demostración concurrente automatizada
├── datos/                                               # Almacenamiento transaccional en texto plano (.txt)
│   ├── usuarios.txt, zonas.txt, necesidades.txt, recursos.txt
│   ├── movimientos.txt, personas.txt, mensajes.txt, mascotas.txt
│   ├── albergues.txt y actividad.txt
├── docs/diagramas/                                      # Diagramas Mermaid
│   ├── modulos.mmd                                      # Arquitectura Hexagonal y Puertos
│   ├── modelo_datos.mmd                                 # Modelo ER y Clases de Dominio
│   ├── secuencia.mmd                                    # Flujo Concurrente de Asignación Atómica
│   └── arbol_otp.mmd                                    # Árbol de Supervisión OTP
├── lib/emergencias/
│   ├── application.ex                                   # Árbol de supervisión principal (:one_for_one)
│   ├── dominio/                                         # NÚCLEO PURO (inmutable, sin IO, sin procesos)
│   │   ├── modelos/                                     # Structs tipados con @enforce_keys
│   │   │   ├── usuario.ex, zona.ex, sector.ex, punto_atencion.ex
│   │   │   ├── necesidad.ex, recurso.ex, movimiento_inventario.ex
│   │   │   ├── persona.ex, mensaje.ex, reporte_mascota.ex
│   │   │   └── albergue.ex, registro_actividad.ex
│   │   └── reglas/                                      # Lógica pura y algoritmos recursivos
│   │       ├── validaciones.ex, transiciones_estado.ex, permisos.ex
│   │       ├── prioridades.ex, ordenamiento.ex, inventario.ex
│   │       ├── ocupacion.ex, similitud_mascotas.ex, estadisticas_zona.ex
│   ├── aplicacion/                                      # CASOS DE USO Y PUERTOS FORMALES
│   │   ├── puertos/
│   │   │   ├── entrada/                                 # Behaviours de casos de uso
│   │   │   └── salida/                                  # 7 Behaviours de salida especializados:
│   │   │       ├── puerto_salida_usuarios.ex, puerto_salida_zonas.ex
│   │   │       ├── puerto_salida_necesidades.ex, puerto_salida_recursos.ex
│   │   │       ├── puerto_salida_personas.ex, puerto_salida_mascotas.ex
│   │   │       ├── puerto_salida_albergues.ex, bitacora.ex, reloj.ex, generador_id.ex
│   │   └── casos_uso/                                   # Orquestación de reglas puras y puertos
│   │       ├── gestionar_usuarios.ex, gestionar_zonas.ex, gestionar_necesidades.ex
│   │       ├── gestionar_recursos.ex, gestionar_familiares.ex, gestionar_mascotas.ex
│   │       └── gestionar_albergues.ex, generar_resumenes.ex
│   └── infraestructura/                                 # ADAPTADORES EXTERNOS
│       ├── salida/persistencia/                         # MotorPersistencia, AlmacenArchivo, CodificadorTexto
│       ├── procesos/                                    # Gestores GenServer, AdaptadorAlbergues, Registry
│       └── entrada/consola/                             # Consola CLI, AnalizadorComandos, Presentador, Despachador
└── test/                                                # Suite completa de pruebas ExUnit (74 pruebas)
```

---

## 3. Instrucciones de Ejecución

### Requisitos Previos
- Elixir 1.14 o superior (verificado y optimizado en Elixir 1.20.4 con Erlang/OTP 29 en Windows).

### 1. Compilación Estricta
Verifica que no exista ninguna advertencia en el código:
```bash
mix compile --warnings-as-errors
```

### 2. Ejecutar la Suite de Pruebas
Ejecuta las **74 pruebas automáticas** (unitarias de dominio puro, casos de uso con persistencia en memoria, transacciones atómicas recurso-necesidad, procesos concurrentes y tolerancia a fallos):
```bash
mix test
```

### 3. Ejecutar la Demostración Concurrente Automatizada
Reproduce paso a paso el caso de estudio completo, demostrando la contención de stock en paralelo en vivo mediante `Task.async_stream`:
```bash
mix run priv/demostracion.exs
```

### 4. Iniciar la Consola Interactiva
Inicia la consola interactiva de usuario a través de `priv/main.exs`:
```bash
mix run priv/main.exs
```

---

## 4. Tabla de Comandos de la Consola

| Comando | Argumentos | Rol Mínimo | Descripción |
| :--- | :--- | :--- | :--- |
| `connect` | `<usuario> <clave> [rol]` | Cualquiera | Inicia sesión o auto-registra al usuario con clave cifrada SHA-256 + sal. |
| `disconnect` | *ninguno* | Autenticado | Cierra la sesión activa actual en la consola. |
| `register_zone` | `<nombre> <gravedad>` | Coordinador | Registra una nueva zona (`critico`, `alto`, `medio`, `bajo`). |
| `register_need` | `<zona> <recurso> <cantidad> <prioridad>` | Ciudadano | Reporta una necesidad humanitaria (`critica`, `alta`, `media`, `baja`). |
| `list_needs` | `[zona=Z] [prioridad=P] [estado=E]` | Ciudadano | Lista necesidades aplicando filtros opcionales de consulta. |
| `assign_resource` | `<id_recurso> <id_necesidad> <cant>` | Coordinador | Asigna recursos atómicamente a una necesidad, validando stock y cuota. |
| `register_resource` | `<tipo> <unidad> <cantidad> <zona>` | Voluntario | Registra un lote de suministros en el inventario de la zona. |
| `list_resources` | `[zona=Z] [tipo=T]` | Ciudadano | Consulta las existencias totales, disponibles y reservadas. |
| `transfer_resource` | `<id_origen> <id_destino> <cant>` | Coordinador | Transfiere stock entre recursos o hacia un centro de apoyo de forma atómica. |
| `report_person` | `<documento> "<nombre_completo>"` | Ciudadano | Reporta a una persona damnificada o extraviada en el censo. |
| `find_person` | `<documento>` | Ciudadano | Consulta el estado y ubicación actual de una persona. |
| `send_family_message` | `<documento> "<mensaje>"` | Ciudadano | Envía un mensaje familiar asociado al documento de la persona. |
| `list_family_messages`| `<documento>` | Ciudadano | Lista los mensajes recibidos para una persona damnificada. |
| `report_pet` | `<tipo> <esp> <col> <tam> <zona> [nom]`| Ciudadano | Reporta mascota (`perdida` o `encontrada`). |
| `match_pets` | `[umbral]` | Coordinador | Ejecuta algoritmo de similitud ponderada entre mascotas activas. |
| `register_shelter` | `<nombre> <zona> <capacidad>` | Coordinador | Registra un nuevo albergue supervisado con aforo máximo. |
| `check_shelter` | `<id_albergue>` | Ciudadano | Consulta ocupación en tiempo real, ocupantes y recursos vinculados. |
| `register_entry` | `<id_albergue> <documento>` | Voluntario | Registra ingreso de persona validando cupo máximo sin sobrecupo. |
| `register_exit` | `<id_albergue> <documento>` | Voluntario | Registra salida/egreso de una persona del albergue liberando cupo. |
| `summary` | *ninguno* | Coordinador | Presenta el consolidado ejecutivo global de la emergencia. |
| `critical_resources` | `[umbral]` | Coordinador | Lista suministros con existencias menores o iguales al umbral. |
| `pending_needs` | *ninguno* | Coordinador | Lista necesidades pendientes ordenadas por Merge Sort recursivo. |
| `help` | *ninguno* | Cualquiera | Muestra la guía de ayuda interactiva. |
| `exit` | *ninguno* | Cualquiera | Finaliza la sesión y cierra la consola de forma limpia. |

---

## 5. Matriz de Control de Acceso (Permisos RBAC)

Implementada mediante `MapSet` en el módulo puro `Emergencias.Dominio.Reglas.Permisos` para garantizar verificaciones de autorización en $O(1)$:

| Operación | Ciudadano | Voluntario | Coordinador | Administrador |
| :--- | :---: | :---: | :---: | :---: |
| `registrar_necesidad`, `listar_necesidades` |  |  |  |  |
| `reportar_persona`, `buscar_persona` |  |  |  |  |
| `enviar_mensaje`, `listar_mensajes` |  |  |  |  |
| `reportar_mascota` |  |  |  |  |
| `consultar_albergue` |  |  |  |  |
| `listar_recursos` |  |  |  |  |
| `registrar_recurso` | ❌ |  |  |  |
| `registrar_entrada_albergue`, `registrar_salida_albergue` | ❌ |  |  |  |
| `asignar_recurso`, `transferir_recurso` | ❌ | ❌ |  |  |
| `registrar_zona`, `registrar_albergue` | ❌ | ❌ |  |  |
| `emparejar_mascotas`, `resolver_mascota` | ❌ | ❌ |  |  |
| `actualizar_necesidad`, `actualizar_persona` | ❌ | ❌ |  |  |
| `generar_resumen`, `recursos_criticos`, `necesidades_pendientes` | ❌ | ❌ |  |  |

---

## 6. Acoplamiento Transaccional: Asignación Recurso-Necesidad

El requerimiento exige garantizar que un recurso no pueda asignarse si la necesidad no existe, si ya fue atendida/cancelada, o si la cantidad excede lo pendiente:

1. **Validación Previa:** En `GestionarRecursos.asignar_recurso/4`, se consulta la necesidad a través de `PuertoSalidaNecesidades.consultar(id_necesidad)`.
2. **Chequeo de Estado:** Se verifica que la necesidad esté en estado abierto (`:pendiente` o `:asignada`). Si está en `:atendida` o `:cancelada`, la operación es rechazada con `{:error, :necesidad_ya_cerrada}`.
3. **Cálculo de Cuota:** Se valida que la cantidad a suministrar no sobrepase el saldo pendiente (`solicitada - asignada`).
4. **Descuento Atómico:** Se solicita el descuento de inventario a `PuertoSalidaRecursos.asignar(...)` en el GenServer `GestorRecursos`.
5. **Actualización de la Necesidad:** Si el recurso descuenta exitosamente, se invoca `PuertoSalidaNecesidades.asignar_suministro(...)` para incrementar `cantidad_asignada`.
   - Si la necesidad queda 100% cubierta, transiciona automáticamente a `:atendida`.
   - Si queda cubierta parcialmente, transiciona a `:asignada`.
6. **Reversión Automática (Rollback):** Si la actualización de la necesidad fallase, el caso de uso devuelve inmediatamente el stock al recurso para evitar inconsistencias.

---

## 7. Justificación de Seguridad: Contraseñas con SHA-256 y Sal Criptográfica

Para la sustentación académica, el almacenamiento de contraseñas se diseñó con las siguientes consideraciones:

- **Algoritmo:** SHA-256 implementado directamente en el runtime de Erlang a través de `:crypto.hash(:sha256, @sal_segura <> clave)`.
- **Sal de Aplicación:** Se incorpora un prefijo criptográfico constante (`@sal_segura = "emergencias_uq_2026_"`) para mitigar ataques basados en tablas precalculadas (Rainbow Tables).
- **Justificación Didáctica y Técnica:** En entornos de producción corporativa se suele utilizar Argon2 o bcrypt. Sin embargo, para este proyecto académico y distribuido en Elixir puro:
  1. No requiere compiladores externos de C (NIFs de C), garantizando portabilidad absoluta entre Windows, macOS y Linux sin fallos de compilación nativa.
  2. Es completamente determinista y reproducible para evaluación inmediata del jurado.
  3. No almacena jamás contraseñas en texto plano en `datos/usuarios.txt`.

---

## 8. Funciones Recursivas Obligatorias

Todas las funciones recursivas fueron desarrolladas explícitamente sin utilizar abstracciones de orden superior como `Enum.reduce`:

### 1. `contar_puntos_atencion/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Contar el total de puntos de atención a través de todos los sectores de una zona.
- **Caso Base:** Lista vacía de sectores `[]` retorna el acumulador.
- **Caso Recursivo:** Para `[%Sector{puntos_atencion: puntos} | resto]`, suma recursivamente la longitud de los puntos al acumulador y procesa los sectores restantes con recursión de cola.

### 2. `sumar_personas_afectadas/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Acumular el total de damnificados en todos los puntos de la jerarquía territorial.
- **Caso Base:** Lista vacía retorna el subtotal acumulado.
- **Caso Recursivo:** Suma las personas afectadas del punto actual y continúa recursivamente sobre la lista de puntos y sectores.

### 3. `buscar_punto_atencion/2` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Búsqueda recursiva por código identificador en la estructura anidada.
- **Caso Base 1:** Sectores agotados retorna `{:error, :no_encontrado}`.
- **Caso Base 2:** Coincidencia en cabeza de lista retorna `{:ok, punto}`.
- **Caso Recursivo:** Continúa buscando en los puntos del sector o avanza recursivamente al siguiente sector.

### 4. `aplanar_jerarquia/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Transformar el árbol `Zona -> Sectores -> Puntos` en una lista plana.
- **Caso Base:** Sectores agotados retorna la lista acumulada invertida.
- **Caso Recursivo:** Extrae los puntos del sector de la cabeza y continúa recursivamente.

### 5. `sumar_cantidades/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Sumar las cantidades numéricas de una lista histórica de movimientos de inventario.
- **Caso Base:** Lista de movimientos vacía retorna el acumulador.
- **Caso Recursivo:** Suma `movimiento.cantidad` al acumulador y continúa procesando la cola.

### 6. `ordenar_por_prioridad/1` (`Emergencias.Dominio.Reglas.Ordenamiento` - Merge Sort)
- **Propósito:** Ordenar necesidades humanitarias por prioridad descendente (`critica` > `alta` > `media` > `baja`) desempatando por fecha más antigua (ascendente).
- **Caso Base:** Listas de tamaño 0 o 1 (`[]` o `[x]`) ya están ordenadas por definición.
- **Caso Recursivo:** Divide la lista en mitades con `dividir_lista/1`, ordena cada mitad recursivamente y las combina con `mezclar_listas/3`.

---

## 9. Supervisión OTP, Tolerancia a Fallos y Concurrencia

### Árbol de Supervisión Raíz (`SupervisorRaiz`)
- Estrategia: `:one_for_one`.
- Límites de reinicio ajustados según mejores prácticas del curso: `max_restarts: 3, max_seconds: 5`. Esto garantiza que bucles de error no se oculten y se detecten fallas de configuración inmediatamente.

### Supervisión Dinámica de Albergues
- `SupervisorAlbergues` (`DynamicSupervisor`) gestiona los procesos independientes de cada albergue.
- Cada albergue corre como un proceso concurrente puro con bucle `receive` recursivo, registrado en `Emergencias.RegistroAlbergues` (`Registry :unique`).
- `AdaptadorAlbergues` implementa `PuertoSalidaAlbergues`, coordinando el DynamicSupervisor, Registry y la persistencia en disco de manera transparente para los casos de uso.

### Demostración de Concurrencia en Vivo (`priv/demostracion.exs`)
El script ejecuta dos peticiones simultáneas utilizando `Task.async_stream`:
- Recurso R001 tiene 50 litros disponibles.
- Tarea 1 intenta asignar 30 L para N001.
- Tarea 2 intenta asignar 25 L para N002.
- Total requerido (55 L) > stock disponible (50 L).
- El buzón del GenServer `GestorRecursos` serializa las operaciones: la primera petición descuenta 30 L (dejando 20 L) y la segunda es rechazada atómicamente por stock insuficiente.
- Posteriormente, se ejecuta una transferencia de 10 L desde R002 a R001, y la asignación rechazada se reintenta exitosamente.

---

## 10. Checklist de Requisitos Cumplidos

- [x] **Convención de Nombres:** 100% funciones con verbos en infinitivo en español (`registrar/2`, `validar/1`, `asignar/3`, `poder_transitar?/2`, etc.). Callbacks OTP delegan de inmediato a funciones en infinitivo.
- [x] **Línea Única en Main:** `priv/main.exs` contiene exactamente 1 línea sin funciones ni lambdas.
- [x] **Arquitectura Hexagonal Estricta:** Dominio y aplicación 100% aislados de infraestructura. Cero llamadas a `whereis` y cero referencias a `Infraestructura` en la capa de aplicación.
- [x] **7 Puertos de Salida Especializados:** Implementados por los gestores de infraestructura e inyectados vía configuración.
- [x] **Funciones Puras:** Retornos canónicos `{:ok, _}` o `{:error, _}`; cero excepciones no controladas en reglas de negocio.
- [x] **Validación Exhaustiva de Entradas:** Validación de tipos, enteros, enums y permisos antes de modificar el estado.
- [x] **Transacciones Atómicas Recurso-Necesidad:** Validación de necesidad abierta, control de sobre-asignación, reversión automática y actualización de estado.
- [x] **Estructuras de Datos Justificadas:** `Map`, `List`, `Tupla`, `MapSet`, `Struct` anidados y `Keyword List`.
- [x] **Recursividad Obligatoria:** 6 funciones recursivas puras implementadas sin `Enum.reduce`.
- [x] **Ordenamiento Propio:** Merge Sort recursivo para priorizar necesidades humanitarias.
- [x] **Similitud Ponderada de Mascotas:** Algoritmo ponderado (0-100) con coeficiente Jaccard.
- [x] **Concurrencia OTP:** GenServers serializadores y procesos puros con bucle `receive` recursivo.
- [x] **Supervisión Dinámica:** `SupervisorAlbergues` (`DynamicSupervisor`) y `Registry :unique`.
- [x] **Persistencia Atómica en Texto Plano:** Archivos `.txt` con escritura temporal y renombrado atómico tolerante a líneas corruptas.
- [x] **Pruebas Completas ExUnit:** 74 pruebas unitarias, de integración y de concurrencia pasando al 100%.
- [x] **Compilación Limpia:** `mix compile --warnings-as-errors` con 0 advertencias y 0 errores.
- [x] **Diagramas Mermaid:** `modulos.mmd`, `modelo_datos.mmd`, `secuencia.mmd` y `arbol_otp.mmd` actualizados.
- [x] **Demostración Automatizada Idempotente:** `priv/demostracion.exs` con carrera concurrente real mediante `Task.async_stream`.
