defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaZonas do
  @moduledoc """
  Puerto de salida para la persistencia y consulta de zonas territoriales de emergencia.
  """

  alias Emergencias.Dominio.Modelos.Zona

  @doc "Registrar una nueva zona en el sistema."
  @callback registrar(map(), String.t()) :: {:ok, Zona.t()} | {:error, atom()}

  @doc "Consultar una zona por su identificador único."
  @callback consultar(String.t()) :: {:ok, Zona.t()} | {:error, atom()}

  @doc "Listar todas las zonas registradas."
  @callback listar() :: {:ok, list(Zona.t())}

  @doc "Actualizar el nivel de gravedad o estado de una zona."
  @callback actualizar_estado(String.t(), atom(), String.t()) :: {:ok, Zona.t()} | {:error, atom()}
end
