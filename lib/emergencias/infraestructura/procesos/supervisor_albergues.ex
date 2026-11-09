defmodule Emergencias.Infraestructura.Procesos.SupervisorAlbergues do
  @moduledoc "DynamicSupervisor para procesos concurrentes de albergues y puerto de salida."
  use DynamicSupervisor
  @behaviour Emergencias.Aplicacion.Puertos.Salida.PuertoAlbergues

  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Dominio.Reglas.Identificadores
  alias Emergencias.Infraestructura.Procesos.Albergue, as: ProcesoAlbergue
  alias Emergencias.Infraestructura.Salida.AlmacenArchivo

  @registro Emergencias.RegistroAlbergues

  def iniciar(opts \\ []), do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  def start_link(opts \\ []), do: iniciar(opts)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :iniciar, [opts]}, type: :supervisor}

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  @impl true
  def registrar(p) do
    existentes = AlmacenArchivo.cargar(:albergues)
    id = Map.get(p, :id) || Identificadores.generar("ALB", length(existentes))
    fecha = DateTime.utc_now() |> DateTime.to_iso8601()
    {:ok, alb} = Albergue.construir(Map.merge(p, %{id: id, fecha_registro: fecha}))
    nuevos = [alb | Enum.reject(existentes, &(&1.id == id))]
    AlmacenArchivo.guardar(:albergues, nuevos)
    DynamicSupervisor.start_child(__MODULE__, {ProcesoAlbergue, alb})
    {:ok, alb}
  end

  @impl true
  def consultar(id), do: pedir_al_proceso(id, :consultar)
  @impl true
  def ingresar(id, doc), do: pedir_al_proceso(id, {:ingresar, doc})
  @impl true
  def salir(id, doc), do: pedir_al_proceso(id, {:salir, doc})
  @impl true
  def vincular_recurso(id, r_id), do: pedir_al_proceso(id, {:vincular_recurso, r_id})
  @impl true
  def vincular_necesidad(id, n_id), do: pedir_al_proceso(id, {:vincular_necesidad, n_id})

  @impl true
  def listar do
    AlmacenArchivo.cargar(:albergues)
    |> Enum.map(fn a ->
      case consultar(a.id) do
        {:ok, en_vivo} -> en_vivo
        _ -> a
      end
    end)
  end

  @doc "Actualizar el albergue persistido en disco al cambiar su ocupacion o vinculos."
  def actualizar_en_memoria(%Albergue{} = alb) do
    existentes = AlmacenArchivo.cargar(:albergues)
    nuevos = [alb | Enum.reject(existentes, &(&1.id == alb.id))]
    AlmacenArchivo.guardar(:albergues, nuevos)
  end

  defp pedir_al_proceso(id, peticion) do
    case Registry.lookup(@registro, id) do
      [{pid, _}] ->
        msg = case peticion do
          :consultar -> {:consultar, self()}
          {tipo, arg} -> {tipo, arg, self()}
        end
        send(pid, msg)
        receive do
          {:ok, resp} -> {:ok, resp}
          {:error, razon} -> {:error, razon}
        after
          1000 -> {:error, :tiempo_espera_agotado}
        end
      [] -> {:error, :albergue_no_encontrado}
    end
  end
end
