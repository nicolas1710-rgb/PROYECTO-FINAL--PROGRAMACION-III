defmodule Emergencias.Infraestructura.Entrada.Consola do
  @moduledoc """
  Bucle de entrada y salida recursivo para la interacción interactiva por consola.
  Mantiene en su llamada de cola el usuario con sesión activa.
  """

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Infraestructura.Entrada.{AnalizadorComandos, DespachadorComandos, Presentador}

  @doc """
  Iniciar el bucle interactivo de la consola de emergencias.
  """
  @spec iniciar() :: :ok
  def iniciar do
    IO.puts(Presentador.formatear_bienvenida())
    ejecutar_bucle(nil)
  end

  @doc """
  Bucle recursivo que lee comandos del usuario, los procesa y actualiza la sesión.
  """
  @spec ejecutar_bucle(Usuario.t() | nil) :: :ok
  def ejecutar_bucle(usuario_actual) do
    prompt = construir_prompt(usuario_actual)

    case IO.gets(prompt) do
      :eof ->
        IO.puts("\nCerrando sistema de emergencias.")
        :ok

      {:error, _razon} ->
        IO.puts("\nError en lectura de consola.")
        :ok

      linea when is_binary(linea) ->
        procesar_linea(String.trim(linea), usuario_actual)
    end
  end

  @doc """
  Procesar una línea leída desde la consola.
  """
  @spec procesar_linea(String.t(), Usuario.t() | nil) :: :ok
  def procesar_linea("", usuario_actual), do: ejecutar_bucle(usuario_actual)

  def procesar_linea(linea, usuario_actual) do
    case AnalizadorComandos.analizar_linea(linea) do
      {:ok, comando, argumentos} ->
        case DespachadorComandos.despachar(comando, argumentos, usuario_actual) do
          {:ok, salida, nuevo_usuario} ->
            mostrar_mensaje(salida)
            ejecutar_bucle(nuevo_usuario)

          {:error, error_str, mismo_usuario} ->
            mostrar_mensaje(error_str)
            ejecutar_bucle(mismo_usuario)

          {:salir, despedida} ->
            mostrar_mensaje(despedida)
            :ok
        end

      {:error, razon} ->
        mostrar_mensaje(Presentador.formatear_error(razon))
        ejecutar_bucle(usuario_actual)
    end
  end

  @doc """
  Construir el prompt de terminal reflejando el usuario y rol conectado.
  """
  @spec construir_prompt(Usuario.t() | nil) :: String.t()
  def construir_prompt(nil), do: "emergencias> "
  def construir_prompt(%Usuario{nombre: n, rol: r}), do: "#{n} [#{r}]> "

  defp mostrar_mensaje(texto) do
    if texto != "", do: IO.puts(texto)
  end
end
