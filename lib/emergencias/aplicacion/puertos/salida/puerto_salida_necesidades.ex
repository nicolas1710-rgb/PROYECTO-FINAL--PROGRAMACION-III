defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaNecesidades do
  @moduledoc """
  Puerto de salida para el almacenamiento, consulta y actualización de necesidades humanitarias.
  """

  alias Emergencias.Dominio.Modelos.Necesidad

  @doc "Registrar una nueva necesidad en el sistema."
  @callback registrar(map(), String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}

  @doc "Consultar una necesidad por su identificador único."
  @callback consultar(String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}

  @doc "Actualizar el estado formal de una necesidad en su ciclo de vida."
  @callback actualizar_estado(String.t(), atom(), String.t()) :: {:ok, Necesidad.t()} | {:error, atom()}

  @doc "Registrar la asignación de suministros actualizando cantidad_asignada y el estado."
  @callback asignar_suministro(String.t(), pos_integer(), String.t()) ::
              {:ok, Necesidad.t()} | {:error, atom()}

  @doc "Listar necesidades aplicando filtros opcionales."
  @callback listar(keyword()) :: {:ok, list(Necesidad.t())}
end
