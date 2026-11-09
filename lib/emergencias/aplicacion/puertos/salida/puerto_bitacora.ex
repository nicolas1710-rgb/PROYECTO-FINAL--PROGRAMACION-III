defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoBitacora do
  @moduledoc "Puerto de salida para auditoria y bitacora de actividades."
  @callback registrar_actividad(String.t(), String.t(), String.t(), String.t()) :: :ok
  @callback consultar_por_usuario(String.t()) :: [tuple()]
end
