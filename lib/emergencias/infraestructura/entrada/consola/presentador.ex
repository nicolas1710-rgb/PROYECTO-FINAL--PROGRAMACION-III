defmodule Emergencias.Infraestructura.Entrada.Consola.Presentador do
  @moduledoc "Presentador en consola con formateador generico de tablas y catalogo de errores."

  alias Emergencias.Infraestructura.MensajesError

  @doc "Formatear una lista de elementos en tabla alineada segun las columnas indicadas."
  def formatear_tabla([], _columnas), do: "No se encontraron registros."
  def formatear_tabla(filas, columnas) do
    encabezados = Enum.map_join(columnas, " | ", fn {tit, _, ancho} -> String.pad_trailing(tit, ancho) end)
    separador = Enum.map_join(columnas, "-+-", fn {_, _, ancho} -> String.duplicate("-", ancho) end)

    cuerpo =
      Enum.map_join(filas, "\n", fn item ->
        Enum.map_join(columnas, " | ", fn {_, fun_o_campo, ancho} ->
          val = if is_function(fun_o_campo, 1), do: fun_o_campo.(item), else: Map.get(item, fun_o_campo, "")
          String.pad_trailing(to_string(val), ancho)
        end)
      end)

    "#{encabezados}\n#{separador}\n#{cuerpo}"
  end

  @doc "Formatear un mensaje de exito para la consola."
  def formatear_exito(msg), do: "[OK] #{msg}"

  @doc "Formatear un atomo de error a un mensaje explicativo para el usuario."
  def formatear_error(razon) do
    "[ERROR] " <> MensajesError.obtener_mensaje(razon)
  end
end
