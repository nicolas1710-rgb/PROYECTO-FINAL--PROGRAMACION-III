defmodule Emergencias.Aplicacion.CasosUso.GestionarZonas do
  @moduledoc """
  Caso de uso para la administración y consulta de zonas territoriales de emergencia.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoZonas

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Usuario, Zona}
  alias Emergencias.Dominio.Reglas.{Permisos, Validaciones}
  alias Emergencias.Infraestructura.Procesos.GestorZonas

  @impl true
  @doc """
  Registrar una nueva zona en el sistema previa autorización y validación.
  """
  @spec registrar_zona(map(), Usuario.t(), keyword()) :: {:ok, Zona.t()} | {:error, atom()}
  def registrar_zona(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_zona) do
      repo_personalizado = Keyword.get(opciones, :repositorio)

      if Process.whereis(GestorZonas) != nil and is_nil(repo_personalizado) do
        GestorZonas.registrar_zona(params)
      else
        ejecutar_registro_directo(params, usuario, opciones)
      end
    end
  end

  @impl true
  @doc """
  Consultar una zona específica por su código identificador.
  """
  @spec consultar_zona(String.t(), Usuario.t(), keyword()) :: {:ok, Zona.t()} | {:error, atom()}
  def consultar_zona(id_zona, %Usuario{}, opciones \\ []) do
    repo_personalizado = Keyword.get(opciones, :repositorio)

    if Process.whereis(GestorZonas) != nil and is_nil(repo_personalizado) do
      GestorZonas.consultar_zona(id_zona)
    else
      repositorio = obtener_repositorio(opciones)

      case cargar_zonas(repositorio) do
        {:ok, lista} ->
          encontrada = Enum.find(lista, fn z -> String.upcase(z.id) == String.upcase(id_zona) end)
          if encontrada, do: {:ok, encontrada}, else: {:error, :zona_no_encontrada}

        _ ->
          {:error, :zona_no_encontrada}
      end
    end
  end

  @impl true
  @doc """
  Listar todas las zonas registradas en el sistema.
  """
  @spec listar_zonas(Usuario.t(), keyword()) :: {:ok, list(Zona.t())} | {:error, atom()}
  def listar_zonas(%Usuario{}, opciones \\ []) do
    repo_personalizado = Keyword.get(opciones, :repositorio)

    if Process.whereis(GestorZonas) != nil and is_nil(repo_personalizado) do
      GestorZonas.listar_zonas()
    else
      repositorio = obtener_repositorio(opciones)
      cargar_zonas(repositorio)
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos_validados} <- Validaciones.validar_entrada_zona(params) do
      repositorio = obtener_repositorio(opciones)
      bitacora = obtener_bitacora(opciones)
      reloj = obtener_reloj(opciones)
      fecha = reloj.obtener_fecha_actual()

      {:ok, existentes} = cargar_zonas(repositorio)
      nuevo_id = GeneradorId.formatear_id(:zona, length(existentes) + 1)

      {:ok, nueva_zona} =
        Zona.construir(%{
          id: nuevo_id,
          nombre: datos_validados.nombre,
          nivel_gravedad: datos_validados.nivel_gravedad,
          fecha_registro: fecha,
          sectores: Map.get(params, :sectores, [])
        })

      guardar_zona(repositorio, nueva_zona)
      notificar_bitacora(bitacora, usuario.nombre, "registrar_zona", "Zona #{nuevo_id} creada", fecha)
      {:ok, nueva_zona}
    end
  end

  defp obtener_repositorio(opts),
    do: Keyword.get(opts, :repositorio, Emergencias.Infraestructura.Salida.Persistencia.AlmacenArchivo)

  defp obtener_bitacora(opts),
    do: Keyword.get(opts, :bitacora, Emergencias.Infraestructura.Procesos.BitacoraActividad)

  defp obtener_reloj(opts), do: Keyword.get(opts, :reloj, Reloj)

  defp cargar_zonas(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:zonas), else: {:ok, []}
  end

  defp guardar_zona(repo, zona) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:zonas, zona), else: :ok
  end

  defp notificar_bitacora(bitacora, u, a, d, f) do
    if is_atom(bitacora) and function_exported?(bitacora, :registrar_actividad, 4) do
      bitacora.registrar_actividad(u, a, d, f)
    else
      :ok
    end
  end
end
