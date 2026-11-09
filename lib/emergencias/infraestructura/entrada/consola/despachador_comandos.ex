defmodule Emergencias.Infraestructura.Entrada.DespachadorComandos do
  @moduledoc """
  Enrutador de comandos que vincula las entradas de consola con los casos de uso.
  Valida sesión activa, desempaqueta argumentos y delega al presentador la salida final.
  """

  alias Emergencias.Aplicacion.CasosUso.{
    GenerarResumenes,
    GestionarAlbergues,
    GestionarFamiliares,
    GestionarMascotas,
    GestionarNecesidades,
    GestionarRecursos,
    GestionarUsuarios,
    GestionarZonas
  }

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Infraestructura.Entrada.{AnalizadorComandos, Presentador}

  @doc """
  Despachar un comando analizado hacia el caso de uso correspondiente.
  Retorna `{:ok, texto_salida, usuario_actual}`, `{:error, error_str, usuario_actual}` o `{:salir, texto}`.
  """
  @spec despachar_comando(atom(), list(), Usuario.t() | nil) ::
          {:ok, String.t(), Usuario.t() | nil}
          | {:error, String.t(), Usuario.t() | nil}
          | {:salir, String.t()}
  def despachar_comando(:help, _args, usuario), do: {:ok, Presentador.formatear_ayuda(), usuario}
  def despachar_comando(:exit, _args, _usuario), do: {:salir, "Cerrando sistema de emergencias. ¡Hasta pronto!"}

  def despachar_comando(:connect, [nom, clave], usuario) do
    ejecutar_conexion(nom, clave, :ciudadano, usuario)
  end

  def despachar_comando(:connect, [nom, clave, rol_str], usuario) do
    rol = String.to_atom(String.downcase(to_string(rol_str)))
    ejecutar_conexion(nom, clave, rol, usuario)
  end

  def despachar_comando(:connect, _args, usuario) do
    {:error, Presentador.formatear_error(:argumentos_invalidos), usuario}
  end

  def despachar_comando(:disconnect, _args, nil) do
    {:error, Presentador.formatear_error(:no_autenticado), nil}
  end

  def despachar_comando(:disconnect, _args, %Usuario{} = usuario) do
    GestionarUsuarios.desconectar(usuario.nombre)
    {:ok, Presentador.formatear_exito("Sesión de '#{usuario.nombre}' cerrada correctamente."), nil}
  end

  # Comandos que exigen usuario autenticado
  def despachar_comando(_cmd, _args, nil) do
    {:error, Presentador.formatear_error(:no_autenticado), nil}
  end

  def despachar_comando(:register_zone, [nom, grav], %Usuario{} = u) do
    params = %{nombre: nom, nivel_gravedad: String.to_atom(String.downcase(to_string(grav)))}

    case GestionarZonas.registrar_zona(params, u) do
      {:ok, z} -> {:ok, Presentador.formatear_exito("Zona [#{z.id}] '#{z.nombre}' registrada."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_need, [zona, rec, cant_str, prio_str], %Usuario{} = u) do
    params = %{
      codigo_zona: AnalizadorComandos.normalizar_identificador(zona),
      tipo_recurso: rec,
      cantidad_solicitada: String.to_integer(cant_str),
      prioridad: String.to_atom(String.downcase(to_string(prio_str)))
    }

    case GestionarNecesidades.registrar_necesidad(params, u) do
      {:ok, n} -> {:ok, Presentador.formatear_exito("Necesidad [#{n.id}] reportada con prioridad #{n.prioridad}."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:list_needs, filtros, %Usuario{} = u) do
    filtros_keyword = extraer_filtros_necesidades(filtros)

    case GestionarNecesidades.listar_necesidades(filtros_keyword, u) do
      {:ok, lista} -> {:ok, Presentador.formatear_necesidades(lista), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:assign_resource, [id_rec, id_nec, cant_str], %Usuario{} = u) do
    rec_norm = AnalizadorComandos.normalizar_identificador(id_rec)
    nec_norm = AnalizadorComandos.normalizar_identificador(id_nec)
    cantidad = String.to_integer(cant_str)

    case GestionarRecursos.asignar_recurso(rec_norm, nec_norm, cantidad, u) do
      {:ok, {recurso_act, _mov}} ->
        # Opcional: transitar necesidad a asignada si estaba pendiente
        _ = GestionarNecesidades.actualizar_necesidad(nec_norm, :asignada, u)
        msg = "Asignados #{cantidad} #{recurso_act.unidad_medida} de [#{rec_norm}] a [#{nec_norm}]. Stock restante: #{recurso_act.cantidad_disponible}"
        {:ok, Presentador.formatear_exito(msg), u}

      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_resource, [tipo, unidad, cant_str, zona], %Usuario{} = u) do
    params = %{
      tipo: tipo,
      unidad_medida: unidad,
      cantidad_total: String.to_integer(cant_str),
      codigo_zona: AnalizadorComandos.normalizar_identificador(zona)
    }

    case GestionarRecursos.registrar_recurso(params, u) do
      {:ok, r} -> {:ok, Presentador.formatear_exito("Recurso [#{r.id}] #{r.tipo} (#{r.cantidad_total} #{r.unidad_medida}) ingresado a #{r.codigo_zona}."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:list_resources, filtros, %Usuario{} = u) do
    filtros_kw = extraer_filtros_recursos(filtros)

    case GestionarRecursos.listar_recursos(filtros_kw, u) do
      {:ok, lista} -> {:ok, Presentador.formatear_recursos(lista), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:transfer_resource, [orig, dest, cant_str], %Usuario{} = u) do
    o_norm = AnalizadorComandos.normalizar_identificador(orig)
    d_norm = AnalizadorComandos.normalizar_identificador(dest)
    cant = String.to_integer(cant_str)

    case GestionarRecursos.transferir_recurso(o_norm, d_norm, cant, u) do
      {:ok, {o_act, d_act}} ->
        msg = "Transferencia exitosa: #{cant} transferidos de [#{o_act.id}] (queda #{o_act.cantidad_disponible}) a [#{d_act.id}] (queda #{d_act.cantidad_disponible})."
        {:ok, Presentador.formatear_exito(msg), u}

      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:report_person, [doc, nom], %Usuario{} = u) do
    case GestionarFamiliares.reportar_persona(%{documento: doc, nombre_completo: nom}, u) do
      {:ok, p} -> {:ok, Presentador.formatear_exito("Persona [#{p.id}] #{p.nombre_completo} (Doc: #{p.documento}) reportada como #{p.estado}."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:find_person, [doc], %Usuario{} = u) do
    case GestionarFamiliares.buscar_persona(doc, u) do
      {:ok, p} -> {:ok, Presentador.formatear_persona(p), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:send_family_message, [doc, contenido], %Usuario{} = u) do
    case GestionarFamiliares.enviar_mensaje(doc, contenido, u) do
      {:ok, m} -> {:ok, Presentador.formatear_exito("Mensaje familiar [#{m.id}] registrado para documento #{doc}."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:list_family_messages, [doc], %Usuario{} = u) do
    case GestionarFamiliares.listar_mensajes(doc, u) do
      {:ok, mensajes} -> {:ok, Presentador.formatear_mensajes(mensajes), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:report_pet, [tipo, esp, col, tam, zona | opcional], %Usuario{} = u) do
    nombre = if length(opcional) > 0, do: hd(opcional), else: ""

    params = %{
      tipo_reporte: String.to_atom(String.downcase(to_string(tipo))),
      especie: esp,
      nombre: nombre,
      color: col,
      tamano: String.to_atom(String.downcase(to_string(tam))),
      codigo_zona: AnalizadorComandos.normalizar_identificador(zona)
    }

    case GestionarMascotas.reportar_mascota(params, u) do
      {:ok, m} -> {:ok, Presentador.formatear_exito("Mascota [#{m.id}] reportada como #{m.tipo_reporte} (#{m.especie} #{m.color})."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:match_pets, args, %Usuario{} = u) do
    umbral = if length(args) > 0, do: String.to_integer(hd(args)), else: 60

    case GestionarMascotas.emparejar_mascotas(u, umbral: umbral) do
      {:ok, coincidencias} -> {:ok, Presentador.formatear_coincidencias_mascotas(coincidencias), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_shelter, [nom, zona, cap_str], %Usuario{} = u) do
    params = %{
      nombre: nom,
      codigo_zona: AnalizadorComandos.normalizar_identificador(zona),
      capacidad_maxima: String.to_integer(cap_str)
    }

    case GestionarAlbergues.registrar_albergue(params, u) do
      {:ok, a} -> {:ok, Presentador.formatear_exito("Albergue [#{a.id}] '#{a.nombre}' registrado con capacidad #{a.capacidad_maxima}."), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:check_shelter, [id_alb], %Usuario{} = u) do
    codigo = AnalizadorComandos.normalizar_identificador(id_alb)

    case GestionarAlbergues.consultar_albergue(codigo, u) do
      {:ok, a} -> {:ok, Presentador.formatear_albergue(a), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_entry, [id_alb, doc], %Usuario{} = u) do
    codigo = AnalizadorComandos.normalizar_identificador(id_alb)

    case GestionarAlbergues.registrar_entrada(codigo, doc, u) do
      {:ok, a} ->
        _ = GestionarFamiliares.actualizar_persona(doc, :en_albergue, %{codigo_albergue: codigo}, u)
        {:ok, Presentador.formatear_exito("Ingreso registrado: #{doc} alojado en albergue [#{a.id}]."), u}

      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_exit, [id_alb, doc], %Usuario{} = u) do
    codigo = AnalizadorComandos.normalizar_identificador(id_alb)

    case GestionarAlbergues.registrar_salida(codigo, doc, u) do
      {:ok, a} ->
        _ = GestionarFamiliares.actualizar_persona(doc, :reunificada, %{codigo_albergue: nil}, u)
        {:ok, Presentador.formatear_exito("Salida registrada: #{doc} egresó del albergue [#{a.id}]."), u}

      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:summary, _args, %Usuario{} = u) do
    case GenerarResumenes.generar_resumen(u) do
      {:ok, resumen} -> {:ok, Presentador.formatear_resumen(resumen), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:critical_resources, args, %Usuario{} = u) do
    umbral = if length(args) > 0, do: String.to_integer(hd(args)), else: 20

    case GenerarResumenes.listar_recursos_criticos(umbral, u) do
      {:ok, lista} -> {:ok, Presentador.formatear_recursos(lista), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:pending_needs, _args, %Usuario{} = u) do
    case GenerarResumenes.listar_necesidades_pendientes(u) do
      {:ok, lista} -> {:ok, Presentador.formatear_necesidades(lista), u}
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(_otro, _args, u) do
    {:error, Presentador.formatear_error(:argumentos_invalidos), u}
  end

  defp ejecutar_conexion(nombre, clave, rol, _anterior) do
    case GestionarUsuarios.conectar(nombre, clave, rol) do
      {:ok, %Usuario{} = usuario} ->
        {:ok, Presentador.formatear_exito("Bienvenido/a, #{usuario.nombre}. Conectado con rol: #{usuario.rol}."), usuario}

      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), nil}
    end
  end

  defp extraer_filtros_necesidades(filtros) do
    Enum.flat_map(filtros, fn
      {:zona, z} -> [zona: AnalizadorComandos.normalizar_identificador(z)]
      {:prioridad, p} -> [prioridad: p]
      {:estado, e} -> [estado: e]
      _ -> []
    end)
  end

  defp extraer_filtros_recursos(filtros) do
    Enum.flat_map(filtros, fn
      {:zona, z} -> [zona: AnalizadorComandos.normalizar_identificador(z)]
      {:tipo, t} -> [tipo: t]
      _ -> []
    end)
  end
end
