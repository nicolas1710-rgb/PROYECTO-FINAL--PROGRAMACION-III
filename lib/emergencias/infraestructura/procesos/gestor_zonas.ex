defmodule Emergencias.Infraestructura.Procesos.GestorZonas do
  @moduledoc """
  GenServer para la administración concurrente y consulta de zonas territoriales.
  """

  use GenServer

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Zona
  alias Emergencias.Dominio.Reglas.Validaciones
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de zonas.
  """
  @spec iniciar(keyword()) :: {:ok, pid()} | {:error, any()}
  def iniciar(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Callback exigido por OTP; delega a iniciar/1.
  """
  def start_link(opciones \\ []), do: iniciar(opciones)

  @doc """
  Especificación de supervisión OTP; delega a definir_especificacion/1.
  """
  def child_spec(opciones), do: definir_especificacion(opciones)

  @doc """
  Definir la especificación de supervisión para el gestor de zonas.
  """
  @spec definir_especificacion(keyword()) :: map()
  def definir_especificacion(opciones) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :iniciar, [opciones]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Registrar una nueva zona en el catálogo.
  """
  @spec registrar_zona(map()) :: {:ok, Zona.t()} | {:error, atom()}
  def registrar_zona(params) do
    GenServer.call(__MODULE__, {:registrar_zona, params})
  end

  @doc """
  Consultar una zona por su código identificador.
  """
  @spec consultar_zona(String.t()) :: {:ok, Zona.t()} | {:error, :zona_no_encontrada}
  def consultar_zona(id_zona) do
    GenServer.call(__MODULE__, {:consultar_zona, id_zona})
  end

  @doc """
  Listar todas las zonas en memoria.
  """
  @spec listar_zonas() :: {:ok, list(Zona.t())}
  def listar_zonas do
    GenServer.call(__MODULE__, :listar_zonas)
  end

  # Callbacks OTP
  @impl true
  def init(opciones) do
    inicializar_gestor(opciones)
  end

  @impl true
  def handle_call({:registrar_zona, params}, _from, estado) do
    ejecutar_registro_zona(params, estado)
  end

  @impl true
  def handle_call({:consultar_zona, id_zona}, _from, estado) do
    ejecutar_consulta_zona(id_zona, estado)
  end

  @impl true
  def handle_call(:listar_zonas, _from, estado) do
    responder_listado(estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando zonas desde disco.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, zonas} = MotorPersistencia.cargar(:zonas)
    mapa = Map.new(zonas, fn z -> {String.upcase(z.id), z} end)
    {:ok, %{zonas: mapa}}
  end

  @doc """
  Ejecutar el registro de una zona garantizando id único secuencial.
  """
  @spec ejecutar_registro_zona(map(), map()) :: {:reply, {:ok, Zona.t()} | {:error, atom()}, map()}
  def ejecutar_registro_zona(params, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_zona(params) do
      nuevo_id = GeneradorId.formatear_id(:zona, map_size(estado.zonas) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nueva_zona} =
        Zona.construir(%{
          id: nuevo_id,
          nombre: validados.nombre,
          nivel_gravedad: validados.nivel_gravedad,
          fecha_registro: fecha,
          sectores: Map.get(params, :sectores, [])
        })

      MotorPersistencia.guardar(:zonas, nueva_zona)
      nuevas_zonas = Map.put(estado.zonas, String.upcase(nuevo_id), nueva_zona)
      {:reply, {:ok, nueva_zona}, %{estado | zonas: nuevas_zonas}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar la consulta de una zona en memoria.
  """
  @spec ejecutar_consulta_zona(String.t(), map()) ::
          {:reply, {:ok, Zona.t()} | {:error, :zona_no_encontrada}, map()}
  def ejecutar_consulta_zona(id_zona, estado) do
    case Map.get(estado.zonas, String.upcase(id_zona)) do
      %Zona{} = z -> {:reply, {:ok, z}, estado}
      nil -> {:reply, {:error, :zona_no_encontrada}, estado}
    end
  end

  @doc """
  Responder la lista de todas las zonas.
  """
  @spec responder_listado(map()) :: {:reply, {:ok, list(Zona.t())}, map()}
  def responder_listado(estado) do
    {:reply, {:ok, Map.values(estado.zonas)}, estado}
  end
end
