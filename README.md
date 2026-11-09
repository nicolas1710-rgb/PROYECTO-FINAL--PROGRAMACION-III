# Sistema Distribuido de Coordinación y Gestión de Emergencias

**Proyecto Final — Programación III**  
**Universidad del Quindío**  
**Tecnología:** Elixir / OTP  
**Arquitectura:** Hexagonal Estricta (Ports and Adapters)

---

## 1. Visión General del Sistema

Tras un terremoto devastador, las comunicaciones y la logística colapsan. Este sistema distribuido y concurrente permite coordinar en tiempo real la ayuda humanitaria, el inventario de suministros críticos, el censo y localización de personas damnificadas, la mensajería familiar, el emparejamiento inteligente de mascotas extraviadas y el control de cupo en albergues temporales.

El sistema fue diseñado bajo estrictos principios de diseño en Elixir y OTP:
- **Nombres de funciones en infinitivo en español:** (`registrar/2`, `asignar/3`, `contar_puntos_atencion/1`, `poder_transitar?/2`, etc.). Los callbacks exigidos por OTP delegan de inmediato a funciones propias en infinitivo.
- **`priv/main.exs` de una sola línea:** No contiene definiciones de funciones ni lambdas.
- **Arquitectura Hexagonal:** Dominio puro aislado de dependencias externas, puertos formales con `@callback`, casos de uso orquestadores y adaptadores delgados de infraestructura.
- **Funciones puras sin excepciones:** Retornos canónicos `{:ok, resultado}` y `{:error, razon_atom}`.
- **Concurrencia segura y serialización atómica:** Resolución estricta de condiciones de carrera (ej. 30 y 25 litros solicitados simultáneamente sobre 50 disponibles) mediante `GenServer` y procesos puros con bucle `receive` recursivo.

---

## 2. Arquitectura del Proyecto

```
emergencias/
├── mix.exs                                              # Configuración del proyecto Mix
├── README.md                                            # Documentación técnica, justificaciones y guion
├── priv/
│   ├── main.exs                                         # Entrada de producción: exactamente 1 línea
│   └── demostracion.exs                                 # Script automatizado con el flujo completo
├── datos/                                               # Almacenamiento transaccional en texto plano (.txt)
│   ├── usuarios.txt
│   ├── zonas.txt
│   ├── necesidades.txt
│   ├── recursos.txt
│   ├── movimientos.txt
│   ├── personas.txt
│   ├── mensajes.txt
│   ├── mascotas.txt
│   ├── albergues.txt
│   └── actividad.txt
├── docs/diagramas/                                      # Diagramas Mermaid
│   ├── modulos.mmd                                      # Arquitectura Hexagonal
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
│   ├── aplicacion/                                      # CASOS DE USO Y PUERTOS
│   │   ├── puertos/
│   │   │   ├── entrada/                                 # Behaviours de casos de uso
│   │   │   └── salida/                                  # Behaviours: Repositorio, Bitacora, Reloj, GeneradorId
│   │   └── casos_uso/                                   # Orquestación de reglas puras y puertos
│   │       ├── gestionar_usuarios.ex, gestionar_zonas.ex, gestionar_necesidades.ex
│   │       ├── gestionar_recursos.ex, gestionar_familiares.ex, gestionar_mascotas.ex
│   │       └── gestionar_albergues.ex, generar_resumenes.ex
│   └── infraestructura/                                 # ADAPTADORES EXTERNOS
│       ├── salida/persistencia/                         # MotorPersistencia, AlmacenArchivo, CodificadorTexto
│       ├── procesos/                                    # Gestores GenServer y procesos puros con receive
│       └── entrada/consola/                             # Consola CLI, AnalizadorComandos, Presentador, Despachador
└── test/                                                # Suite completa de pruebas ExUnit
```

---

## 3. Instrucciones de Ejecución

### Requisitos Previos
- Elixir 1.14 o superior (probado en Elixir 1.20.4 con Erlang/OTP 29).

