defmodule Emergencias.Aplicacion.Puertos.Salida.Reloj do
  @moduledoc """
  Puerto de salida para la obtención de la fecha y hora actual en formato ISO8601.
  """

  @callback obtener_fecha_actual() :: String.t()

  @doc """
  Obtener la fecha y hora UTC actual en formato estándar ISO8601.
  """
  @spec obtener_fecha_actual() :: String.t()
  def obtener_fecha_actual do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  @doc """
  Alias explícito para obtención en UTC.
  """
  @spec obtener_fecha_utc() :: String.t()
  def obtener_fecha_utc, do: obtener_fecha_actual()
end
