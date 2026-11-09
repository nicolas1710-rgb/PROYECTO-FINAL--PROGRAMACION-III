defmodule Emergencias.Dominio.Modelos.Mensaje do
  @moduledoc """
  Representa un mensaje de comunicación familiar asociado al documento de una persona.
  """

  @enforce_keys [:id, :documento_persona, :remitente, :contenido, :fecha_envio]
  defstruct [:id, :documento_persona, :remitente, :contenido, :fecha_envio]

  @type t :: %__MODULE__{
          id: String.t(),
          documento_persona: String.t(),
          remitente: String.t(),
          contenido: String.t(),
          fecha_envio: String.t()
        }

  @doc """
  Construir un mensaje de comunicación familiar.
  """
  @spec construir(map()) :: {:ok, t()} | {:error, atom()}
  def construir(atributos) when is_map(atributos) do
    {:ok,
     %__MODULE__{
       id: Map.fetch!(atributos, :id),
       documento_persona: Map.fetch!(atributos, :documento_persona),
       remitente: Map.fetch!(atributos, :remitente),
       contenido: Map.fetch!(atributos, :contenido),
       fecha_envio: Map.fetch!(atributos, :fecha_envio)
     }}
  rescue
    KeyError -> {:error, :atributos_incompletos}
  end
end
