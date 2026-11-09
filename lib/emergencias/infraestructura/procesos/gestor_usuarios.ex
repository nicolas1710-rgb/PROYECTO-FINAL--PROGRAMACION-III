defmodule Emergencias.Infraestructura.Procesos.GestorUsuarios do
  @moduledoc "GenServer para autenticacion y registro de usuarios concurrentes."
  use GenServer
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoUsuarios

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.Identificadores
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  @sal "emergencias_uq_2026_"

  @doc "Iniciar el gestor de usuarios."
  def iniciar(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :worker}

  # Implementacion de callbacks del puerto de salida
  @impl true
  def conectar(nom, clave, rol), do: GenServer.call(__MODULE__, {:conectar, nom, clave, rol})
  @impl true
  def desconectar(nom), do: GenServer.call(__MODULE__, {:desconectar, nom})
  @impl true
  def listar, do: GenServer.call(__MODULE__, :listar)

  # Callbacks OTP
  @impl true
  def init(_opts) do
    lista = AlmacenArchivo.cargar(:usuarios)
    mapa = Map.new(lista, fn u -> {u.nombre, u} end)
    {:ok, mapa}
  end

  @impl true
  def handle_call({:conectar, nom, clave, rol}, _from, st), do: ejecutar_conexion(nom, clave, rol, st)
  @impl true
  def handle_call({:desconectar, _nom}, _from, st), do: {:reply, :ok, st}
  @impl true
  def handle_call(:listar, _from, st), do: {:reply, Map.values(st), st}

  defp ejecutar_conexion(nom, clave, rol, st) do
    hash = calcular_hash(clave)

    case Map.get(st, nom) do
      nil ->
        id = Identificadores.generar("U", map_size(st))
        fecha = DateTime.utc_now() |> DateTime.to_iso8601()
        {:ok, u} = Usuario.construir(%{id: id, nombre: nom, rol: rol, clave_hash: hash, fecha_registro: fecha})
        nuevo_st = Map.put(st, nom, u)
        AlmacenArchivo.guardar(:usuarios, Map.values(nuevo_st))
        {:reply, {:ok, u}, nuevo_st}

      %Usuario{clave_hash: ^hash} = u ->
        {:reply, {:ok, u}, st}

      _ ->
        {:reply, {:error, :clave_incorrecta}, st}
    end
  end

  defp calcular_hash(clave) do
    :crypto.hash(:sha256, @sal <> clave) |> Base.encode16(case: :lower)
  end
end