### 1. Compilación Estricta
Verifica que no exista ninguna advertencia en el código:
```bash
mix compile --warnings-as-errors
```

### 2. Ejecutar la Suite de Pruebas
Ejecuta las 58 pruebas automáticas (unitarias de dominio, casos de uso, persistencia, supervisión y concurrencia):
```bash
mix test
```

### 3. Ejecutar la Demostración Automatizada
Reproduce paso a paso el caso de estudio completo (Laura, Pedro, María, conflicto de recursos, albergues y mascotas):
```bash
mix run priv/demostracion.exs
```

### 4. Iniciar la Consola Interactiva
Inicia la consola interactiva a través del archivo `priv/main.exs`:
```bash
mix run priv/main.exs
```

---

## 4. Tabla de Comandos de la Consola

| Comando | Argumentos | Rol Mínimo | Descripción |
| :--- | :--- | :--- | :--- |
| `connect` | `<usuario> <clave> [rol]` | Cualquiera | Inicia sesión o auto-registra al usuario con clave cifrada SHA-256. |
| `disconnect` | *ninguno* | Autenticado | Cierra la sesión activa actual. |
| `register_zone` | `<nombre> <gravedad>` | Coordinador | Registra una nueva zona (`critico`, `alto`, `medio`, `bajo`). |
| `register_need` | `<zona> <recurso> <cantidad> <prioridad>` | Ciudadano | Reporta una necesidad humanitaria (`critica`, `alta`, `media`, `baja`). |
| `list_needs` | `[zona=Z] [prioridad=P] [estado=E]` | Ciudadano | Lista necesidades aplicando filtros opcionales. |
| `assign_resource` | `<id_recurso> <id_necesidad> <cant>` | Coordinador | Asigna recursos atómicamente a una necesidad. |
| `register_resource` | `<tipo> <unidad> <cantidad> <zona>` | Voluntario | Registra un lote de suministros en inventario. |
| `list_resources` | `[zona=Z] [tipo=T]` | Ciudadano | Consulta las existencias disponibles de suministros. |
| `transfer_resource` | `<id_origen> <id_destino> <cant>` | Coordinador | Transfiere stock entre recursos de distintas zonas de forma atómica. |
| `report_person` | `<documento> "<nombre_completo>"` | Ciudadano | Reporta a una persona damnificada o extraviada. |
| `find_person` | `<documento>` | Ciudadano | Consulta el estado y ubicación actual de una persona. |
| `send_family_message` | `<documento> "<mensaje>"` | Ciudadano | Envía un mensaje familiar asociado al documento. |
| `list_family_messages`| `<documento>` | Ciudadano | Lista los mensajes recibidos para un familiar. |
| `report_pet` | `<tipo> <esp> <col> <tam> <zona> [nom]`| Ciudadano | Reporta mascota (`perdida` o `encontrada`). |
| `match_pets` | `[umbral]` | Coordinador | Ejecuta algoritmo de similitud ponderada entre mascotas activas. |
| `register_shelter` | `<nombre> <zona> <capacidad>` | Coordinador | Registra un nuevo albergue con aforo máximo. |
| `check_shelter` | `<id_albergue>` | Ciudadano | Consulta ocupación en tiempo real y porcentaje de aforo. |
| `register_entry` | `<id_albergue> <documento>` | Voluntario | Registra ingreso de persona validando cupo máximo. |
| `register_exit` | `<id_albergue> <documento>` | Voluntario | Registra salida/egreso de una persona del albergue. |
| `summary` | *ninguno* | Coordinador | Presenta el consolidado ejecutivo global de la emergencia. |
| `critical_resources` | `[umbral]` | Coordinador | Lista suministros con existencias menores o iguales al umbral. |
| `pending_needs` | *ninguno* | Coordinador | Lista necesidades pendientes ordenadas por Merge Sort recursivo. |
| `help` | *ninguno* | Cualquiera | Muestra la ayuda de comandos interactiva. |
| `exit` | *ninguno* | Cualquiera | Sale de la sesión y finaliza la consola. |

