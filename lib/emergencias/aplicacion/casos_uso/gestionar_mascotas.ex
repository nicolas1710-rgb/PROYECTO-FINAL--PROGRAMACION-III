defmodule Emergencias.Aplicacion.CasosUso.GestionarMascotas do
  @moduledoc """
  Caso de uso para el registro, emparejamiento por similitud ponderada y resolución de mascotas.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoMascotas

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{ReporteMascota, Usuario}
  alias Emergencias.Dominio.Reglas.{Permisos, SimilitudMascotas, TransicionesEstado, Validaciones}

  @impl true
  @doc """
  Registrar un nuevo reporte de mascota extraviada o hallada.
  """
  @spec reportar_mascota(map(), Usuario.t(), keyword()) ::
          {:ok, ReporteMascota.t()} | {:error, atom()}
  def reportar_mascota(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :reportar_mascota) do
      puerto_mas = resolver_puerto(opciones, :puerto_mascotas, :puerto_mascotas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_mas != nil and function_exported?(puerto_mas, :reportar, 2) ->
          case puerto_mas.reportar(params, usuario.nombre) do
            {:ok, reporte} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "reportar_mascota", "Mascota #{reporte.id} reportada", fecha)
              {:ok, reporte}

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
  Ejecutar algoritmo de similitud ponderada entre mascotas perdidas y encontradas.
  """
  @spec emparejar_mascotas(Usuario.t(), keyword()) ::
          {:ok, list({ReporteMascota.t(), ReporteMascota.t(), non_neg_integer()})}
          | {:error, atom()}
  def emparejar_mascotas(%Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :emparejar_mascotas) do
      puerto_mas = resolver_puerto(opciones, :puerto_mascotas, :puerto_mascotas)
      umbral = Keyword.get(opciones, :umbral, 60)

      cond do
        puerto_mas != nil and function_exported?(puerto_mas, :emparejar, 1) ->
          puerto_mas.emparejar(umbral)

        true ->
          repositorio = Keyword.get(opciones, :repositorio)
          {:ok, lista} = cargar_mascotas(repositorio)

          perdidas = Enum.filter(lista, fn m -> m.tipo_reporte == :perdida and m.estado == :activa end)
          encontradas = Enum.filter(lista, fn m -> m.tipo_reporte == :encontrada and m.estado == :activa end)

          coincidencias = SimilitudMascotas.emparejar_reportes(perdidas, encontradas, umbral)
          {:ok, coincidencias}
      end
    end
  end

  @impl true
  @doc """
  Resolver un caso de mascota, marcándolo en estado terminal :resuelta.
  """
  @spec resolver_mascota(String.t(), Usuario.t(), keyword()) ::
          {:ok, ReporteMascota.t()} | {:error, atom()}
  def resolver_mascota(id_mascota, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :resolver_mascota) do
      puerto_mas = resolver_puerto(opciones, :puerto_mascotas, :puerto_mascotas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_mas != nil and function_exported?(puerto_mas, :resolver, 2) ->
          case puerto_mas.resolver(id_mascota, usuario.nombre) do
            {:ok, transitada} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "resolver_mascota", "Mascota #{id_mascota} resuelta", fecha)
              {:ok, transitada}

            error ->
              error
          end

        true ->
          ejecutar_resolucion_directa(id_mascota, usuario, opciones)
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
    with {:ok, datos} <- Validaciones.validar_entrada_mascota(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_mascotas(repositorio)
      nuevo_id = GeneradorId.formatear_id(:mascota, length(existentes) + 1)

      {:ok, nuevo_reporte} =
        ReporteMascota.construir(%{
          id: nuevo_id,
          tipo_reporte: datos.tipo_reporte,
          especie: datos.especie,
          nombre: datos.nombre,
          color: datos.color,
          tamano: datos.tamano,
          codigo_zona: datos.codigo_zona,
          caracteristicas: datos.caracteristicas,
          estado: :activa,
          usuario_reporta: usuario.nombre,
          fecha_registro: fecha
        })

      guardar_mascota(repositorio, nuevo_reporte)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "reportar_mascota", "Mascota #{nuevo_id} reportada", fecha)
      {:ok, nuevo_reporte}
    end
  end

  defp ejecutar_resolucion_directa(id_mascota, usuario, opciones) do
    repositorio = Keyword.get(opciones, :repositorio)
    puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
    reloj = Keyword.get(opciones, :reloj, Reloj)
    fecha = reloj.obtener_fecha_actual()

    with {:ok, %ReporteMascota{} = mascota} <- buscar_mascota(repositorio, id_mascota),
         {:ok, transitada} <- TransicionesEstado.transitar_mascota(mascota, :resuelta, usuario.nombre, fecha) do
      guardar_mascota(repositorio, transitada)
      notificar_bitacora(puerto_bitacora, usuario.nombre, "resolver_mascota", "Mascota #{id_mascota} resuelta", fecha)
      {:ok, transitada}
    end
  end

  defp buscar_mascota(nil, _id), do: {:error, :mascota_no_encontrada}
  defp buscar_mascota(repo, id) do
    {:ok, mascotas} = cargar_mascotas(repo)
    encontrada = Enum.find(mascotas, fn m -> String.upcase(m.id) == String.upcase(id) end)
    if encontrada, do: {:ok, encontrada}, else: {:error, :mascota_no_encontrada}
  end

  defp cargar_mascotas(nil), do: {:ok, []}
  defp cargar_mascotas(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:mascotas), else: {:ok, []}
  end

  defp guardar_mascota(nil, _m), do: :ok
  defp guardar_mascota(repo, m) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:mascotas, m), else: :ok
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
