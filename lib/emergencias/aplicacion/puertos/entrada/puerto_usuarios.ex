defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoUsuarios do
  @moduledoc """
  Contrato del caso de uso de gestión de sesiones y usuarios.
  """

  alias Emergencias.Dominio.Modelos.Usuario

  @callback conectar(String.t(), String.t(), atom()) :: {:ok, Usuario.t()} | {:error, atom()}
  @callback desconectar(String.t()) :: :ok | {:error, atom()}
end
