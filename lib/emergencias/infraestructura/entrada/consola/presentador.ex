defmodule Emergencias.Infraestructura.Entrada.Presentador do
  @moduledoc """
  Adaptador de presentación responsable de formatear tablas, mensajes y errores en español.
  Único componente que genera las cadenas de salida para la interfaz de consola.
  """

  alias Emergencias.Dominio.Modelos.{Albergue, Mensaje, Necesidad, Persona, Recurso, Zona}
  alias Emergencias.Dominio.Reglas.Ocupacion

  @doc """
  Generar mensaje de bienvenida con diseño ASCII didáctico.
  """
  @spec formatear_bienvenida() :: String.t()
  def formatear_bienvenida do
    """
    ================================================================================
           SISTEMA DISTRIBUIDO DE COORDINACIÓN Y GESTIÓN DE EMERGENCIAS
                        Universidad del Quindío - Programación III
    ================================================================================
    Escribe 'help' para ver los comandos disponibles o 'connect <usuario> <clave>'
    para iniciar sesión.
    """
  end

  @doc """
  Generar texto de ayuda detallando comandos y sintaxis.
  """
  @spec formatear_ayuda() :: String.t()
  def formatear_ayuda do
    """
    COMANDOS DISPONIBLES:
      connect <usuario> <clave> [rol]           : Iniciar sesión o registrar usuario
      disconnect                                : Cerrar la sesión activa
      register_zone <nombre> <gravedad>         : Registrar zona territorial (critico|alto|medio|bajo)
      register_need <zona> <recurso> <cantidad> <prioridad> : Reportar necesidad humanitaria
      list_needs [zona=Z] [prioridad=P] [estado=E] : Listar necesidades con filtros
      assign_resource <id_rec> <id_nec> <cant>  : Asignar suministros a una necesidad
      register_resource <tipo> <unidad> <cant> <zona> : Ingresar lote de recursos a inventario
      list_resources [zona=Z] [tipo=T]          : Consultar stock disponible de recursos
      transfer_resource <origen> <destino> <cant> : Transferir existencias entre zonas
      report_person <documento> "<nombre>"      : Reportar persona damnificada
      find_person <documento>                   : Localizar persona y consultar estado
      send_family_message <doc> "<mensaje>"     : Enviar mensaje a un familiar
      list_family_messages <doc>                : Listar mensajes de un familiar
      report_pet <perdida|encontrada> <esp> <col> <tam> <zona> [nom] : Reportar mascota
      match_pets [umbral]                       : Emparejar mascotas por similitud
      register_shelter <nombre> <zona> <cap>    : Registrar albergue temporal
      check_shelter <id_albergue>               : Consultar ocupación y cupos del albergue
      register_entry <id_albergue> <documento>  : Ingresar persona al albergue
      register_exit <id_albergue> <documento>   : Registrar salida de persona del albergue
      summary                                   : Ver consolidado ejecutivo del desastre
      critical_resources [umbral]               : Listar suministros en estado crítico
      pending_needs                             : Ver necesidades pendientes priorizadas
      help                                      : Mostrar esta lista de comandos
      exit                                      : Salir de la aplicación
    """
  end

  @doc """
  Formatear mensaje de confirmación exitosa.
  """
  @spec formatear_exito(String.t()) :: String.t()
  def formatear_exito(mensaje) do
    "[OK] #{mensaje}"
  end

  @doc """
  Formatear mensaje explicativo para errores de negocio y validación.
  """
  @spec formatear_error(atom() | String.t() | struct()) :: String.t()
  def formatear_error(:sin_permiso), do: "[ERROR] Permiso denegado: tu rol no tiene autorización para esta operación."
  def formatear_error(:no_autenticado), do: "[ERROR] Debes iniciar sesión con 'connect <usuario> <clave>' antes de continuar."
  def formatear_error(:clave_incorrecta), do: "[ERROR] Contraseña incorrecta para el usuario indicado."
  def formatear_error(:cantidad_insuficiente), do: "[ERROR] Existencias insuficientes en inventario para atender la solicitud."
  def formatear_error(:sin_cupo), do: "[ERROR] El albergue ha alcanzado su capacidad máxima permitida."
  def formatear_error(:persona_ya_alojada), do: "[ERROR] La persona indicada ya se encuentra registrada en este albergue."
  def formatear_error(:persona_no_encontrada), do: "[ERROR] No se encontró ningún registro para el documento suministrado."
  def formatear_error(:ya_cerrada), do: "[ERROR] No es posible modificar una entidad que ya se encuentra en estado terminal/cerrada."
  def formatear_error(:transicion_invalida), do: "[ERROR] Transición de estado no permitida según el flujo formal del sistema."
  def formatear_error(:necesidad_no_encontrada), do: "[ERROR] La necesidad indicada no existe en el sistema."
  def formatear_error(:necesidad_ya_cerrada), do: "[ERROR] La necesidad ya fue atendida o cerrada y no puede recibir más suministros."
  def formatear_error(:necesidad_ya_atendida), do: "[ERROR] La necesidad ya fue atendida en su totalidad y no puede recibir más suministros."
  def formatear_error(:necesidad_cancelada), do: "[ERROR] La necesidad se encuentra cancelada y no puede recibir suministros."
  def formatear_error(:cantidad_excede_necesidad), do: "[ERROR] La cantidad especificada supera el saldo pendiente de la necesidad."
  def formatear_error(:tipo_recurso_incompatible), do: "[ERROR] El tipo de recurso no coincide con el solicitado por la necesidad."
  def formatear_error(:recurso_no_encontrado), do: "[ERROR] El recurso especificado no existe en el inventario."
  def formatear_error(:recurso_origen_no_encontrado), do: "[ERROR] El recurso o centro de origen no existe."
  def formatear_error(:recurso_destino_no_encontrado), do: "[ERROR] El recurso o centro de destino no existe."
  def formatear_error(:cantidad_invalida), do: "[ERROR] La cantidad debe ser un número entero estrictamente positivo (> 0)."
  def formatear_error(:entero_invalido), do: "[ERROR] El valor suministrado debe ser un número entero válido."
  def formatear_error(:nivel_invalido), do: "[ERROR] Nivel de gravedad inválido. Valores permitidos: critico, alto, medio, bajo."
  def formatear_error(:prioridad_invalida), do: "[ERROR] Prioridad inválida. Valores permitidos: critica, alta, media, baja."
  def formatear_error(:rol_invalido), do: "[ERROR] Rol inválido. Valores permitidos: ciudadano, voluntario, coordinador, administrador."
  def formatear_error(:tamano_invalido), do: "[ERROR] Tamaño de mascota inválido. Valores permitidos: pequeno, mediano, grande."
  def formatear_error(:tipo_reporte_invalido), do: "[ERROR] Tipo de reporte inválido. Valores permitidos: perdida, encontrada."
  def formatear_error(:albergue_no_encontrado), do: "[ERROR] El albergue indicado no existe en el sistema."
  def formatear_error(:zona_no_encontrada), do: "[ERROR] La zona indicada no existe en el sistema."
  def formatear_error(:comando_desconocido), do: "[ERROR] Comando no reconocido. Escribe 'help' para consultar la ayuda."
  def formatear_error(:argumentos_invalidos), do: "[ERROR] Sintaxis o cantidad de argumentos incorrecta para este comando."
  def formatear_error(:linea_vacia), do: ""
  def formatear_error(%{__struct__: _} = err), do: "[ERROR] Error de ejecución: #{Exception.message(err)}"
  def formatear_error(otro), do: "[ERROR] Ocurrió un error en la operación: #{inspect(otro)}"

  @doc """
  Formatear el resumen ejecutivo del sistema.
  """
  @spec formatear_resumen(map()) :: String.t()
  def formatear_resumen(datos) do
    """
    +-------------------------------------------------------------+
    |                     RESUMEN EJECUTIVO                       |
    +-------------------------------------------------------------+
      Total Recursos Disponibles:   #{datos.total_recursos_disponibles}
      Necesidades Pendientes:       #{datos.necesidades_pendientes}
      Personas Localizadas:         #{datos.personas_localizadas} / #{datos.total_personas_reportadas}
      Personas en Albergues:        #{datos.personas_en_albergues}
      Mensajes Familiares Enviados: #{datos.total_mensajes_enviados}
      Mascotas Activas / Resueltas: #{datos.mascotas_activas} / #{datos.mascotas_resueltas}
    +-------------------------------------------------------------+
    """
  end

  @doc """
  Formatear lista de necesidades en tabla visual.
  """
  @spec formatear_necesidades(list(Necesidad.t())) :: String.t()
  def formatear_necesidades([]) do
    "No se encontraron necesidades registradas con los criterios dados."
  end

  def formatear_necesidades(necesidades) do
    encabezado = "ID    | ZONA  | RECURSO       | CANT SOL | ASIGNADA | PRIORIDAD | ESTADO\n" <>
                 "------+-------+---------------+----------+----------+-----------+-------------"

    filas =
      Enum.map(necesidades, fn n ->
        id = String.pad_trailing(n.id, 5)
        zona = String.pad_trailing(n.codigo_zona, 5)
        rec = String.pad_trailing(String.slice(n.tipo_recurso, 0, 13), 13)
        sol = String.pad_leading(to_string(n.cantidad_solicitada), 8)
        asig = String.pad_leading(to_string(n.cantidad_asignada), 8)
        prio = String.pad_trailing(to_string(n.prioridad), 9)
        est = to_string(n.estado)
        "#{id} | #{zona} | #{rec} | #{sol} | #{asig} | #{prio} | #{est}"
      end)

    Enum.join([encabezado | filas], "\n")
  end

  @doc """
  Formatear lista de recursos disponibles en inventario.
  """
  @spec formatear_recursos(list(Recurso.t())) :: String.t()
  def formatear_recursos([]) do
    "No hay recursos registrados en el inventario."
  end

  def formatear_recursos(recursos) do
    encabezado = "ID    | TIPO          | TOTAL | DISP | RESERV | ZONA  | UNIDAD\n" <>
                 "------+---------------+-------+------+--------+-------+-------------"

    filas =
      Enum.map(recursos, fn r ->
        id = String.pad_trailing(r.id, 5)
        tipo = String.pad_trailing(String.slice(r.tipo, 0, 13), 13)
        tot = String.pad_leading(to_string(r.cantidad_total), 5)
        disp = String.pad_leading(to_string(r.cantidad_disponible), 4)
        res = String.pad_leading(to_string(r.cantidad_reservada), 6)
        zona = String.pad_trailing(r.codigo_zona, 5)
        "#{id} | #{tipo} | #{tot} | #{disp} | #{res} | #{zona} | #{r.unidad_medida}"
      end)

    Enum.join([encabezado | filas], "\n")
  end

  @doc """
  Formatear datos de albergue, su tasa de ocupación, recursos asignados y necesidades asociadas.
  """
  @spec formatear_albergue(Albergue.t()) :: String.t()
  def formatear_albergue(%Albergue{} = a) do
    ocupados = MapSet.size(a.personas_alojadas)
    porcentaje = Ocupacion.calcular_porcentaje_ocupacion(a)
    recursos_str =
      if map_size(a.recursos_asignados) == 0 do
        "Ninguno"
      else
        a.recursos_asignados
        |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
        |> Enum.join(", ")
      end

    necesidades_str =
      if Enum.empty?(a.necesidades_asociadas) do
        "Ninguna"
      else
        Enum.join(a.necesidades_asociadas, ", ")
      end

    """
    Albergue:     [#{a.id}] #{a.nombre}
    Zona:         #{a.codigo_zona}
    Capacidad:    #{ocupados} / #{a.capacidad_maxima} personas (#{porcentaje}%)
    Ocupantes:    #{if ocupados == 0, do: "Ninguno", else: a.personas_alojadas |> Enum.join(", ")}
    Recursos:     #{recursos_str}
    Necesidades:  #{necesidades_str}
    """
  end

  @doc """
  Formatear lista de coincidencias de mascotas por similitud.
  """
  @spec formatear_coincidencias_mascotas(list({struct(), struct(), non_neg_integer()})) :: String.t()
  def formatear_coincidencias_mascotas([]) do
    "No se encontraron posibles coincidencias de mascotas sobre el umbral requerido."
  end

  def formatear_coincidencias_mascotas(coincidencias) do
    filas =
      Enum.map(coincidencias, fn {p, e, puntaje} ->
        "  - Coincidencia [Puntaje: #{puntaje}/100]:\n" <>
        "      Perdida:    [#{p.id}] #{p.especie} #{p.color} (#{p.tamano}), Zona: #{p.codigo_zona}, Nombre: '#{p.nombre}'\n" <>
        "      Encontrada: [#{e.id}] #{e.especie} #{e.color} (#{e.tamano}), Zona: #{e.codigo_zona}, Nombre: '#{e.nombre}'"
      end)

    "COINCIDENCIAS IDENTIFICADAS:\n" <> Enum.join(filas, "\n\n")
  end

  @doc """
  Formatear los datos de una persona y su historial.
  """
  @spec formatear_persona(Persona.t()) :: String.t()
  def formatear_persona(%Persona{} = p) do
    """
    Persona:    [#{p.id}] #{p.nombre_completo} (Doc: #{p.documento})
    Estado:     #{p.estado}
    Ubicación:  #{p.ubicacion_actual}
    Albergue:   #{p.codigo_albergue || "Ninguno"}
    Reporte:    #{p.fecha_reporte}
    """
  end

  @doc """
  Formatear lista de mensajes de familiares.
  """
  @spec formatear_mensajes(list(Mensaje.t())) :: String.t()
  def formatear_mensajes([]) do
    "No hay mensajes registrados para este documento."
  end

  def formatear_mensajes(mensajes) do
    filas =
      Enum.map(mensajes, fn m ->
        "  [#{m.fecha_envio}] De: #{m.remitente} -> #{m.contenido}"
      end)

    "MENSAJES FAMILIARES:\n" <> Enum.join(filas, "\n")
  end

  @doc """
  Formatear detalles de una zona territorial.
  """
  @spec formatear_zona(Zona.t()) :: String.t()
  def formatear_zona(%Zona{} = z) do
    """
    Zona:     [#{z.id}] #{z.nombre}
    Gravedad: #{z.nivel_gravedad}
    Sectores: #{length(z.sectores)}
    """
  end
end
