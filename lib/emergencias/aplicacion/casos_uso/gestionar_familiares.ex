defmodule Emergencias.Aplicacion.CasosUso.GestionarFamiliares do
  @moduledoc """
  Caso de uso para localización de personas damnificadas y mensajería entre familiares.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoFamiliares

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Mensaje, Persona, Usuario}
  alias Emergencias.Dominio.Reglas.{Permisos, TransicionesEstado, Validaciones}

  @impl true
  @doc """
  Registrar reporte de una persona no localizada o damnificada.
  """
  @spec reportar_persona(map(), Usuario.t(), keyword()) :: {:ok, Persona.t()} | {:error, atom()}
  def reportar_persona(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :reportar_persona) do
      puerto_per = resolver_puerto(opciones, :puerto_personas, :puerto_personas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_per != nil and function_exported?(puerto_per, :reportar, 2) ->
          case puerto_per.reportar(params, usuario.nombre) do
            {:ok, persona} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "reportar_persona", "Persona #{persona.documento} reportada", fecha)
              {:ok, persona}

            error ->
              error
          end

        true ->
          ejecutar_reporte_directo(params, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Buscar persona por su documento de identidad.
  """
  @spec buscar_persona(String.t(), Usuario.t(), keyword()) :: {:ok, Persona.t()} | {:error, atom()}
  def buscar_persona(documento, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :buscar_persona) do
      puerto_per = resolver_puerto(opciones, :puerto_personas, :puerto_personas)

      cond do
        puerto_per != nil and function_exported?(puerto_per, :buscar, 1) ->
          puerto_per.buscar(documento)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)

          case buscar_por_documento(repositorio, documento) do
            {:ok, %Persona{} = p} -> {:ok, p}
            _ -> {:error, :persona_no_encontrada}
          end
      end
    end
  end

  @impl true
  @doc """
  Enviar un mensaje de familiar asociado a un documento de persona.
  """
  @spec enviar_mensaje(String.t(), String.t(), Usuario.t(), keyword()) ::
          {:ok, Mensaje.t()} | {:error, atom()}
  def enviar_mensaje(documento_persona, contenido, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :enviar_mensaje) do
      puerto_per = resolver_puerto(opciones, :puerto_personas, :puerto_personas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_per != nil and function_exported?(puerto_per, :enviar_mensaje, 3) ->
          case puerto_per.enviar_mensaje(documento_persona, contenido, usuario.nombre) do
            {:ok, msg} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "enviar_mensaje", "Mensaje #{msg.id} a #{documento_persona}", fecha)
              {:ok, msg}

            error ->
              error
          end

        true ->
          ejecutar_envio_directo(documento_persona, contenido, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Listar todos los mensajes recibidos para un documento de persona.
  """
  @spec listar_mensajes(String.t(), Usuario.t(), keyword()) ::
          {:ok, list(Mensaje.t())} | {:error, atom()}
  def listar_mensajes(documento_persona, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :listar_mensajes) do
      puerto_per = resolver_puerto(opciones, :puerto_personas, :puerto_personas)

      cond do
        puerto_per != nil and function_exported?(puerto_per, :listar_mensajes, 1) ->
          puerto_per.listar_mensajes(documento_persona)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)
          {:ok, todos} = cargar_mensajes(repositorio)

          filtrados =
            Enum.filter(todos, fn m ->
              String.trim(m.documento_persona) == String.trim(documento_persona)
            end)

          {:ok, filtrados}
      end
    end
  end

  @impl true
  @doc """
  Actualizar el estado y ubicación de una persona en el sistema.
  """
  @spec actualizar_persona(String.t(), atom(), map(), Usuario.t(), keyword()) ::
          {:ok, Persona.t()} | {:error, atom()}
  def actualizar_persona(documento, nuevo_estado, extras, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :actualizar_persona) do
      puerto_per = resolver_puerto(opciones, :puerto_personas, :puerto_personas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_per != nil and function_exported?(puerto_per, :actualizar_estado, 4) ->
          case puerto_per.actualizar_estado(documento, nuevo_estado, extras, usuario.nombre) do
            {:ok, persona} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "actualizar_persona", "#{documento} -> #{nuevo_estado}", fecha)
              {:ok, persona}

            error ->
              error
          end

        true ->
          ejecutar_actualizacion_directa(documento, nuevo_estado, extras, usuario, opciones)
      end
    end
  end

  defp resolver_puerto(opciones, clave, config_key) do
    cond do
      Keyword.has_key?(opciones, clave) -> Keyword.get(opciones, clave)
      Keyword.has_key?(opciones, :repositorio) -> nil
      true -> Application.get_env(:emergencias, config_key)
    end
  end

  defp ejecutar_reporte_directo(params, usuario, opciones) do
    with {:ok, datos} <- Validaciones.validar_entrada_persona(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_personas(repositorio)
      nuevo_id = GeneradorId.formatear_id(:persona, length(existentes) + 1)

      {:ok, nueva_persona} =
        Persona.construir(%{
          id: nuevo_id,
          documento: datos.documento,
          nombre_completo: datos.nombre_completo,
          estado: :reportada,
          fecha_reporte: fecha,
          ubicacion_actual: Map.get(params, :ubicacion_actual, "desconocida"),
          codigo_albergue: Map.get(params, :codigo_albergue, nil)
        })

      guardar_persona(repositorio, nueva_persona)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "reportar_persona", "Persona #{datos.documento} reportada", fecha)
      {:ok, nueva_persona}
    end
  end

  defp ejecutar_envio_directo(documento_persona, contenido, usuario, opciones) do
    with {:ok, doc_valido} <- Validaciones.validar_documento(documento_persona),
         {:ok, cont_valido} <- Validaciones.validar_texto_no_vacio(contenido) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_mensajes(repositorio)
      nuevo_id = GeneradorId.formatear_id(:mensaje, length(existentes) + 1)

      {:ok, nuevo_msg} =
        Mensaje.construir(%{
          id: nuevo_id,
          documento_persona: doc_valido,
          remitente: usuario.nombre,
          contenido: cont_valido,
          fecha_envio: fecha
        })

      guardar_mensaje(repositorio, nuevo_msg)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "enviar_mensaje", "Mensaje #{nuevo_id} a #{doc_valido}", fecha)
      {:ok, nuevo_msg}
    end
  end

  defp ejecutar_actualizacion_directa(documento, nuevo_estado, extras, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %Persona{} = actual} <- buscar_por_documento(repositorio, documento),
         {:ok, transitada} <- TransicionesEstado.transitar_persona(actual, nuevo_estado, extras, usuario.nombre, fecha) do
      guardar_persona(repositorio, transitada)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "actualizar_persona", "#{documento} -> #{nuevo_estado}", fecha)
      {:ok, transitada}
    end
  end

  defp buscar_por_documento(nil, _doc), do: {:error, :persona_no_encontrada}
  defp buscar_por_documento(repo, doc) do
    {:ok, personas} = cargar_personas(repo)
    encontrada = Enum.find(personas, fn p -> String.trim(p.documento) == String.trim(doc) end)
    if encontrada, do: {:ok, encontrada}, else: {:error, :persona_no_encontrada}
  end

  defp cargar_personas(nil), do: {:ok, []}
  defp cargar_personas(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:personas), else: {:ok, []}
  end

  defp guardar_persona(nil, _p), do: :ok
  defp guardar_persona(repo, p) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:personas, p), else: :ok
  end

  defp cargar_mensajes(nil), do: {:ok, []}
  defp cargar_mensajes(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:mensajes), else: {:ok, []}
  end

  defp guardar_mensaje(nil, _m), do: :ok
  defp guardar_mensaje(repo, m) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:mensajes, m), else: :ok
  end

  defp notificar_bitacora(nil, _u, _a, _d, _f), do: :ok
  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
