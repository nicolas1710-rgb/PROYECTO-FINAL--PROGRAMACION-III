defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaAlbergues do
  @moduledoc """
  Puerto de salida para la administración de albergues temporales y control de ocupación.
  """

  alias Emergencias.Dominio.Modelos.Albergue

  @doc "Registrar un nuevo albergue temporal e iniciar su proceso supervisado."
  @callback registrar(map(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}

  @doc "Consultar el estado, capacidad y ocupación de un albergue por su identificador."
  @callback consultar(String.t()) :: {:ok, Albergue.t()} | {:error, atom()}

  @doc "Registrar el ingreso de una persona al albergue verificando aforo."
  @callback ingresar(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}

  @doc "Registrar la salida de una persona del albergue liberando cupo."
  @callback salir(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}

  @doc "Listar todos los albergues registrados en el sistema."
  @callback listar() :: {:ok, list(Albergue.t())}

  @doc "Asociar una cantidad de recurso al albergue."
  @callback asociar_recurso(String.t(), String.t(), pos_integer()) :: {:ok, Albergue.t()} | {:error, atom()}

  @doc "Asociar una necesidad humanitaria al albergue."
  @callback asociar_necesidad(String.t(), String.t()) :: {:ok, Albergue.t()} | {:error, atom()}
end
