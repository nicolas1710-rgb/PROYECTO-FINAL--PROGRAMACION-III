defmodule Emergencias.Dominio.Modelos.Mensaje do
  @moduledoc "Mensaje humanitario dirigido a una persona o sus familiares."
  defstruct [:id, :documento_persona, :remitente, :contenido, :fecha]

  @doc "Construir un mensaje de texto para un familiar."
  def construir(attrs) when is_map(attrs) do
    {:ok, struct(__MODULE__, attrs)}
  end
end
