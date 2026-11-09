defmodule Emergencias.Infraestructura.Entrada.Consola.Analizador do
  @moduledoc "Analizador lexico de comandos CLI respetando comillas y argumentos clave=valor."

  @doc "Convertir una linea de texto en {comando_atom, argumentos_posicionales, argumentos_clave}."
  def analizar(linea) when is_binary(linea) do
    tokens = extraer_tokens(String.trim(linea))

    case tokens do
      [] -> {:vacio, [], %{}}
      [cmd | resto] ->
        {posicionales, claves} = clasificar_argumentos(resto, [], %{})
        {String.to_atom(String.downcase(cmd)), posicionales, claves}
    end
  end

  defp extraer_tokens(texto) do
    Regex.scan(~r/"([^"]*)"|'([^']*)'|(\S+)/, texto)
    |> Enum.map(fn
      [_, d_com, "", ""] -> d_com
      [_, "", s_com, ""] -> s_com
      [_, "", "", palabra] -> palabra
      [completo | _] -> completo
    end)
  end

  defp clasificar_argumentos([], pos, claves), do: {Enum.reverse(pos), claves}
  defp clasificar_argumentos([token | resto], pos, claves) do
    case String.split(token, "=", parts: 2) do
      [k, v] when k != "" and v != "" ->
        clasificar_argumentos(resto, pos, Map.put(claves, String.to_atom(String.downcase(k)), v))
      _ ->
        clasificar_argumentos(resto, [token | pos], claves)
    end
  end
end
