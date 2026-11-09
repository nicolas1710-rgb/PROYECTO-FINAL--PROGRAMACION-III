defmodule Emergencias.Infraestructura.Entrada.DespachadorComandos do
  @moduledoc """
  Adaptador de infraestructura que valida entradas del usuario y despacha a los casos de uso.
  Garantiza que ninguna entrada inválida genere caídas por ArgumentError ni modifique el estado.
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
  alias Emergencias.Dominio.Reglas.Validaciones
  alias Emergencias.Infraestructura.Entrada.{AnalizadorComandos, Presentador}

  @doc """
  Despachar un comando analizado con protección total contra excepciones no controladas.
  """
  @spec despachar(atom(), list(), Usuario.t() | nil) ::
          {:ok, String.t(), Usuario.t() | nil}
          | {:error, String.t(), Usuario.t() | nil}
          | {:salir, String.t()}
  def despachar(comando, argumentos, usuario_actual) do
    try do
      despachar_comando(comando, argumentos, usuario_actual)
    rescue
      error ->
        {:error, Presentador.formatear_error(error), usuario_actual}
    end
  end

  @doc """
  Despachar el comando específico a su caso de uso correspondiente.
  """
  @spec despachar_comando(atom(), list(), Usuario.t() | nil) ::
          {:ok, String.t(), Usuario.t() | nil}
          | {:error, String.t(), Usuario.t() | nil}
          | {:salir, String.t()}
  def despachar_comando(:help, _args, usuario) do
    {:ok, Presentador.formatear_ayuda(), usuario}
  end

  def despachar_comando(:exit, _args, _usuario) do
    {:salir, "¡Hasta pronto! Sistema cerrado correctamente."}
  end

  def despachar_comando(:connect, [nom, clave], usuario_anterior) do
    ejecutar_conexion(nom, clave, :ciudadano, usuario_anterior)
  end

  def despachar_comando(:connect, [nom, clave, rol_str], usuario_anterior) do
    case Validaciones.validar_rol(rol_str) do
      {:ok, rol} -> ejecutar_conexion(nom, clave, rol, usuario_anterior)
      {:error, razon} -> {:error, Presentador.formatear_error(razon), usuario_anterior}
    end
  end

  def despachar_comando(:connect, _args, usuario_anterior) do
    {:error, Presentador.formatear_error(:argumentos_invalidos), usuario_anterior}
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

  def despachar_comando(:register_zone, [nom, grav_str], %Usuario{} = u) do
    with {:ok, gravedad} <- Validaciones.validar_nivel_gravedad(grav_str),
         {:ok, z} <- GestionarZonas.registrar_zona(%{nombre: nom, nivel_gravedad: gravedad}, u) do
      {:ok, Presentador.formatear_exito("Zona [#{z.id}] '#{z.nombre}' registrada."), u}
    else
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_need, [zona, rec, cant_str, prio_str | opcionales], %Usuario{} = u) do
    desc = if length(opcionales) > 0, do: Enum.join(opcionales, " "), else: ""

    with {:ok, cant} <- Validaciones.validar_cantidad_positiva(cant_str),
         {:ok, prio} <- Validaciones.validar_prioridad(prio_str),
         params = %{
           codigo_zona: AnalizadorComandos.normalizar_identificador(zona),
           tipo_recurso: rec,
           cantidad_solicitada: cant,
           prioridad: prio,
           descripcion: desc
         },
         {:ok, n} <- GestionarNecesidades.registrar_necesidad(params, u) do
      {:ok, Presentador.formatear_exito("Necesidad [#{n.id}] reportada con prioridad #{n.prioridad}."), u}
    else
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

    with {:ok, cantidad} <- Validaciones.validar_cantidad_positiva(cant_str),
         {:ok, {recurso_act, _mov}} <- GestionarRecursos.asignar_recurso(rec_norm, nec_norm, cantidad, u) do
      msg = "Asignados #{cantidad} #{recurso_act.unidad_medida} de [#{rec_norm}] a [#{nec_norm}]. Stock restante: #{recurso_act.cantidad_disponible}"
      {:ok, Presentador.formatear_exito(msg), u}
    else
      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_resource, [tipo, unidad, cant_str, zona], %Usuario{} = u) do
    with {:ok, cant} <- Validaciones.validar_cantidad_positiva(cant_str) do
      params = %{
        nombre: tipo,
        tipo: tipo,
        unidad_medida: unidad,
        cantidad_total: cant,
        codigo_zona: AnalizadorComandos.normalizar_identificador(zona)
      }

      case GestionarRecursos.registrar_recurso(params, u) do
        {:ok, r} ->
          {:ok, Presentador.formatear_exito("Recurso [#{r.id}] #{r.tipo} (#{r.cantidad_total} #{r.unidad_medida}) ingresado a #{r.codigo_zona}."), u}

        {:error, razon} ->
          {:error, Presentador.formatear_error(razon), u}
      end
    else
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_resource, [nom, tipo, unidad, cant_str, zona], %Usuario{} = u) do
    with {:ok, cant} <- Validaciones.validar_cantidad_positiva(cant_str) do
      params = %{
        nombre: nom,
        tipo: tipo,
        unidad_medida: unidad,
        cantidad_total: cant,
        codigo_zona: AnalizadorComandos.normalizar_identificador(zona)
      }

      case GestionarRecursos.registrar_recurso(params, u) do
        {:ok, r} ->
          {:ok, Presentador.formatear_exito("Recurso [#{r.id}] #{r.nombre} (#{r.cantidad_total} #{r.unidad_medida}) ingresado a #{r.codigo_zona}."), u}

        {:error, razon} ->
          {:error, Presentador.formatear_error(razon), u}
      end
    else
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

    with {:ok, cant} <- Validaciones.validar_cantidad_positiva(cant_str),
         {:ok, {o_act, d_act}} <- GestionarRecursos.transferir_recurso(o_norm, d_norm, cant, u) do
      msg = "Transferencia exitosa: #{cant} transferidos de [#{o_act.id}] (queda #{o_act.cantidad_disponible}) a [#{d_act.id}] (queda #{d_act.cantidad_disponible})."
      {:ok, Presentador.formatear_exito(msg), u}
    else
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

  def despachar_comando(:report_pet, [tipo_str, esp, col, tam_str, zona | opcional], %Usuario{} = u) do
    nombre = if length(opcional) > 0, do: hd(opcional), else: ""

    with {:ok, tipo} <- Validaciones.validar_tipo_reporte_mascota(tipo_str),
         {:ok, tam} <- Validaciones.validar_tamano_mascota(tam_str) do
      params = %{
        tipo_reporte: tipo,
        especie: esp,
        nombre: nombre,
        color: col,
        tamano: tam,
        codigo_zona: AnalizadorComandos.normalizar_identificador(zona)
      }

      case GestionarMascotas.reportar_mascota(params, u) do
        {:ok, m} -> {:ok, Presentador.formatear_exito("Mascota [#{m.id}] reportada como #{m.tipo_reporte} (#{m.especie} #{m.color})."), u}
        {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
      end
    else
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:match_pets, args, %Usuario{} = u) do
    umbral_res =
      if length(args) > 0 do
        Validaciones.validar_entero(hd(args))
      else
        {:ok, 60}
      end

    with {:ok, umbral} <- umbral_res,
         {:ok, coincidencias} <- GestionarMascotas.emparejar_mascotas(u, umbral: umbral) do
      {:ok, Presentador.formatear_coincidencias_mascotas(coincidencias), u}
    else
      {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_shelter, [nom, zona, cap_str], %Usuario{} = u) do
    with {:ok, cap} <- Validaciones.validar_cantidad_positiva(cap_str) do
      params = %{
        nombre: nom,
        codigo_zona: AnalizadorComandos.normalizar_identificador(zona),
        capacidad_maxima: cap
      }

      case GestionarAlbergues.registrar_albergue(params, u) do
        {:ok, a} -> {:ok, Presentador.formatear_exito("Albergue [#{a.id}] '#{a.nombre}' registrado con capacidad #{a.capacidad_maxima}."), u}
        {:error, razon} -> {:error, Presentador.formatear_error(razon), u}
      end
    else
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

    with {:ok, doc_valido} <- Validaciones.validar_documento(doc),
         {:ok, a} <- GestionarAlbergues.registrar_entrada(codigo, doc_valido, u) do
      _ = GestionarFamiliares.actualizar_persona(doc_valido, :en_albergue, %{codigo_albergue: codigo}, u)
      {:ok, Presentador.formatear_exito("Ingreso registrado: #{doc_valido} alojado en albergue [#{a.id}]."), u}
    else
      {:error, razon} ->
        {:error, Presentador.formatear_error(razon), u}
    end
  end

  def despachar_comando(:register_exit, [id_alb, doc], %Usuario{} = u) do
    codigo = AnalizadorComandos.normalizar_identificador(id_alb)

    with {:ok, doc_valido} <- Validaciones.validar_documento(doc),
         {:ok, a} <- GestionarAlbergues.registrar_salida(codigo, doc_valido, u) do
      _ = GestionarFamiliares.actualizar_persona(doc_valido, :reunificada, %{codigo_albergue: nil}, u)
      {:ok, Presentador.formatear_exito("Salida registrada: #{doc_valido} egresó del albergue [#{a.id}]."), u}
    else
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
    umbral_res =
      if length(args) > 0 do
        Validaciones.validar_entero(hd(args))
      else
        {:ok, 20}
      end

    with {:ok, umbral} <- umbral_res,
         {:ok, lista} <- GenerarResumenes.listar_recursos_criticos(umbral, u) do
      {:ok, Presentador.formatear_recursos(lista), u}
    else
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
