defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoAlbergues do
  @moduledoc """
  Contrato del caso de uso de administración de albergues y control de ocupación.
  """

  alias Emergencias.Dominio.Modelos.Albergue

  @callback registrar_albergue(map(), struct(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  @callback consultar_albergue(String.t(), struct(), keyword()) :: {:ok, Albergue.t()} | {:error, atom()}
  @callback registrar_entrada(String.t(), String.t(), struct(), keyword()) ::
              {:ok, Albergue.t()} | {:error, atom()}
  @callback registrar_salida(String.t(), String.t(), struct(), keyword()) ::
              {:ok, Albergue.t()} | {:error, atom()}
  @callback listar_albergues(struct(), keyword()) :: {:ok, list(Albergue.t())} | {:error, atom()}
end