---

## 5. Matriz de Control de Acceso (Permisos RBAC)

La matriz está implementada mediante `MapSet` en el módulo `Emergencias.Dominio.Reglas.Permisos` para garantizar consultas de autorización $O(1)$:

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

## 6. Justificación de Estructuras de Datos

1. **`Map`:** Utilizado en los GenServers (`GestorRecursos`, `GestorZonas`, `GestorUsuarios`, etc.) como índice por clave identificadora. Proporciona búsquedas y actualizaciones eficientes en tiempo $O(\log n)$ manteniendo inmutabilidad referencial.
2. **`List`:** Utilizado para representar secuencias ordenadas (resultado de Merge Sort) e historiales cronológicos de eventos inmutables donde se agregan nuevos eventos al inicio en tiempo $O(1)$.
3. **`Tupla`:** Empleada en los contratos de retorno (`{:ok, resultado}` / `{:error, razon}`) permitiendo pattern matching determinista sin incurrir en excepciones.
4. **`MapSet`:** Empleado en tres áreas críticas:
   - *Ocupantes de albergue:* Garantiza en $O(1)$ que una persona no ingrese por duplicado y permite calcular la ocupación exacta con `MapSet.size/1`.
   - *Permisos por rol:* Verifica en $O(1)$ la membresía de la operación dentro del conjunto permitido.
   - *Similitud de características:* Permite calcular la intersección y unión de palabras en el coeficiente Jaccard.
5. **`Structs` Anidados:** Permite modelar con tipado estricto la jerarquía `Zona -> [Sector] -> [PuntoAtencion]`, facilitando la navegación recursiva del árbol territorial.
6. **`Keyword List`:** Empleada para el paso de opciones configurables y filtros opcionales (`[zona: "Z001", prioridad: :critica]`), integrándose de forma idiomática con Elixir.

---

## 7. Funciones Recursivas Obligatorias

Todas las funciones recursivas fueron implementadas explícitamente sin recurrir a abstracciones como `Enum.reduce`:

### 1. `contar_puntos_atencion/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Contar el total de puntos de atención distribuidos a lo largo de todos los sectores de una zona.
- **Caso Base:** Lista vacía de sectores `[]` retorna el acumulador.
- **Caso Recursivo:** Para `[%Sector{puntos_atencion: puntos} | resto]`, cuenta recursivamente los elementos de la lista de puntos, los suma al acumulador y continúa con el resto de sectores mediante recursión de cola.

### 2. `sumar_personas_afectadas/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Acumular el número de personas afectadas en todos los puntos de atención de la jerarquía territorial.
- **Caso Base:** Lista vacía de sectores o puntos retorna el subtotal acumulado.
- **Caso Recursivo:** Suma las `personas_afectadas` del punto actual al acumulador y procesa la cola de puntos y sectores mediante recursión de cola.

### 3. `buscar_punto_atencion/2` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Búsqueda recursiva por código identificador dentro de la jerarquía anidada.
- **Caso Base 1:** Lista de sectores vacía retorna `{:error, :no_encontrado}`.
- **Caso Base 2:** Cabeza de lista de puntos con id coincidente retorna `{:ok, punto}`.
- **Caso Recursivo:** Si el punto no coincide, continúa con la cola de puntos; si el sector se agota, avanza recursivamente al siguiente sector.

### 4. `aplanar_jerarquia/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Convertir el árbol `Zona -> Sectores -> Puntos` en una lista plana de puntos de atención.
- **Caso Base:** Lista de sectores vacía retorna la lista acumulada invertida.
- **Caso Recursivo:** Extrae recursivamente los puntos del sector de la cabeza, los agrega al acumulador y avanza a los sectores restantes.

