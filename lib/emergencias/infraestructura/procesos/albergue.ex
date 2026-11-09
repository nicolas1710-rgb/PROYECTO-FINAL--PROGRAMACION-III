defmodule Emergencias.Infraestructura.Procesos.Albergue do
  @moduledoc "Proceso concurrente puro sin GenServer con bucle receive recursivo."

  alias Emergencias.Dominio.Modelos.Albergue
  alias Emergencias.Dominio.Reglas.Ocupacion

  @registro Emergencias.RegistroAlbergues

  def child_spec(albergue) do
    %{id: {:albergue, albergue.id}, start: {__MODULE__, :iniciar, [albergue]}, restart: :transient, type: :worker}
  end

  def iniciar(%Albergue{} = alb) do
    padre = self()
    pid = spawn_link(fn ->
      Registry.register(@registro, alb.id, alb)
      send(padre, {:registrado, self()})
      bucle(alb)
    end)
    receive do {:registrado, ^pid} -> {:ok, pid} after 1000 -> {:ok, pid} end
  end

  def bucle(%Albergue{} = alb) do
    receive do
      {:ingresar, doc, from} ->
        case Ocupacion.ingresar_persona(alb, doc) do
          {:ok, alb_act} ->
            sincronizar(alb_act)
            send(from, {:ok, alb_act})
            bucle(alb_act)
          error ->
            send(from, error)
            bucle(alb)
        end

      {:salir, doc, from} ->
        case Ocupacion.retirar_persona(alb, doc) do
          {:ok, alb_act} ->
            sincronizar(alb_act)
            send(from, {:ok, alb_act})
            bucle(alb_act)
          error ->
            send(from, error)
            bucle(alb)
        end

      {:vincular_recurso, r_id, from} ->
        recs = Map.update(alb.recursos_asignados, r_id, 1, &(&1 + 1))
        alb_act = %{alb | recursos_asignados: recs}
        sincronizar(alb_act)
        send(from, {:ok, alb_act})
        bucle(alb_act)

      {:vincular_necesidad, n_id, from} ->
        necs = if n_id in alb.necesidades_asociadas, do: alb.necesidades_asociadas, else: [n_id | alb.necesidades_asociadas]
        alb_act = %{alb | necesidades_asociadas: necs}
        sincronizar(alb_act)
        send(from, {:ok, alb_act})
        bucle(alb_act)

      {:consultar, from} ->
        send(from, {:ok, alb})
        bucle(alb)
    end
  end

  defp sincronizar(alb) do
    Emergencias.Infraestructura.Procesos.SupervisorAlbergues.actualizar_en_memoria(alb)
  end
end
