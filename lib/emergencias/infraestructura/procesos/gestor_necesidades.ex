defmodule Emergencias.Infraestructura.Procesos.GestorNecesidades do
  @moduledoc """
  GenServer para la administración de necesidades humanitarias y control de transiciones de estado.
  Evita doble cierre y serializa modificaciones de necesidades.
  Implementa el puerto de salida PuertoSalidaNecesidades.
  """

  use GenServer

  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaNecesidades

  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Necesidad
  alias Emergencias.Dominio.Reglas.{TransicionesEstado, Validaciones}
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de necesidades.
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
  Definir la especificación de supervisión para el gestor de necesidades.
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
  Registrar una nueva necesidad.
  """
  @spec registrar_necesidad(map(), String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def registrar_necesidad(params, usuario) do
    GenServer.call(__MODULE__, {:registrar, params, usuario})
  end

  @impl true
  @doc "Implementación del puerto: registrar necesidad."
  @spec registrar(map(), String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def registrar(params, usuario), do: registrar_necesidad(params, usuario)

  @impl true
  @doc "Implementación del puerto: consultar necesidad por identificador."
  @spec consultar(String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}
  def consultar(id_necesidad) do
    GenServer.call(__MODULE__, {:consultar, id_necesidad})
  end

  @impl true
  @doc """
  Actualizar el estado de una necesidad previa validación de grafo y cierre.
  """
  @spec actualizar_estado(String.t(), atom(), String.t()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def actualizar_estado(id_necesidad, nuevo_estado, usuario) do
    GenServer.call(__MODULE__, {:actualizar, id_necesidad, nuevo_estado, usuario})
  end

  @impl true
  @doc "Implementación del puerto: asignar suministros a una necesidad."
  @spec asignar_suministro(String.t(), pos_integer(), String.t()) ::
          {:ok, Necesidad.t()} | {:error, atom()}
  def asignar_suministro(id_necesidad, cantidad, usuario) do
    GenServer.call(__MODULE__, {:asignar_suministro, id_necesidad, cantidad, usuario})
  end

  @doc """
  Listar necesidades aplicando filtros.
  """
  @spec listar_necesidades(keyword()) :: {:ok, list(Necesidad.t())}
  def listar_necesidades(filtros \\ []) do
    GenServer.call(__MODULE__, {:listar, filtros})
  end

  @impl true
  @doc "Implementación del puerto: listar necesidades."
  @spec listar(keyword()) :: {:ok, list(Necesidad.t())}
  def listar(filtros \\ []), do: listar_necesidades(filtros)

  @doc """
  Recargar necesidades desde persistencia en disco.
  """
  @spec recargar_datos() :: :ok
  def recargar_datos do
    GenServer.call(__MODULE__, :recargar)
  end

  # Callbacks OTP
  @impl true
  def init(opciones) do
    inicializar_gestor(opciones)
  end

  @impl true
  def handle_call(:recargar, _from, _estado) do
    {:ok, nuevo_estado} = inicializar_gestor([])
    {:reply, :ok, nuevo_estado}
  end

  @impl true
  def handle_call({:registrar, params, usuario}, _from, estado) do
    ejecutar_registro(params, usuario, estado)
  end

  @impl true
  def handle_call({:consultar, id_necesidad}, _from, estado) do
    ejecutar_consulta(id_necesidad, estado)
  end

  @impl true
  def handle_call({:actualizar, id_necesidad, nuevo_estado, usuario}, _from, estado) do
    ejecutar_actualizacion(id_necesidad, nuevo_estado, usuario, estado)
  end

  @impl true
  def handle_call({:asignar_suministro, id_necesidad, cantidad, usuario}, _from, estado) do
    ejecutar_asignacion_suministro(id_necesidad, cantidad, usuario, estado)
  end

  @impl true
  def handle_call({:listar, filtros}, _from, estado) do
    ejecutar_listado(filtros, estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando necesidades desde disco a memoria.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, necesidades} = MotorPersistencia.cargar(:necesidades)
    mapa = Map.new(necesidades, fn n -> {String.upcase(n.id), n} end)
    {:ok, %{necesidades: mapa}}
  end

  @doc """
  Ejecutar el registro seguro de una necesidad con id secuencial.
  """
  @spec ejecutar_registro(map(), String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, atom()}, map()}
  def ejecutar_registro(params, usuario, estado) do
    with {:ok, validados} <- Validaciones.validar_entrada_necesidad(params) do
      nuevo_id = GeneradorId.formatear_id(:necesidad, map_size(estado.necesidades) + 1)
      fecha = Reloj.obtener_fecha_actual()

      {:ok, nueva_nec} =
        Necesidad.construir(%{
          id: nuevo_id,
          codigo_zona: validados.codigo_zona,
          tipo_recurso: validados.tipo_recurso,
          cantidad_solicitada: validados.cantidad_solicitada,
          cantidad_asignada: 0,
          prioridad: validados.prioridad,
          estado: :pendiente,
          fecha_registro: fecha,
          usuario_reporta: usuario,
          descripcion: Map.get(validados, :descripcion, "")
        })

      MotorPersistencia.guardar(:necesidades, nueva_nec)
      nuevas = Map.put(estado.necesidades, String.upcase(nuevo_id), nueva_nec)
      {:reply, {:ok, nueva_nec}, %{estado | necesidades: nuevas}}
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar la transición de estado garantizando que no se cierre dos veces.
  """
  @spec ejecutar_actualizacion(String.t(), atom(), String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, atom()}, map()}
  def ejecutar_actualizacion(id_necesidad, nuevo_estado, usuario, estado) do
    clave = String.upcase(id_necesidad)

    case Map.get(estado.necesidades, clave) do
      nil ->
        {:reply, {:error, :necesidad_no_encontrada}, estado}

      %Necesidad{} = nec ->
        fecha = Reloj.obtener_fecha_actual()

        case TransicionesEstado.transitar_necesidad(nec, nuevo_estado, usuario, fecha) do
          {:ok, transitada} ->
            MotorPersistencia.guardar(:necesidades, transitada)
            nuevas = Map.put(estado.necesidades, clave, transitada)
            {:reply, {:ok, transitada}, %{estado | necesidades: nuevas}}

          {:error, razon} ->
            {:reply, {:error, razon}, estado}
        end
    end
  end

  @doc """
  Ejecutar la consulta de una necesidad por su identificador.
  """
  @spec ejecutar_consulta(String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, :necesidad_no_encontrada}, map()}
  def ejecutar_consulta(id_necesidad, estado) do
    clave = String.upcase(id_necesidad)

    case Map.get(estado.necesidades, clave) do
      nil -> {:reply, {:error, :necesidad_no_encontrada}, estado}
      %Necesidad{} = nec -> {:reply, {:ok, nec}, estado}
    end
  end

  @doc """
  Ejecutar la asignación de suministros a una necesidad actualizando cantidad asignada y estado.
  """
  @spec ejecutar_asignacion_suministro(String.t(), pos_integer(), String.t(), map()) ::
          {:reply, {:ok, Necesidad.t()} | {:error, atom()}, map()}
  def ejecutar_asignacion_suministro(id_necesidad, cantidad, usuario, estado) do
    clave = String.upcase(id_necesidad)

    case Map.get(estado.necesidades, clave) do
      nil ->
        {:reply, {:error, :necesidad_no_encontrada}, estado}

      %Necesidad{} = nec ->
        cond do
          nec.estado == :atendida ->
            {:reply, {:error, :necesidad_ya_atendida}, estado}

          nec.estado == :cancelada ->
            {:reply, {:error, :necesidad_cancelada}, estado}

          true ->
            pendiente = nec.cantidad_solicitada - nec.cantidad_asignada

            if cantidad > pendiente do
              {:reply, {:error, :cantidad_excede_necesidad}, estado}
            else
              nueva_asignada = nec.cantidad_asignada + cantidad
              nuevo_estado = if nueva_asignada >= nec.cantidad_solicitada, do: :atendida, else: :asignada
              fecha = Reloj.obtener_fecha_actual()

              evento = %{
                fecha: fecha,
                estado_anterior: nec.estado,
                estado_nuevo: nuevo_estado,
                usuario: usuario
              }

              actualizada = %{
                nec
                | cantidad_asignada: nueva_asignada,
                  estado: nuevo_estado,
                  historial: [evento | nec.historial]
              }

              MotorPersistencia.guardar(:necesidades, actualizada)
              nuevas = Map.put(estado.necesidades, clave, actualizada)
              {:reply, {:ok, actualizada}, %{estado | necesidades: nuevas}}
            end
        end
    end
  end

  @doc """
  Ejecutar el filtrado y listado de necesidades en memoria.
  """
  @spec ejecutar_listado(keyword(), map()) :: {:reply, {:ok, list(Necesidad.t())}, map()}
  def ejecutar_listado(filtros, estado) do
    lista = Map.values(estado.necesidades)
    resultado = filtrar_lista(lista, filtros)
    {:reply, {:ok, resultado}, estado}
  end

  defp filtrar_lista(lista, []), do: lista

  defp filtrar_lista(lista, [{:zona, z} | resto]) do
    lista
    |> Enum.filter(fn n -> String.downcase(n.codigo_zona) == String.downcase(to_string(z)) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [{:prioridad, p} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.prioridad) == to_string(p) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [{:estado, e} | resto]) do
    lista
    |> Enum.filter(fn n -> to_string(n.estado) == to_string(e) end)
    |> filtrar_lista(resto)
  end

  defp filtrar_lista(lista, [_ | resto]), do: filtrar_lista(lista, resto)
end