### 5. `sumar_cantidades/1` (`Emergencias.Dominio.Reglas.EstadisticasZona`)
- **Propósito:** Sumar las cantidades numéricas de una lista histórica de movimientos de inventario.
- **Caso Base:** Lista vacía de movimientos `[]` retorna el total acumulado.
- **Caso Recursivo:** `[%MovimientoInventario{cantidad: cant} | resto]` suma `cant` al acumulador y continúa procesando el resto de la lista con recursión de cola.

### 6. `ordenar_por_prioridad/1` (`Emergencias.Dominio.Reglas.Ordenamiento` - Merge Sort)
- **Propósito:** Ordenar necesidades humanitarias por prioridad descendente (`critica` > `alta` > `media` > `baja`) desempatando por fecha más antigua (ascendente).
- **Caso Base:** `[]` retorna `[]`; `[x]` retorna `[x]` (listas de tamaño 0 o 1 ya están ordenadas).
- **Caso Recursivo:** Divide la lista en dos mitades aproximadamente iguales mediante `dividir_lista/1`, ordena recursivamente cada mitad con `ordenar_merge_sort/2`, y las mezcla con `mezclar_listas/3` respetando el predicado de precedencia.

---

## 8. Concurrencia, Supervisión y Tolerancia a Fallos

### GenServers vs Procesos Puros con `receive`
El sistema combina ambos enfoques según la responsabilidad:
1. **GenServers serializadores:** (`GestorRecursos`, `GestorNecesidades`, etc.) Se encargan del estado compartido transaccional. En `GestorRecursos`, cada asignación o transferencia se ejecuta en un único `handle_call`, garantizando que la comprobación de existencia y el descuento ocurran de forma indivisible. Frente a peticiones simultáneas de 30L y 25L sobre 50L disponibles, la primera consume 30L (quedan 20L) y la segunda es rechazada atómicamente con `{:error, :cantidad_insuficiente}`.
2. **Procesos puros con bucle `receive`:**
   - `BitacoraActividad`: Proceso independiente no bloqueante que acumula eventos en cola y los remite a disco en segundo plano.
   - Procesos `Albergue`: Cada albergue activo corre como un proceso independiente supervisado bajo un `DynamicSupervisor` (`SupervisorAlbergues`) y registrado en un `Registry` único por código.

### Persistencia Transaccional
- Archivos en texto plano en la carpeta `datos/` con formato delimitado por `|`.
- El proceso `MotorPersistencia` es el único escritor autorizado sobre los archivos, serializando escrituras.
- Las escrituras completas se realizan mediante un archivo temporal auxiliar (`archivo.txt.tmp`) seguido de un renombrado atómico (`File.rename/2`), evitando la corrupción de datos ante caídas intempestivas del nodo.

### Tolerancia a Fallos
El árbol de supervisión principal (`SupervisorRaiz`) utiliza la estrategia `:one_for_one`. Si un gestor es terminado abruptamente (`Process.exit(pid, :kill)`), el supervisor lo reinicia automáticamente y su callback de inicialización recupera el estado íntegro directamente desde los archivos de texto plano.

---

## 9. Algoritmo de Similitud de Mascotas (`match_pets`)

El algoritmo evalúa reportes de tipo `:perdida` contra reportes de tipo `:encontrada` en estado `:activa`:
1. Si la especie difiere (ej. perro vs gato), el puntaje es 0 inmediatamente.
2. Si la especie coincide, se suma una escala ponderada de 100 puntos:
   - **Especie:** 25 puntos (obligatoria)
   - **Color:** 20 puntos (coincidencia textual normalizada)
   - **Tamaño:** 15 puntos (mismo tamaño)
   - **Zona:** 20 puntos (misma zona geográfica)
   - **Nombre:** 5 puntos (si ambos reportes lo conocen y coincide)
   - **Características:** 15 puntos (coeficiente Jaccard sobre conjuntos de palabras: $\frac{|\text{Intersección}|}{|\text{Unión}|} \times 15$)
