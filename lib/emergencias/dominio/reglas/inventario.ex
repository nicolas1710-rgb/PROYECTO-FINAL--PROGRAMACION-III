defmodule Emergencias.Dominio.Reglas.Inventario do
  @moduledoc "Operaciones puras sobre inventario de recursos y generacion de movimientos."

  alias Emergencias.Dominio.Modelos.{Movimiento, Recurso}
  alias Emergencias.Dominio.Reglas.Identificadores

  @doc "Agregar stock a un lote de recursos generando su movimiento de entrada."
  def agregar(%Recurso{} = rec, cant, u, fecha) when cant > 0 do
    rec_act = %{rec | cantidad_total: rec.cantidad_total + cant, cantidad_disponible: rec.cantidad_disponible + cant}
    mov = %Movimiento{id: Identificadores.generar("MOV", 0), codigo_recurso: rec.id, tipo: :entrada, cantidad: cant, origen: "Ingreso", destino: rec.ubicacion, usuario: u, fecha: fecha}
    {:ok, rec_act, mov}
  end

  @doc "Descontar stock disponible validando existencias suficientes."
  def descontar(%Recurso{} = rec, cant, u, fecha) when cant > 0 do
    if rec.cantidad_disponible >= cant do
      rec_act = %{rec | cantidad_total: rec.cantidad_total - cant, cantidad_disponible: rec.cantidad_disponible - cant}
      mov = %Movimiento{id: Identificadores.generar("MOV", 0), codigo_recurso: rec.id, tipo: :salida, cantidad: cant, origen: rec.ubicacion, destino: "Salida", usuario: u, fecha: fecha}
      {:ok, rec_act, mov}
    else
      {:error, :stock_insuficiente}
    end
  end

  @doc "Transferir stock entre dos recursos o ubicaciones de forma pura."
  def transferir(%Recurso{} = o, %Recurso{} = d, cant, u, fecha) when cant > 0 do
    if o.cantidad_disponible >= cant do
      o_act = %{o | cantidad_disponible: o.cantidad_disponible - cant}
      d_act = %{d | cantidad_total: d.cantidad_total + cant, cantidad_disponible: d.cantidad_disponible + cant}
      mov_o = %Movimiento{id: Identificadores.generar("MOV", 1), codigo_recurso: o.id, tipo: :transferencia_origen, cantidad: cant, origen: o.ubicacion, destino: d.ubicacion, usuario: u, fecha: fecha}
      mov_d = %Movimiento{id: Identificadores.generar("MOV", 2), codigo_recurso: d.id, tipo: :transferencia_destino, cantidad: cant, origen: o.ubicacion, destino: d.ubicacion, usuario: u, fecha: fecha}
      {:ok, o_act, d_act, [mov_o, mov_d]}
    else
      {:error, :stock_insuficiente}
    end
  end
end
