defmodule Emergencias.Aplicacion.Puertos.Salida.PuertoSalidaPersonas do
  @moduledoc """
  Puerto de salida para el censo de personas afectadas y mensajería familiar.
  """

  alias Emergencias.Dominio.Modelos.{Mensaje, Persona}

  @doc "Reportar una persona damnificada en el censo."
  @callback reportar(map(), String.t()) :: {:ok, Persona.t()} | {:error, atom()}

  @doc "Buscar una persona por su número de documento de identidad."
  @callback buscar(String.t()) :: {:ok, Persona.t()} | {:error, atom()}

  @doc "Registrar un mensaje familiar destinado a una persona."
  @callback enviar_mensaje(String.t(), String.t(), String.t()) :: {:ok, Mensaje.t()} | {:error, atom()}

  @doc "Listar todos los mensajes asociados al documento de una persona."
  @callback listar_mensajes(String.t()) :: {:ok, list(Mensaje.t())}

  @doc "Listar todas las personas reportadas en el censo."
  @callback listar_personas() :: {:ok, list(Persona.t())}

  @doc "Listar todos los mensajes familiares registrados en el sistema."
  @callback listar_todos_mensajes() :: {:ok, list(Mensaje.t())}

  @doc "Actualizar el estado y ubicación de una persona en el censo."
  @callback actualizar_estado(String.t(), atom(), map(), String.t()) ::
              {:ok, Persona.t()} | {:error, atom()}
end
