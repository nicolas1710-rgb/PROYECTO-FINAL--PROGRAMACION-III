defmodule Emergencias.Infraestructura.Entrada.Consola.Despachador do
  @moduledoc "Despachador conciso que delega comandos CLI hacia los casos de uso."

  alias Emergencias.Aplicacion.CasosUso.{GenerarResumenes, GestionarAlbergues, GestionarFamiliares, GestionarLogistica, GestionarMascotas, GestionarUsuarios, GestionarZonas}
  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Infraestructura.Entrada.Consola.Presentador

  def despachar(:exit, _args, _kw, _u), do: {:salir, "Cerrando sesion. Hasta luego."}
  def despachar(:help, _args, _kw, u), do: {:ok, mostrar_ayuda(), u}
  def despachar(:connect, [nom, clave | r], _kw, _u) do
    case GestionarUsuarios.conectar(nom, clave, hd(r ++ ["ciudadano"])) do
      {:ok, usr} -> {:ok, Presentador.formatear_exito("Conectado como #{usr.nombre} (#{usr.rol})."), usr}
      {:error, r} -> {:error, Presentador.formatear_error(r), nil}
    end
  end
  def despachar(:disconnect, _args, _kw, %Usuario{} = u) do
    _ = GestionarUsuarios.desconectar(u)
    {:ok, Presentador.formatear_exito("Sesion cerrada."), nil}
  end
  def despachar(_cmd, _args, _kw, nil), do: {:error, Presentador.formatear_error(:no_autenticado), nil}

  def despachar(:register_zone, [c, n, g | rest], kw, u), do: dar_exito(GestionarZonas.registrar_zona(c, n, g, kw[:personas] || hd(rest ++ [0]), u), u, &"Zona [#{&1.id}] registrada.")
  def despachar(:register_sector, [z, c, n, p], _kw, u), do: dar_exito(GestionarZonas.registrar_sector(z, c, n, p, u), u, &"Sector [#{&1.id}] registrado.")
  def despachar(:register_point, [z, s, c, n, p], _kw, u), do: dar_exito(GestionarZonas.registrar_punto(z, s, c, n, p, u), u, &"Punto [#{&1.id}] registrado.")
  def despachar(:list_zones, _a, _kw, u), do: dar_formato(GestionarZonas.listar_zonas(u), u, &Presentador.formatear_tabla(&1, [{"CODIGO", :id, 8}, {"NOMBRE", :nombre, 18}, {"GRAVEDAD", :nivel_gravedad, 10}, {"PERSONAS", :personas_afectadas, 8}]))
  def despachar(:zone_status, [z], _kw, u), do: dar_formato(GestionarZonas.consultar_estado_zona(z, u), u, &"Zona: #{&1.zona.nombre} (#{z})\nSectores: #{&1.total_sectores}\nPuntos Atencion: #{&1.total_puntos}\nTotal Personas Afectadas: #{&1.total_personas}")

  def despachar(:register_resource, [c, n, k, m, ub | _], kw, u), do: dar_exito(GestionarLogistica.registrar_recurso(c, n, k, m, ub, kw[:categoria], u), u, &"Recurso [#{&1.id}] '#{&1.nombre}' ingresado (#{k} #{m}).")
  def despachar(:list_resources, _a, kw, u), do: dar_formato(GestionarLogistica.listar_recursos(kw, u), u, &Presentador.formatear_tabla(&1, [{"CODIGO", :id, 8}, {"NOMBRE", :nombre, 14}, {"DISP", :cantidad_disponible, 6}, {"TOTAL", :cantidad_total, 6}, {"UNIDAD", :unidad_medida, 8}, {"UBICACION", :ubicacion, 10}]))
  def despachar(:transfer_resource, [c, o, d, k], _kw, u), do: dar_exito(GestionarLogistica.transferir_recurso(c, o, d, k, u), u, fn {orig, dest} -> "Transferencia exitosa: #{k} de [#{orig.id}] (#{orig.ubicacion}) a [#{dest.id}] (#{dest.ubicacion})." end)

  def despachar(:register_need, [z, r, k, p | desc], _kw, u), do: dar_exito(GestionarLogistica.registrar_necesidad(z, r, k, p, Enum.join(desc, " "), u), u, &"Necesidad [#{&1.id}] reportada para #{z}.")
  def despachar(:list_needs, _a, kw, u), do: dar_formato(GestionarLogistica.listar_necesidades(kw, u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 6}, {"ZONA", :codigo_zona, 6}, {"RECURSO", :tipo_recurso, 12}, {"SOLIC", :cantidad_solicitada, 6}, {"ASIG", :cantidad_asignada, 6}, {"PRIO", :prioridad, 8}, {"ESTADO", :estado, 10}]))
  def despachar(:assign_resource, [r, n, k], _kw, u), do: dar_exito(GestionarLogistica.asignar_recurso(r, n, k, u), u, fn {rec, nec, _} -> "Asignados #{k} de [#{rec.id}] a [#{nec.id}]. Stock restante: #{rec.cantidad_disponible}." end)

  def despachar(:report_person, [d, n, e, z | est], _kw, u), do: dar_exito(GestionarFamiliares.reportar_persona(d, n, e, z, hd(est ++ ["reportada"]), u), u, &"Persona #{&1.nombre} (#{d}) reportada.")
  def despachar(:find_person, args, kw, u) do
    dar_formato(GestionarFamiliares.buscar_persona(if(args != [], do: hd(args), else: kw), u), u, fn
      %{} = p -> "Persona: #{p.nombre} (Doc: #{p.documento})\nEdad: #{p.edad}\nZona: #{p.zona}\nEstado: #{p.estado}\nAlbergue: #{p.codigo_albergue || "Ninguno"}"
      list when is_list(list) -> Presentador.formatear_tabla(list, [{"DOC", :documento, 10}, {"NOMBRE", :nombre, 18}, {"ZONA", :zona, 8}, {"ESTADO", :estado, 10}])
    end)
  end
  def despachar(:update_person, [d, e], _kw, u), do: dar_exito(GestionarFamiliares.actualizar_persona(d, e, u), u, &"Persona #{d} actualizada a #{&1.estado}.")
  def despachar(:send_family_message, [d | c], _kw, u), do: dar_exito(GestionarFamiliares.enviar_mensaje(d, u.nombre, Enum.join(c, " "), u), u, &"Mensaje [#{&1.id}] enviado a #{d}.")
  def despachar(:list_family_messages, [d], _kw, u), do: dar_formato(GestionarFamiliares.listar_mensajes(d, u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 6}, {"DE", :remitente, 12}, {"MENSAJE", :contenido, 30}, {"FECHA", :fecha, 20}]))

  def despachar(:report_pet, [t, e, c, tam, z | n], _kw, u), do: dar_exito(GestionarMascotas.reportar_mascota(t, e, c, tam, z, hd(n ++ [""]), [], u), u, &"Mascota [#{&1.id}] #{t} reportada.")
  def despachar(:list_pets, _a, kw, u), do: dar_formato(GestionarMascotas.listar_mascotas(kw, u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 6}, {"TIPO", :tipo_reporte, 10}, {"ESPECIE", :especie, 8}, {"COLOR", :color, 8}, {"ZONA", :codigo_zona, 6}, {"ESTADO", :estado, 10}]))
  def despachar(:match_pets, args, _kw, u) do
    dar_formato(GestionarMascotas.emparejar_mascotas(hd(args ++ ["60"]), u), u, fn pares ->
      lineas = Enum.map_join(pares, "\n", &"Coincidencia (#{(&1).puntaje}%): Perdida [#{(&1).perdida.id}] #{(&1).perdida.especie} (#{(&1).perdida.nombre}) vs Encontrada [#{(&1).encontrada.id}] (#{(&1).encontrada.nombre})")
      if lineas != "", do: lineas, else: "No hay coincidencias sobre el umbral."
    end)
  end
  def despachar(:confirm_match, [p, e], _kw, u), do: dar_exito(GestionarMascotas.confirmar_coincidencia(p, e, u), u, fn _ -> "Coincidencia confirmada. Reportes [#{p}] y [#{e}] resueltos." end)

  def despachar(:register_shelter, [n, z, c], _kw, u), do: dar_exito(GestionarAlbergues.registrar_albergue(n, z, c, u), u, &"Albergue [#{&1.id}] registrado con capacidad #{&1.capacidad_maxima}.")
  def despachar(:check_shelter, [id], _kw, u), do: dar_formato(GestionarAlbergues.consultar_albergue(id, u), u, &"Albergue [#{&1.id}] #{&1.nombre}\nZona: #{&1.codigo_zona}\nOcupacion: #{MapSet.size(&1.personas_alojadas)}/#{&1.capacidad_maxima}\nPersonas: #{Enum.join(&1.personas_alojadas, ", ")}\nRecursos: #{inspect(&1.recursos_asignados)}\nNecesidades: #{inspect(&1.necesidades_asociadas)}")
  def despachar(:register_entry, [id, d], _kw, u), do: dar_exito(GestionarAlbergues.registrar_entrada(id, d, u), u, fn a -> "Ingreso registrado: #{d} alojado en [#{a.id}]." end)
  def despachar(:register_exit, [id, d], _kw, u), do: dar_exito(GestionarAlbergues.registrar_salida(id, d, u), u, fn a -> "Salida registrada: #{d} egreso de [#{a.id}]." end)
  def despachar(:link_shelter_resource, [id, r], _kw, u), do: dar_exito(GestionarAlbergues.vincular_recurso(id, r, u), u, fn _ -> "Recurso #{r} vinculado al albergue #{id}." end)
  def despachar(:link_shelter_need, [id, n], _kw, u), do: dar_exito(GestionarAlbergues.vincular_necesidad(id, n, u), u, fn _ -> "Necesidad #{n} vinculada al albergue #{id}." end)
  def despachar(:list_shelters, _a, _kw, u), do: dar_formato(GestionarAlbergues.listar_albergues(u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 8}, {"NOMBRE", :nombre, 18}, {"ZONA", :codigo_zona, 6}, {"OCUPADOS", fn a -> MapSet.size(a.personas_alojadas) end, 8}, {"CAPACIDAD", :capacidad_maxima, 8}]))
  def despachar(:shelter_report, _a, _kw, u), do: dar_formato(GestionarAlbergues.generar_reporte_albergues(u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 8}, {"NOMBRE", :nombre, 18}, {"ZONA", :codigo_zona, 6}, {"OCUPACION", fn a -> "#{Float.round(MapSet.size(a.personas_alojadas) * 100 / max(a.capacidad_maxima, 1), 1)}%" end, 10}]))

  def despachar(:summary, _a, _kw, u), do: dar_formato(GenerarResumenes.generar_resumen_ejecutivo(u), u, &"=== RESUMEN EJECUTIVO ===\nRecursos Disponibles: #{&1.total_recursos_disponibles}\nNecesidades Pendientes: #{&1.necesidades_pendientes}\nTotal Personas Afectadas: #{&1.personas_afectadas_total}\nPersonas Censadas: #{&1.personas_censadas}\nPersonas en Albergues: #{&1.personas_en_albergue}\nMensajes Enviados: #{&1.mensajes_enviados}\nMascotas Activas/Resueltas: #{&1.mascotas_activas}/#{&1.mascotas_resueltas}")
  def despachar(:critical_resources, args, _kw, u), do: dar_formato(GenerarResumenes.listar_recursos_criticos(hd(args ++ ["10"]), u), u, &"Total unidades movilizadas: #{&1.total_unidades_movilizadas}\n" <> Presentador.formatear_tabla(&1.recursos_criticos, [{"ID", :id, 8}, {"NOMBRE", :nombre, 14}, {"DISP", :cantidad_disponible, 6}, {"UBICACION", :ubicacion, 10}]))
  def despachar(:pending_needs, _a, _kw, u), do: dar_formato(GenerarResumenes.listar_necesidades_pendientes(u), u, &Presentador.formatear_tabla(&1, [{"ID", :id, 6}, {"ZONA", :codigo_zona, 6}, {"RECURSO", :tipo_recurso, 12}, {"PRIORIDAD", :prioridad, 10}, {"ESTADO", :estado, 10}]))

  def despachar(cmd, _a, _kw, u), do: {:error, Presentador.formatear_error(:comando_desconocido) <> " ('#{cmd}')", u}

  defp dar_exito(res, u, fun), do: dar_formato(res, u, &Presentador.formatear_exito(fun.(&1)))

  defp dar_formato(res, u, fun) do
    case res do
      {:ok, val} -> {:ok, fun.(val), u}
      {:error, r} -> {:error, Presentador.formatear_error(r), u}
    end
  end

  defp mostrar_ayuda do
    "Comandos: connect, disconnect, register_zone, list_zones, zone_status, register_sector, register_point, " <>
    "register_resource, list_resources, transfer_resource, register_need, list_needs, assign_resource, " <>
    "report_person, find_person, update_person, send_family_message, list_family_messages, " <>
    "report_pet, list_pets, match_pets, confirm_match, register_shelter, check_shelter, " <>
    "register_entry, register_exit, link_shelter_resource, link_shelter_need, list_shelters, shelter_report, " <>
    "summary, critical_resources, pending_needs, help, exit."
  end
end
