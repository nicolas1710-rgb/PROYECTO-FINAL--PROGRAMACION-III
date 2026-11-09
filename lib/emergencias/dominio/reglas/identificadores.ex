defmodule Emergencias.Dominio.Reglas.Identificadores do
  @moduledoc "Generador puro de identificadores correlativos legibles."

  @doc "Generar un codigo con prefijo y correlativo numerico a 3 digitos."
  def generar(prefijo, total_actual) when is_binary(prefijo) and is_integer(total_actual) do
    numero = String.pad_leading(to_string(total_actual + 1), 3, "0")
    "#{prefijo}#{numero}"
  end
end
