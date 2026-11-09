defmodule Emergencias.Infraestructura.Entrada.AnalizadorComandos do
  @moduledoc """
  Analizador léxico y sintáctico para comandos de consola.
  Soporta argumentos entrecomillados ("..."), pares clave=valor y normalización de identificadores.
  """

  @comandos_validos MapSet.new([
                      "connect",
                      "disconnect",
                      "register_zone",
                      "register_need",
                      "list_needs",
                      "assign_resource",
                      "register_resource",
                      "list_resources",
                      "transfer_resource",
                      "report_person",
                      "find_person",
                      "send_family_message",
                      "list_family_messages",
                      "report_pet",
                      "match_pets",
                      "register_shelter",
                      "check_shelter",
                      "register_entry",
                      "register_exit",
                      "summary",
                      "critical_resources",
                      "pending_needs",
                      "help",
                      "exit"
                    ])

  @doc """
  Analizar una línea de texto introducida por el usuario y convertirla en una tupla de comando y argumentos.
  """
  @spec analizar_linea(String.t()) ::
          {:ok, atom(), list(String.t() | {atom(), String.t()})}
          | {:error, :comando_desconocido | :linea_vacia}
  def analizar_linea(linea) when is_binary(linea) do
    tokens = extraer_tokens(String.trim(linea))

    case tokens do
      [] ->
        {:error, :linea_vacia}

      [comando_str | args_raw] ->
        cmd = String.downcase(comando_str)

        if MapSet.member?(@comandos_validos, cmd) do
          args_procesados = procesar_argumentos(args_raw)
          {:ok, String.to_existing_atom(cmd), args_procesados}
        else
          {:error, :comando_desconocido}
        end
    end
  end

  def analizar_linea(_), do: {:error, :linea_vacia}

  @doc """
  Normalizar un identificador a su prefijo canónico en mayúsculas (ej: 'need001' -> 'N001').
  """
  @spec normalizar_identificador(String.t()) :: String.t()
  def normalizar_identificador(id) when is_binary(id) do
    limpio = String.trim(id)

    cond do
      Regex.match?(~r/^(?:need|n)(\d+)$/i, limpio) ->
        [_, num] = Regex.run(~r/^(?:need|n)(\d+)$/i, limpio)
        "N" <> String.pad_leading(num, 3, "0")

      Regex.match?(~r/^(?:res|r)(\d+)$/i, limpio) ->
        [_, num] = Regex.run(~r/^(?:res|r)(\d+)$/i, limpio)
        "R" <> String.pad_leading(num, 3, "0")

      Regex.match?(~r/^(?:zone|z)(\d+)$/i, limpio) ->
        [_, num] = Regex.run(~r/^(?:zone|z)(\d+)$/i, limpio)
        "Z" <> String.pad_leading(num, 3, "0")

      Regex.match?(~r/^(?:pet|mc)(\d+)$/i, limpio) ->
        [_, num] = Regex.run(~r/^(?:pet|mc)(\d+)$/i, limpio)
        "MC" <> String.pad_leading(num, 3, "0")

      Regex.match?(~r/^(?:shelter|alb)(\d+)$/i, limpio) ->
        [_, num] = Regex.run(~r/^(?:shelter|alb)(\d+)$/i, limpio)
        "ALB" <> String.pad_leading(num, 3, "0")

      true ->
        String.upcase(limpio)
    end
  end

  def normalizar_identificador(otro), do: to_string(otro)

  defp extraer_tokens(linea) do
    # Expresión regular que reconoce palabras o bloques entre comillas dobles
    Regex.scan(~r/"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|(\S+)/, linea)
    |> Enum.map(fn
      [_, entre_comillas_dobles | _] when entre_comillas_dobles != "" -> entre_comillas_dobles
      [_, _, entre_comillas_simples | _] when entre_comillas_simples != "" -> entre_comillas_simples
      [_, _, _, palabra] -> palabra
      [palabra] -> palabra
    end)
  end

  defp procesar_argumentos(args) do
    Enum.map(args, fn arg ->
      if String.contains?(arg, "=") do
        case String.split(arg, "=", parts: 2) do
          [clave, valor] ->
            {String.to_atom(String.downcase(clave)), desglosar_valor(valor)}

          _ ->
            arg
        end
      else
        arg
      end
    end)
  end

  defp desglosar_valor(valor) do
    String.trim(valor, "\"")
  end
end
