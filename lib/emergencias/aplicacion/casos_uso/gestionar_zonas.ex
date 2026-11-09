defmodule Emergencias.Aplicacion.CasosUso.GestionarZonas do
  @moduledoc """
  Caso de uso para la administración y consulta de zonas territoriales de emergencia.
  """

  @behaviour Emergencias.Aplicacion.Puertos.Entrada.PuertoZonas

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.{Usuario, Zona}
  alias Emergencias.Dominio.Reglas.{Permisos, Validaciones}

  @impl true
  @doc """
  Registrar una nueva zona en el sistema previa autorización y validación.
  """
  @spec registrar_zona(map(), Usuario.t(), keyword()) :: {:ok, Zona.t()} | {:error, atom()}
  def registrar_zona(params, %Usuario{} = usuario, opciones \\ []) do
    with :ok <- Permisos.autorizar(usuario.rol, :registrar_zona) do
      puerto_zonas = resolver_puerto(opciones, :puerto_zonas, :puerto_zonas)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
      fecha = reloj.obtener_fecha_actual()

      cond do
        puerto_zonas != nil and function_exported?(puerto_zonas, :registrar, 2) ->
          case puerto_zonas.registrar(params, usuario.nombre) do
            {:ok, zona} ->
              notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_zona", "Zona #{zona.id} creada", fecha)
              {:ok, zona}

            error ->
              error
          end

        true ->
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
    puerto_zonas = resolver_puerto(opciones, :puerto_zonas, :puerto_zonas)

    cond do
      puerto_zonas != nil and function_exported?(puerto_zonas, :consultar, 1) ->
        puerto_zonas.consultar(id_zona)

      true ->
        repositorio = Keyword.get(opciones, :repositorio)

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
    puerto_zonas = resolver_puerto(opciones, :puerto_zonas, :puerto_zonas)

    cond do
      puerto_zonas != nil and function_exported?(puerto_zonas, :listar, 0) ->
        puerto_zonas.listar()

      true ->
        repositorio = Keyword.get(opciones, :repositorio)
        cargar_zonas(repositorio)
    end
  end

  defp resolver_puerto(opciones, clave, config_key) do
    cond do
      Keyword.has_key?(opciones, clave) -> Keyword.get(opciones, clave)
      Keyword.has_key?(opciones, :repositorio) -> nil
      true -> Application.get_env(:emergencias, config_key)
    end
  end

  defp ejecutar_registro_directo(params, usuario, opciones) do
    with {:ok, datos_validados} <- Validaciones.validar_entrada_zona(params) do
      repositorio = Keyword.get(opciones, :repositorio)
      puerto_bitacora = resolver_puerto(opciones, :bitacora, :puerto_bitacora)
      reloj = Keyword.get(opciones, :reloj, Reloj)
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
      notificar_bitacora(puerto_bitacora, usuario.nombre, "registrar_zona", "Zona #{nuevo_id} creada", fecha)
      {:ok, nueva_zona}
    end
  end

  defp cargar_zonas(nil), do: {:ok, []}
  defp cargar_zonas(repo) do
    if function_exported?(repo, :cargar, 1), do: repo.cargar(:zonas), else: {:ok, []}
  end

  defp guardar_zona(nil, _zona), do: :ok
  defp guardar_zona(repo, zona) do
    if function_exported?(repo, :guardar, 2), do: repo.guardar(:zonas, zona), else: :ok
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
