defmodule Emergencias.Aplicacion.Puertos.Salida.GeneradorId do
  @moduledoc """
  Puerto de salida para generar identificadores con prefijo canónico secuencial o formateado.
  """

  @callback generar_id(atom(), non_neg_integer()) :: String.t()

  @doc """
  Generar un identificador formateado con prefijo y relleno de ceros.
  """
  @spec formatear_id(atom(), non_neg_integer()) :: String.t()
  def formatear_id(:necesidad, secuencia), do: "N" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:persona, secuencia), do: "P" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:mensaje, secuencia), do: "M" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:mascota, secuencia), do: "MC" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:zona, secuencia), do: "Z" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:recurso, secuencia), do: "R" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:albergue, secuencia), do: "ALB" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:movimiento, secuencia), do: "MOV" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:usuario, secuencia), do: "U" <> rellenar_ceros(secuencia, 3)
  def formatear_id(:actividad, secuencia), do: "ACT" <> rellenar_ceros(secuencia, 3)
  def formatear_id(_tipo, secuencia), do: "ID" <> rellenar_ceros(secuencia, 3)

  defp rellenar_ceros(numero, ancho) do
    numero
    |> to_string()
    |> String.pad_leading(ancho, "0")
  end
end
