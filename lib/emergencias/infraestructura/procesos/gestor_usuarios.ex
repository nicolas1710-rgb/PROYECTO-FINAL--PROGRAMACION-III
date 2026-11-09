defmodule Emergencias.Infraestructura.Procesos.GestorUsuarios do
  @moduledoc """
  GenServer para la administración de usuarios, credenciales y sesiones concurrentes en memoria.
  """

  use GenServer

  alias Emergencias.Aplicacion.CasosUso.GestionarUsuarios
  alias Emergencias.Aplicacion.Puertos.Salida.{GeneradorId, Reloj}
  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.Validaciones
  alias Emergencias.Infraestructura.Salida.Persistencia.MotorPersistencia

  @doc """
  Iniciar el GenServer de usuarios.
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
  Definir la especificación de supervisión para el gestor de usuarios.
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
  Conectar un usuario; si no existe, lo registra automáticamente con clave cifrada.
  """
  @spec conectar(String.t(), String.t(), atom()) :: {:ok, Usuario.t()} | {:error, atom()}
  def conectar(nombre, clave, rol \\ :ciudadano) do
    GenServer.call(__MODULE__, {:conectar, nombre, clave, rol})
  end

  @doc """
  Cerrar la sesión de un usuario.
  """
  @spec desconectar(String.t()) :: :ok
  def desconectar(nombre) do
    GenServer.call(__MODULE__, {:desconectar, nombre})
  end

  @doc """
  Consultar todos los usuarios en memoria.
  """
  @spec listar_usuarios() :: {:ok, list(Usuario.t())}
  def listar_usuarios do
    GenServer.call(__MODULE__, :listar)
  end

  # Callbacks OTP
  @impl true
  def init(opciones) do
    inicializar_gestor(opciones)
  end

  @impl true
  def handle_call({:conectar, nombre, clave, rol}, _from, estado) do
    ejecutar_conexion(nombre, clave, rol, estado)
  end

  @impl true
  def handle_call({:desconectar, nombre}, _from, estado) do
    ejecutar_desconexion(nombre, estado)
  end

  @impl true
  def handle_call(:listar, _from, estado) do
    responder_listado(estado)
  end

  # Funciones con verbos en infinitivo
  @doc """
  Inicializar el estado cargando usuarios desde disco a memoria.
  """
  @spec inicializar_gestor(keyword()) :: {:ok, map()}
  def inicializar_gestor(_opciones) do
    {:ok, usuarios} = MotorPersistencia.cargar(:usuarios)
    mapa = Map.new(usuarios, fn u -> {String.downcase(u.nombre), u} end)
    {:ok, %{usuarios: mapa, sesiones: MapSet.new()}}
  end

  @doc """
  Ejecutar el proceso de autenticación o registro automático.
  """
  @spec ejecutar_conexion(String.t(), String.t(), atom(), map()) ::
          {:reply, {:ok, Usuario.t()} | {:error, atom()}, map()}
  def ejecutar_conexion(nombre, clave, rol, estado) do
    with {:ok, nom_valido} <- Validaciones.validar_texto_no_vacio(nombre),
         {:ok, clave_valida} <- Validaciones.validar_texto_no_vacio(clave),
         {:ok, rol_valido} <- Validaciones.validar_rol(rol) do
      clave = String.downcase(nom_valido)
      hash = GestionarUsuarios.calcular_hash_clave(clave_valida)
      fecha = Reloj.obtener_fecha_actual()

      case Map.get(estado.usuarios, clave) do
        nil ->
          registrar_nuevo_usuario(nom_valido, hash, rol_valido, fecha, estado)

        %Usuario{} = existente ->
          autenticar_usuario(existente, hash, estado)
      end
    else
      error -> {:reply, error, estado}
    end
  end

  @doc """
  Ejecutar el cierre de sesión de un usuario.
  """
  @spec ejecutar_desconexion(String.t(), map()) :: {:reply, :ok, map()}
  def ejecutar_desconexion(nombre, estado) do
    sesiones = MapSet.delete(estado.sesiones, String.downcase(nombre))
    {:reply, :ok, %{estado | sesiones: sesiones}}
  end

  @doc """
  Responder la lista de usuarios en memoria.
  """
  @spec responder_listado(map()) :: {:reply, {:ok, list(Usuario.t())}, map()}
  def responder_listado(estado) do
    {:reply, {:ok, Map.values(estado.usuarios)}, estado}
  end

  defp registrar_nuevo_usuario(nombre, hash, rol, fecha, estado) do
    nuevo_id = GeneradorId.formatear_id(:usuario, map_size(estado.usuarios) + 1)

    {:ok, usuario} =
      Usuario.construir(%{
        id: nuevo_id,
        nombre: nombre,
        rol: rol,
        clave_hash: hash,
        fecha_registro: fecha
      })

    MotorPersistencia.guardar(:usuarios, usuario)
    nuevos_usuarios = Map.put(estado.usuarios, String.downcase(nombre), usuario)
    nuevas_sesiones = MapSet.put(estado.sesiones, String.downcase(nombre))

    {:reply, {:ok, usuario}, %{estado | usuarios: nuevos_usuarios, sesiones: nuevas_sesiones}}
  end

  defp autenticar_usuario(existente, hash, estado) do
    if existente.clave_hash == hash do
      nuevas_sesiones = MapSet.put(estado.sesiones, String.downcase(existente.nombre))
      {:reply, {:ok, existente}, %{estado | sesiones: nuevas_sesiones}}
    else
      {:reply, {:error, :clave_incorrecta}, estado}
    end
  end
end
