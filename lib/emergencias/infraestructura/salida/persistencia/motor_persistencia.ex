defmodule Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia do
  @moduledoc """
  GenServer encargado exclusivo de sincronizar y escribir de forma atómica en disco.
  Utiliza archivos temporales con renombrado atómico para prevenir corrupción por concurrencia.
  """

  use GenServer

  alias Emergencias.Infraestructura.Salida.Persistencia.CodificadorTexto

  @archivos %{
    usuarios: "usuarios.txt",
    zonas: "zonas.txt",
    necesidades: "necesidades.txt",
    recursos: "recursos.txt",
    movimientos: "movimientos.txt",
    personas: "personas.txt",
    mensajes: "mensajes.txt",
    mascotas: "mascotas.txt",
    albergues: "albergues.txt",
    actividad: "actividad.txt"
  }

  @doc """
  Iniciar el proceso de persistencia coordinado envolviendo start_link.
  """
  @spec iniciar(keyword()) :: {:ok, pid()} | {:error, any()}
  def iniciar(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  @doc """
  Callback exigido por supervisión OTP; delega a iniciar/1.
  """
  def start_link(opciones \\ []), do: iniciar(opciones)

  @doc """
  Especificación de supervisión OTP; delega a definir_especificacion/1.
  """
  def child_spec(opciones), do: definir_especificacion(opciones)

  @doc """
  Definir especificación de supervisión para el motor de persistencia.
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
  Guardar una lista completa de entidades o actualizar una entidad.
  """
  @spec guardar(atom(), list(struct()) | struct()) :: :ok | {:error, atom()}
  def guardar(entidad, registros) do
    GenServer.call(__MODULE__, {:guardar, entidad, registros})
  end

  @doc """
  Anexar un registro histórico de forma append-only verificando escritura segura.
  """
  @spec anexar(atom(), struct()) :: :ok | {:error, atom()}
  def anexar(entidad, registro) do
    GenServer.call(__MODULE__, {:anexar, entidad, registro})
  end

  @doc """
  Cargar todos los registros de una entidad desde el archivo correspondiente.
  """
  @spec cargar(atom(), String.t() | nil) :: {:ok, list(struct())}
  def cargar(entidad, dir_personalizado \\ nil) do
    directorio = dir_personalizado || obtener_directorio()
    leer_archivo(directorio, entidad)
  end

  # Callbacks OTP obligatorios que delegan inmediatamente a funciones en infinitivo
  @impl true
  def init(opciones) do
    inicializar_estado(opciones)
  end

  @impl true
  def handle_call({:guardar, entidad, registros}, _from, estado) do
    ejecutar_guardado(entidad, registros, estado)
  end

  @impl true
  def handle_call({:anexar, entidad, registro}, _from, estado) do
    ejecutar_anexo(entidad, registro, estado)
  end

  # Funciones propias con verbos en infinitivo
  @doc """
  Inicializar el estado del motor de persistencia asegurando el directorio de datos.
  """
  @spec inicializar_estado(keyword()) :: {:ok, map()}
  def inicializar_estado(opciones) do
    dir = Keyword.get(opciones, :directorio, obtener_directorio())
    File.mkdir_p!(dir)
    {:ok, %{directorio: dir}}
  end

  @doc """
  Ejecutar el guardado atómico de registros mediante archivo temporal y renombrado.
  """
  @spec ejecutar_guardado(atom(), list(struct()) | struct(), map()) ::
          {:reply, :ok | {:error, atom()}, map()}
  def ejecutar_guardado(entidad, registro_unico, estado) when not is_list(registro_unico) do
    directorio_actual = obtener_directorio()
    {:ok, existentes} = leer_archivo(directorio_actual, entidad)
    id_objetivo = Map.get(registro_unico, :id) || Map.get(registro_unico, :documento)

    nuevos =
      if id_objetivo do
        sin_actual = Enum.reject(existentes, fn r ->
          (Map.get(r, :id) || Map.get(r, :documento)) == id_objetivo
        end)
        [registro_unico | sin_actual]
      else
        [registro_unico | existentes]
      end

    ejecutar_guardado(entidad, nuevos, estado)
  end

  def ejecutar_guardado(entidad, registros, estado) when is_list(registros) do
    directorio_actual = obtener_directorio()
    File.mkdir_p!(directorio_actual)
    resultado = escribir_registros_seguro(directorio_actual, entidad, registros)
    {:reply, resultado, %{estado | directorio: directorio_actual}}
  end

  @doc """
  Ejecutar anexo append-only al final del archivo correspondiente.
  """
  @spec ejecutar_anexo(atom(), struct(), map()) :: {:reply, :ok | {:error, atom()}, map()}
  def ejecutar_anexo(entidad, registro, estado) do
    directorio_actual = obtener_directorio()
    File.mkdir_p!(directorio_actual)
    nombre_archivo = Map.get(@archivos, entidad, "#{entidad}.txt")
    ruta = Path.join(directorio_actual, nombre_archivo)

    resultado =
      with {:ok, linea} <- CodificadorTexto.codificar(registro),
           :ok <- File.write(ruta, linea <> "\n", [:append]) do
        :ok
      else
        error -> error
      end

    {:reply, resultado, %{estado | directorio: directorio_actual}}
  end

  @doc """
  Escribir de forma atómica una lista de structs convirtiéndolos a texto plano.
  """
  @spec escribir_registros_seguro(String.t(), atom(), list(struct())) :: :ok | {:error, atom()}
  def escribir_registros_seguro(directorio, entidad, registros) do
    nombre_archivo = Map.get(@archivos, entidad, "#{entidad}.txt")
    ruta_final = Path.join(directorio, nombre_archivo)
    ruta_temporal = Path.join(directorio, "#{nombre_archivo}.tmp")

    lineas =
      registros
      |> Enum.map(&CodificadorTexto.codificar/1)
      |> Enum.map(fn {:ok, l} -> l <> "\n" end)

    with :ok <- File.write(ruta_temporal, lineas),
         :ok <- File.rename(ruta_temporal, ruta_final) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Leer y decodificar registros contenidos en el archivo tolerando líneas corruptas.
  """
  @spec leer_archivo(String.t(), atom()) :: {:ok, list(struct())}
  def leer_archivo(directorio, entidad) do
    nombre_archivo = Map.get(@archivos, entidad, "#{entidad}.txt")
    ruta = Path.join(directorio, nombre_archivo)

    if File.exists?(ruta) do
      registros =
        ruta
        |> File.stream!()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.flat_map(fn linea ->
          case CodificadorTexto.decodificar(linea, entidad) do
            {:ok, struct} -> [struct]
            _ -> []
          end
        end)

      {:ok, registros}
    else
      {:ok, []}
    end
  end

  defp obtener_directorio do
    Application.get_env(:emergencias, :directorio_datos, "datos")
  end
end
