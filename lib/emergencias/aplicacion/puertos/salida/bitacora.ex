defmodule Emergencias.Aplicacion.Puertos.Salida.Bitacora do
  @moduledoc """
  Puerto de salida para auditoría y registro de actividad de los usuarios.
  """

  @callback registrar_actividad(String.t(), String.t(), String.t(), String.t()) :: :ok
end
