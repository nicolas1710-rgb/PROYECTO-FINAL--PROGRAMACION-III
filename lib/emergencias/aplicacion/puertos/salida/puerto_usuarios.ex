defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoUsuarios do
  @moduledoc "Puerto de salida para autenticacion y gestion de usuarios."
  @callback conectar(String.t(), String.t(), atom()) :: {:ok, struct()} | {:error, atom()}
  @callback desconectar(String.t()) :: :ok
  @callback listar() :: [struct()]
end
