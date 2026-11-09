defmodule Emergencias.Dominio.Reglas.Asignacion do
  @moduledoc "Logica pura y atomica de asignacion entre recursos y necesidades."

  alias Emergencias.Dominio.Modelos.Movimiento
  alias Emergencias.Dominio.Reglas.Identificadores

  @doc "Asignar un recurso a una necesidad actualizando el estado logistico de forma atomica."
  def asignar(estado_log, id_rec, id_nec, cantidad, usuario, fecha) do
    with {:ok, nec} <- obtener_necesidad_abierta(estado_log.necesidades, id_nec, cantidad),
         {:ok, rec} <- obtener_recurso_con_stock(estado_log.recursos, id_rec, nec.tipo_recurso, cantidad) do
      ejecutar_asignacion(estado_log, rec, nec, cantidad, usuario, fecha)
    end
  end

  defp obtener_necesidad_abierta(necesidades, id_nec, cantidad) do
    case Map.get(necesidades, id_nec) do
      nil -> {:error, :necesidad_no_encontrada}
      %{estado: est} when est in [:atendida, :cancelada] -> {:error, :necesidad_ya_cerrada}
      nec ->
        pendiente = nec.cantidad_solicitada - nec.cantidad_asignada
        if cantidad <= pendiente, do: {:ok, nec}, else: {:error, :cantidad_excede_necesidad}
    end
  end

  defp obtener_recurso_con_stock(recursos, id_rec, tipo_requerido, cantidad) do
    case Map.get(recursos, id_rec) do
      nil -> {:error, :recurso_no_encontrado}
      rec ->
        cond do
          not compatible?(rec, tipo_requerido) -> {:error, :tipo_recurso_incompatible}
          rec.cantidad_disponible < cantidad -> {:error, :stock_insuficiente}
          true -> {:ok, rec}
        end
    end
  end

  defp compatible?(rec, tipo) do
    norm = fn s -> s |> to_string() |> String.downcase() |> String.trim() end
    norm.(rec.nombre) == norm.(tipo) or norm.(rec.categoria) == norm.(tipo)
  end

  defp ejecutar_asignacion(estado_log, rec, nec, cant, u, fecha) do
    rec_act = %{rec | cantidad_disponible: rec.cantidad_disponible - cant, cantidad_reservada: rec.cantidad_reservada + cant}
    nueva_asig = nec.cantidad_asignada + cant
    nuevo_est = if nueva_asig >= nec.cantidad_solicitada, do: :atendida, else: :asignada
    nec_act = %{nec | cantidad_asignada: nueva_asig, estado: nuevo_est, historial: [{fecha, nec.estado, nuevo_est, u} | nec.historial]}
    mov_id = Identificadores.generar("MOV", length(estado_log.movimientos))
    mov = %Movimiento{id: mov_id, codigo_recurso: rec.id, tipo: :asignacion, cantidad: cant, origen: rec.ubicacion, destino: "Necesidad:#{nec.id}", usuario: u, fecha: fecha}

    nuevo_estado = %{
      estado_log |
      recursos: Map.put(estado_log.recursos, rec.id, rec_act),
      necesidades: Map.put(estado_log.necesidades, nec.id, nec_act),
      movimientos: [mov | estado_log.movimientos]
    }
    {:ok, nuevo_estado, {rec_act, nec_act, mov}}
  end
end
