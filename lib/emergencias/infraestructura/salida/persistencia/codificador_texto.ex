defmodule Emergencias.Infraestructura.Salida.Persistencia.CodificadorTexto do
  @moduledoc """
  Serializador y deserializador seguro entre structs del dominio y líneas de texto plano.
  Utiliza '|' como delimitador de campos con soporte para secuencias de escape.
  """

  alias Emergencias.Dominio.Modelos.{
    Albergue,
    Mensaje,
    MovimientoInventario,
    Necesidad,
    Persona,
    PuntoAtencion,
    Recurso,
    RegistroActividad,
    ReporteMascota,
    Sector,
    Usuario,
    Zona
  }

  @doc """
  Codificar un struct de dominio en una cadena de texto para almacenamiento en archivo.
  """
  @spec codificar(struct()) :: {:ok, String.t()} | {:error, :tipo_desconocido}
  def codificar(%Usuario{} = u) do
    campos = [u.id, u.nombre, to_string(u.rol), u.clave_hash, u.fecha_registro]
    {:ok, unir_campos(campos)}
  end

  def codificar(%Zona{} = z) do
    sectores_str = codificar_sectores(z.sectores)
    campos = [z.id, z.nombre, to_string(z.nivel_gravedad), z.fecha_registro, sectores_str]
    {:ok, unir_campos(campos)}
  end

  def codificar(%Necesidad{} = n) do
    hist_str = codificar_historial_eventos(n.historial)

    campos = [
      n.id,
      n.codigo_zona,
      n.tipo_recurso,
      to_string(n.cantidad_solicitada),
      to_string(n.cantidad_asignada),
      to_string(n.prioridad),
      to_string(n.estado),
      n.fecha_registro,
      n.usuario_reporta,
      hist_str
    ]

    {:ok, unir_campos(campos)}
  end

  def codificar(%Recurso{} = r) do
    campos = [
      r.id,
      r.tipo,
      r.unidad_medida,
      to_string(r.cantidad_total),
      to_string(r.cantidad_disponible),
      to_string(r.cantidad_reservada),
      r.codigo_zona,
      r.fecha_registro
    ]

    {:ok, unir_campos(campos)}
  end

  def codificar(%MovimientoInventario{} = m) do
    campos = [
      m.id,
      m.codigo_recurso,
      to_string(m.tipo_movimiento),
      to_string(m.cantidad),
      m.origen,
      m.destino,
      m.fecha,
      m.usuario_responsable
    ]

    {:ok, unir_campos(campos)}
  end

  def codificar(%Persona{} = p) do
    hist_str = codificar_historial_eventos(p.historial)

    campos = [
      p.id,
      p.documento,
      p.nombre_completo,
      to_string(p.estado),
      p.ubicacion_actual,
      to_string(p.codigo_albergue || ""),
      p.fecha_reporte,
      hist_str
    ]

    {:ok, unir_campos(campos)}
  end

  def codificar(%Mensaje{} = m) do
    campos = [m.id, m.documento_persona, m.remitente, m.contenido, m.fecha_envio]
    {:ok, unir_campos(campos)}
  end

  def codificar(%ReporteMascota{} = rm) do
    caract_str = Enum.join(rm.caracteristicas, ";")
    hist_str = codificar_historial_eventos(rm.historial)

    campos = [
      rm.id,
      to_string(rm.tipo_reporte),
      rm.especie,
      rm.nombre || "",
      rm.color,
      to_string(rm.tamano),
      rm.codigo_zona,
      caract_str,
      to_string(rm.estado),
      rm.usuario_reporta,
      rm.fecha_registro,
      hist_str
    ]

    {:ok, unir_campos(campos)}
  end

  def codificar(%Albergue{} = a) do
    ocupantes_str = a.personas_alojadas |> MapSet.to_list() |> Enum.join(";")
    campos = [a.id, a.nombre, a.codigo_zona, to_string(a.capacidad_maxima), a.fecha_registro, ocupantes_str]
    {:ok, unir_campos(campos)}
  end

  def codificar(%RegistroActividad{} = act) do
    campos = [act.id, act.usuario, act.accion, act.detalles, act.fecha]
    {:ok, unir_campos(campos)}
  end

  def codificar(_), do: {:error, :tipo_desconocido}

  @doc """
  Decodificar una línea de texto plano en un struct del tipo de entidad especificado.
  """
  @spec decodificar(String.t(), atom()) :: {:ok, struct()} | {:error, atom()}
  def decodificar(linea, :usuarios) do
    case separar_campos(linea) do
      [id, nom, rol_str, hash, fecha] ->
        Usuario.construir(%{
          id: id,
          nombre: nom,
          rol: convertir_rol(rol_str),
          clave_hash: hash,
          fecha_registro: fecha
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :zonas) do
    case separar_campos(linea) do
      [id, nom, grav_str, fecha, sectores_str] ->
        sectores = decodificar_sectores(sectores_str)

        Zona.construir(%{
          id: id,
          nombre: nom,
          nivel_gravedad: convertir_gravedad(grav_str),
          fecha_registro: fecha,
          sectores: sectores
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :necesidades) do
    case separar_campos(linea) do
      [id, zona, rec, cant_sol, cant_asig, prior, est, fecha, user, hist_str] ->
        hist = decodificar_historial_eventos(hist_str)

        Necesidad.construir(%{
          id: id,
          codigo_zona: zona,
          tipo_recurso: rec,
          cantidad_solicitada: String.to_integer(cant_sol),
          cantidad_asignada: String.to_integer(cant_asig),
          prioridad: convertir_prioridad(prior),
          estado: convertir_estado_necesidad(est),
          fecha_registro: fecha,
          usuario_reporta: user,
          historial: hist
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :recursos) do
    case separar_campos(linea) do
      [id, tipo, unidad, total, disp, res, zona, fecha] ->
        Recurso.construir(%{
          id: id,
          tipo: tipo,
          unidad_medida: unidad,
          cantidad_total: String.to_integer(total),
          cantidad_disponible: String.to_integer(disp),
          cantidad_reservada: String.to_integer(res),
          codigo_zona: zona,
          fecha_registro: fecha
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :movimientos) do
    case separar_campos(linea) do
      [id, rec, tipo_mov, cant, orig, dest, fecha, user] ->
        MovimientoInventario.construir(%{
          id: id,
          codigo_recurso: rec,
          tipo_movimiento: convertir_tipo_movimiento(tipo_mov),
          cantidad: String.to_integer(cant),
          origen: orig,
          destino: dest,
          fecha: fecha,
          usuario_responsable: user
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :personas) do
    case separar_campos(linea) do
      [id, doc, nom, est, ubic, alb, fecha, hist_str] ->
        hist = decodificar_historial_eventos(hist_str)
        codigo_alb = if alb == "", do: nil, else: alb

        Persona.construir(%{
          id: id,
          documento: doc,
          nombre_completo: nom,
          estado: convertir_estado_persona(est),
          ubicacion_actual: ubic,
          codigo_albergue: codigo_alb,
          fecha_reporte: fecha,
          historial: hist
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :mensajes) do
    case separar_campos(linea) do
      [id, doc, remit, cont, fecha] ->
        Mensaje.construir(%{
          id: id,
          documento_persona: doc,
          remitente: remit,
          contenido: cont,
          fecha_envio: fecha
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :mascotas) do
    case separar_campos(linea) do
      [id, tipo, esp, nom, col, tam, zona, caract_str, est, user, fecha, hist_str] ->
        caract = if caract_str == "", do: [], else: String.split(caract_str, ";")
        hist = decodificar_historial_eventos(hist_str)

        ReporteMascota.construir(%{
          id: id,
          tipo_reporte: convertir_tipo_mascota(tipo),
          especie: esp,
          nombre: nom,
          color: col,
          tamano: convertir_tamano_mascota(tam),
          codigo_zona: zona,
          caracteristicas: caract,
          estado: convertir_estado_mascota(est),
          usuario_reporta: user,
          fecha_registro: fecha,
          historial: hist
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :albergues) do
    case separar_campos(linea) do
      [id, nom, zona, cap, fecha, ocupantes_str] ->
        ocupantes =
          if ocupantes_str == "" do
            MapSet.new()
          else
            ocupantes_str |> String.split(";") |> MapSet.new()
          end

        Albergue.construir(%{
          id: id,
          nombre: nom,
          codigo_zona: zona,
          capacidad_maxima: String.to_integer(cap),
          fecha_registro: fecha,
          personas_alojadas: ocupantes
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(linea, :actividad) do
    case separar_campos(linea) do
      [id, user, acc, det, fecha] ->
        RegistroActividad.construir(%{
          id: id,
          usuario: user,
          accion: acc,
          detalles: det,
          fecha: fecha
        })

      _ ->
        {:error, :formato_invalido}
    end
  end

  def decodificar(_, _), do: {:error, :entidad_desconocida}

  # Conversiones seguras de cadenas a átomos
  defp convertir_rol("administrador"), do: :administrador
  defp convertir_rol("coordinador"), do: :coordinador
  defp convertir_rol("voluntario"), do: :voluntario
  defp convertir_rol(_), do: :ciudadano

  defp convertir_gravedad("critico"), do: :critico
  defp convertir_gravedad("alto"), do: :alto
  defp convertir_gravedad("medio"), do: :medio
  defp convertir_gravedad(_), do: :bajo

  defp convertir_prioridad("critica"), do: :critica
  defp convertir_prioridad("alta"), do: :alta
  defp convertir_prioridad("media"), do: :media
  defp convertir_prioridad(_), do: :baja

  defp convertir_estado_necesidad("asignada"), do: :asignada
  defp convertir_estado_necesidad("en_atencion"), do: :en_atencion
  defp convertir_estado_necesidad("atendida"), do: :atendida
  defp convertir_estado_necesidad("cancelada"), do: :cancelada
  defp convertir_estado_necesidad(_), do: :pendiente

  defp convertir_tipo_movimiento("salida"), do: :salida
  defp convertir_tipo_movimiento("asignacion"), do: :asignacion
  defp convertir_tipo_movimiento("transferencia_origen"), do: :transferencia_origen
  defp convertir_tipo_movimiento("transferencia_destino"), do: :transferencia_destino
  defp convertir_tipo_movimiento(_), do: :entrada

  defp convertir_estado_persona("reportada"), do: :reportada
  defp convertir_estado_persona("localizada"), do: :localizada
  defp convertir_estado_persona("trasladada"), do: :trasladada
  defp convertir_estado_persona("en_albergue"), do: :en_albergue
  defp convertir_estado_persona("reunificada"), do: :reunificada
  defp convertir_estado_persona(_), do: :sin_informacion

  defp convertir_tipo_mascota("encontrada"), do: :encontrada
  defp convertir_tipo_mascota(_), do: :perdida

  defp convertir_tamano_mascota("pequeno"), do: :pequeno
  defp convertir_tamano_mascota("grande"), do: :grande
  defp convertir_tamano_mascota(_), do: :mediano

  defp convertir_estado_mascota("posible_coincidencia"), do: :posible_coincidencia
  defp convertir_estado_mascota("resuelta"), do: :resuelta
  defp convertir_estado_mascota(_), do: :activa

  # Funciones privadas para escape y unión de campos
  defp unir_campos(campos) do
    campos
    |> Enum.map(&escapar_campo/1)
    |> Enum.join("|")
  end

  defp separar_campos(linea) do
    linea
    |> String.trim()
    |> desglosar_con_escape()
  end

  defp escapar_campo(nil), do: ""

  defp escapar_campo(texto) when is_binary(texto) do
    texto
    |> String.replace("\\", "\\\\")
    |> String.replace("|", "\\|")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "")
  end

  defp escapar_campo(otro), do: escapar_campo(to_string(otro))

  defp desglosar_con_escape(linea) do
    linea
    |> String.split(~r/(?<!\\)\|/)
    |> Enum.map(&desescapar_campo/1)
  end

  defp desescapar_campo(texto) do
    texto
    |> String.replace("\\|", "|")
    |> String.replace("\\n", "\n")
    |> String.replace("\\\\", "\\")
  end

  defp codificar_sectores(sectores) when is_list(sectores) do
    sectores
    |> Enum.map(fn %Sector{id: s_id, nombre: s_nom, puntos_atencion: puntos} ->
      puntos_str =
        puntos
        |> Enum.map(fn %PuntoAtencion{id: pid, nombre: pnom, personas_afectadas: af} ->
          "#{pid}:#{pnom}:#{af}"
        end)
        |> Enum.join(",")

      "#{s_id}:#{s_nom}:[#{puntos_str}]"
    end)
    |> Enum.join("~")
  end

  defp decodificar_sectores(""), do: []

  defp decodificar_sectores(cadena) do
    cadena
    |> String.split("~", trim: true)
    |> Enum.map(fn sector_str ->
      case String.split(sector_str, ":[") do
        [encabezado, puntos_encapsulados] ->
          [s_id, s_nom] = String.split(encabezado, ":")
          puntos_str = String.trim_trailing(puntos_encapsulados, "]")
          puntos = decodificar_puntos(puntos_str)
          {:ok, s} = Sector.construir(%{id: s_id, nombre: s_nom, puntos_atencion: puntos})
          s

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp decodificar_puntos(""), do: []

  defp decodificar_puntos(cadena) do
    cadena
    |> String.split(",", trim: true)
    |> Enum.map(fn punto_str ->
      case String.split(punto_str, ":") do
        [pid, pnom, af_str] ->
          {:ok, p} =
            PuntoAtencion.construir(%{
              id: pid,
              nombre: pnom,
              personas_afectadas: String.to_integer(af_str)
            })

          p

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp codificar_historial_eventos(historial) when is_list(historial) do
    historial
    |> Enum.map(fn ev ->
      "#{ev[:fecha] || ev.fecha}~#{ev[:estado_anterior] || ev.estado_anterior}~#{ev[:estado_nuevo] || ev.estado_nuevo}~#{ev[:usuario] || ev.usuario}"
    end)
    |> Enum.join(";;")
  end

  defp decodificar_historial_eventos(""), do: []

  defp decodificar_historial_eventos(cadena) do
    cadena
    |> String.split(";;", trim: true)
    |> Enum.map(fn item ->
      case String.split(item, "~") do
        [fecha, ant, nuevo, user] ->
          %{
            fecha: fecha,
            estado_anterior: convertir_estado_necesidad(ant),
            estado_nuevo: convertir_estado_necesidad(nuevo),
            usuario: user
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
