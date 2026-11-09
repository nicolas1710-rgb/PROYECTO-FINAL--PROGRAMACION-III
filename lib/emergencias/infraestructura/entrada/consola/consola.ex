defmodule Emergencias.Infraestructura.Entrada.Consola.Consola do
  @moduledoc "Bucle interactivo CLI puro con lectura recursiva y captura de comandos."

  alias Emergencias.Infraestructura.Entrada.Consola.{Analizador, Despachador}

  @doc "Iniciar la consola interactiva CLI."
  def iniciar do
    IO.puts("=== SISTEMA DISTRIBUIDO DE COORDINACION DE EMERGENCIAS ===")
    IO.puts("Escribe 'help' para ver la lista de comandos o 'exit' para salir.\n")
    bucle(nil)
  end

  @doc "Bucle recursivo de lectura y despacho de comandos."
  def bucle(usuario) do
    prompt = construir_prompt(usuario)

    case IO.gets(prompt) do
      :eof ->
        IO.puts("\nCerrando sistema.")
        :ok

      {:error, _} ->
        IO.puts("\nError de lectura.")
        :ok

      linea when is_binary(linea) ->
        case Analizador.analizar(linea) do
          {:vacio, _, _} ->
            bucle(usuario)

          {cmd, args, kw} ->
            case Despachador.despachar(cmd, args, kw, usuario) do
              {:salir, despedida} ->
                IO.puts(despedida)
                :ok

              {:ok, salida, nuevo_u} ->
                if salida != "", do: IO.puts(salida)
                bucle(nuevo_u)

              {:error, error_msg, u_persistente} ->
                IO.puts(error_msg)
                bucle(u_persistente)
            end
        end
    end
  end

  defp construir_prompt(nil), do: "emergencias> "
  defp construir_prompt(u), do: "#{u.nombre} [#{u.rol}]> "
end