3. Por defecto, parejas con puntaje $\ge 60$ se clasifican como `:posible_coincidencia` y se ordenan de mayor a menor puntuación.

---

## 10. Supuestos de Diseño

1. **Identificadores Normalizados:** Para facilitar la interacción humana, si el usuario escribe identificadores informales como `need001` o `n1`, el analizador léxico los normaliza a su representación canónica (`N001`).
2. **Autenticación sin Contraseñas en Texto Plano:** Las contraseñas se almacenan únicamente como hashes hexadecimales SHA-256 (`:crypto.hash(:sha256, clave)`).
3. **Persistencia Desacoplada en Pruebas:** Los casos de uso aceptan inyección de dependencias (`[repositorio: RepositorioMemoria]`), permitiendo ejecutar pruebas unitarias ultra rápidas en memoria sin tocar el disco.

---

## 11. Guion de Demostración Paso a Paso (Flujo de Laura)

Para reproducir manualmente en la consola (`mix run priv/main.exs`):

1. **Conexión de la Coordinadora:**
   ```text
   emergencias> connect Laura coord123 coordinador
   [OK] Bienvenido/a, Laura. Conectado con rol: coordinador.
   ```
2. **Registro de Zonas y Albergue:**
   ```text
   Laura [coordinador]> register_zone Centro critico
   [OK] Zona [Z001] 'Centro' registrada.
   Laura [coordinador]> register_zone Norte medio
   [OK] Zona [Z002] 'Norte' registrada.
   Laura [coordinador]> register_shelter "Estadio San Jose" Z001 2
   [OK] Albergue [ALB001] 'Estadio San Jose' registrado con capacidad 2.
   ```
3. **Ingreso de Recursos:**
   ```text
   Laura [coordinador]> register_resource agua litros 50 Z001
   [OK] Recurso [R001] agua (50 litros) ingresado a Z001.
   Laura [coordinador]> register_resource agua litros 20 Z002
   [OK] Recurso [R002] agua (20 litros) ingresado a Z002.
   ```
4. **Reporte de Necesidades:**
   ```text
   Laura [coordinador]> connect Pedro pass123 ciudadano
   Pedro [ciudadano]> register_need Z001 agua 30 critica
   [OK] Necesidad [N001] reportada con prioridad critica.
   Pedro [ciudadano]> connect Maria pass456 ciudadano
   Maria [ciudadano]> register_need Z001 agua 25 alta
   [OK] Necesidad [N002] reportada con prioridad alta.
   ```
5. **Conflicto Concurrente y Asignación Atómica:**
   ```text
   Maria [ciudadano]> connect Laura coord123 coordinador
   Laura [coordinador]> assign_resource R001 N001 30
   [OK] Asignados 30 litros de [R001] a [N001]. Stock restante: 20
   Laura [coordinador]> assign_resource R001 N002 25
   [ERROR] Existencias insuficientes en inventario para atender la solicitud.
   Laura [coordinador]> transfer_resource R002 R001 10
   [OK] Transferencia exitosa: 10 transferidos de [R002] a [R001].
   Laura [coordinador]> assign_resource R001 N002 25
   [OK] Asignados 25 litros de [R001] a [N002]. Stock restante: 5
   ```
6. **Familiares y Mensajería:**
   ```text
   Laura [coordinador]> connect Pedro pass123 ciudadano
   Pedro [ciudadano]> report_person 10949001 "Carlos Lopez"
   [OK] Persona [P001] Carlos Lopez (Doc: 10949001) reportada como reportada.
   Pedro [ciudadano]> connect Maria pass456 ciudadano
   Maria [ciudadano]> send_family_message 10949001 "Estamos todos bien en el refugio"
   [OK] Mensaje familiar [M001] registrado para documento 10949001.
   ```
