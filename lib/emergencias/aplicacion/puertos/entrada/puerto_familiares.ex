defmodule Emergencias.Aplicacion.Puertos.Entrada.PuertoFamiliares do
  @moduledoc """
  Contrato del caso de uso de localización de personas y mensajería familiar.
  """

  alias Emergencias.Dominio.Modelos.{Mensaje, Persona}

  @callback reportar_persona(map(), struct(), keyword()) :: {:ok, Persona.t()} | {:error, atom()}
  @callback buscar_persona(String.t(), struct(), keyword()) :: {:ok, Persona.t()} | {:error, atom()}
  @callback enviar_mensaje(String.t(), String.t(), struct(), keyword()) ::
              {:ok, Mensaje.t()} | {:error, atom()}
  @callback listar_mensajes(String.t(), struct(), keyword()) ::
              {:ok, list(Mensaje.t())} | {:error, atom()}
  @callback actualizar_persona(String.t(), atom(), map(), struct(), keyword()) ::
              {:ok, Persona.t()} | {:error, atom()}
end
