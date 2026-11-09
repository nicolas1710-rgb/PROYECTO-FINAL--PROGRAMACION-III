defmodule Emergencias.Aplicacion.CasosUso.GenerarResumenes do
  @moduledoc """
  Caso de uso para consolidar indicadores ejecutivos, recursos críticos y necesidades pendientes.
  Aplica el algoritmo recursivo Merge Sort para priorizar las necesidades pendientes.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoResumenes

  alias Emergencias.Dominio.Modelos.{Necesidad, Recurso, Usuario}
  alias Emergencias.Dominio.Reglas.{Ordenamiento, Permisos}
  alias Emergencias.Infraestructura.Procesos.{
    GestorMascotas,
    GestorNecesidades,
    GestorPersonas,
    GestorRecursos
  }

  @impl true
  @doc """
  Generar resumen consolidado de recursos, necesidades, personas, mensajes y mascotas.
  """
  @spec generar_resumen(Usuario.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def generar_resumen(%Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :generar_resumen) do
      {:ok, recursos} = obtener_datos_recursos(opciones)
      {:ok, necesidades} = obtener_datos_necesidades(opciones)
      {:ok, personas} = obtener_datos_personas(opciones)
      {:ok, mensajes} = obtener_datos_mensajes(opciones)
      {:ok, mascotas} = obtener_datos_mascotas(opciones)
      {:ok, albergues} = cargar_datos_repo(opciones, :albergues)

      total_disponible = Enum.reduce(recursos, 0, fn r, acc -> acc + r.cantidad_disponible end)
      pendientes = Enum.count(necesidades, fn n -> n.estado == :pendiente end)
      localizadas = Enum.count(personas, fn p -> p.estado in [:localizada, :en_albergue, :reunificada] end)
      mascotas_resueltas = Enum.count(mascotas, fn m -> m.estado == :resuelta end)
      total_alojados = Enum.reduce(albergues, 0, fn a, acc -> acc + MapSet.size(a.personas_alojadas) end)

      resumen = %{
        total_recursos_disponibles: total_disponible,
        necesidades_pendientes: pendientes,
        personas_localizadas: localizadas,
        total_personas_reportadas: length(personas),
        total_mensajes_enviados: length(mensajes),
        mascotas_activas: length(mascotas) - mascotas_resueltas,
        mascotas_resueltas: mascotas_resueltas,
        personas_en_albergues: total_alojados
      }

      {:ok, resumen}
    end
  end

  @impl true
  @doc """
  Listar recursos cuyo stock disponible se encuentre igual o por debajo del umbral crítico.
  """
  @spec listar_recursos_criticos(non_neg_integer(), Usuario.t(), keyword()) ::
          {:ok, list(Recurso.t())} | {:error, atom()}
  def listar_recursos_criticos(umbral \\ 20, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :recursos_criticos) do
      {:ok, recursos} = obtener_datos_recursos(opciones)
      criticos = Enum.filter(recursos, fn r -> r.cantidad_disponible <= umbral end)
      {:ok, criticos}
    end
  end

  @impl true
  @doc """
  Listar necesidades pendientes ordenadas recursivamente mediante Merge Sort
  por prioridad descendente y antigüedad ascendente.
  """
  @spec listar_necesidades_pendientes(Usuario.t(), keyword()) ::
          {:ok, list(Necesidad.t())} | {:error, atom()}
  def listar_necesidades_pendientes(%Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :necesidades_pendientes) do
      {:ok, necesidades} = obtener_datos_necesidades(opciones)
      pendientes = Enum.filter(necesidades, fn n -> n.estado == :pendiente end)
      ordenadas = Ordenamiento.ordenar_por_prioridad(pendientes)
      {:ok, ordenadas}
    end
  end

  defp obtener_datos_recursos(opts) do
    repo = Keyword.get(opts, :repositorio)

    if Process.whereis(GestorRecursos) != nil and is_nil(repo) do
      GestorRecursos.listar_recursos()
    else
      cargar_datos_repo(opts, :recursos)
    end
  end

  defp obtener_datos_necesidades(opts) do
    repo = Keyword.get(opts, :repositorio)

    if Process.whereis(GestorNecesidades) != nil and is_nil(repo) do
      GestorNecesidades.listar_necesidades()
    else
      cargar_datos_repo(opts, :necesidades)
    end
  end

  defp obtener_datos_personas(opts) do
    repo = Keyword.get(opts, :repositorio)

    if Process.whereis(GestorPersonas) != nil and is_nil(repo) do
      GestorPersonas.listar_personas()
    else
      cargar_datos_repo(opts, :personas)
    end
  end

  defp obtener_datos_mensajes(opts) do
    repo = Keyword.get(opts, :repositorio)

    if Process.whereis(GestorPersonas) != nil and is_nil(repo) do
      GestorPersonas.listar_todos_mensajes()
    else
      cargar_datos_repo(opts, :mensajes)
    end
  end

  defp obtener_datos_mascotas(opts) do
    repo = Keyword.get(opts, :repositorio)

    if Process.whereis(GestorMascotas) != nil and is_nil(repo) do
      GestorMascotas.listar_mascotas()
    else
      cargar_datos_repo(opts, :mascotas)
    end
  end

  defp cargar_datos_repo(opts, entidad) do
    repo = Keyword.get(opts, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)
    if function_exported?(repo, :cargar, 1), do: repo.cargar(entidad), else: {:ok, []}
  end
end