7. **Control de Aforo en Albergues:**
   ```text
   Maria [ciudadano]> connect Laura coord123 coordinador
   Laura [coordinador]> register_entry ALB001 10949001
   [OK] Ingreso registrado: 10949001 alojado en albergue [ALB001].
   Laura [coordinador]> register_entry ALB001 10949002
   [OK] Ingreso registrado: 10949002 alojado en albergue [ALB001].
   Laura [coordinador]> register_entry ALB001 10949003
   [ERROR] El albergue ha alcanzado su capacidad máxima permitida.
   ```
8. **Mascotas y Similitud:**
   ```text
   Laura [coordinador]> report_pet perdida perro dorado mediano Z001 Rocky
   [OK] Mascota [MC001] reportada como perdida (perro dorado).
   Laura [coordinador]> report_pet encontrada perro dorado mediano Z001 Rocky
   [OK] Mascota [MC002] reportada como encontrada (perro dorado).
   Laura [coordinador]> match_pets 60
   COINCIDENCIAS IDENTIFICADAS:
     - Coincidencia [Puntaje: 85/100]:
         Perdida:    [MC001] perro dorado (mediano), Zona: Z001, Nombre: 'Rocky'
         Encontrada: [MC002] perro dorado (mediano), Zona: Z001, Nombre: 'Rocky'
   ```
9. **Resumen Ejecutivo y Suministros Críticos:**
   ```text
   Laura [coordinador]> summary
   Laura [coordinador]> critical_resources 15
   Laura [coordinador]> pending_needs
   Laura [coordinador]> exit
   ```

---

## 12. Checklist de Requisitos Cumplidos

- [x] **Convención de Nombres:** 100% funciones con verbos en infinitivo en español (`registrar/2`, `validar/1`, `asignar/3`, `poder_transitar?/2`, etc.). Callbacks OTP delegan de inmediato a funciones en infinitivo.
- [x] **Línea Única en Main:** `priv/main.exs` contiene exactamente 1 línea sin funciones ni lambdas.
- [x] **Arquitectura Hexagonal Estricta:** Dominio aislado de infraestructura y aplicación; dependencias hacia adentro.
- [x] **Funciones Puras:** Retornos canónicos `{:ok, _}` o `{:error, _}`; cero excepciones de negocio.
- [x] **Validación de Entradas:** Validación exhaustiva antes de alterar cualquier estado.
- [x] **Estructuras de Datos Justificadas:** `Map`, `List`, `Tupla`, `MapSet`, `Struct` anidados y `Keyword`.
- [x] **Recursividad Obligatoria:** 6 funciones recursivas implementadas sin `Enum.reduce` (casos base y recursivo documentados).
- [x] **Ordenamiento Propio:** Merge Sort recursivo para priorizar necesidades (`prioridad` desc, `fecha` asc).
- [x] **Similitud Ponderada de Mascotas:** Algoritmo ponderado de 0 a 100 con coeficiente Jaccard.
- [x] **Concurrencia OTP:** GenServers con buzón atómico resolviendo el conflicto 30L + 25L sobre 50L.
- [x] **Procesos Puros con `receive`:** `BitacoraActividad` y procesos `Albergue` con bucle recursivo.
- [x] **Supervisión Dinámica:** `SupervisorAlbergues` (`DynamicSupervisor`) y `Registry`.
- [x] **Persistencia en Texto Plano:** Archivos `.txt` con delimitador `|`, escape seguro y renombrado atómico.
- [x] **Pruebas Completas ExUnit:** 58 pruebas pasando en verde (incluyendo 100 tareas con `Task.async_stream`).
- [x] **Compilación Limpia:** `mix compile --warnings-as-errors` sin una sola advertencia.
- [x] **Diagramas Mermaid:** `modulos.mmd`, `modelo_datos.mmd`, `secuencia.mmd` y `arbol_otp.mmd`.
- [x] **Demostración Automatizada:** `priv/demostracion.exs` ejecutando el flujo completo de Laura.

