defmodule Emergencias.Infraestructura.Salida.AlmacenArchivo do
  @moduledoc "Persistencia atomica en texto plano usando :file.consult y :io_lib.format."

  @doc "Guardar una lista de structs o terminos en datos/<nombre>.txt de forma atomica."
  def guardar(nombre, registros) when is_list(registros) do
    dir = Application.get_env(:emergencias, :directorio_datos, "datos")
    File.mkdir_p!(dir)
    ruta_final = Path.join(dir, "#{nombre}.txt")
    ruta_temporal = Path.join(dir, "#{nombre}.tmp")

    contenido =
      ["%% coding: utf-8\n" | Enum.map(registros, fn r -> :io_lib.format("~tp.~n", [r]) end)]

    with :ok <- File.write(ruta_temporal, :unicode.characters_to_binary(contenido)),
         :ok <- File.rename(ruta_temporal, ruta_final) do
      :ok
    else
      error -> error
    end
  end

  @doc "Cargar registros desde datos/<nombre>.txt tolerando archivos inexistentes o corruptos."
  def cargar(nombre) do
    dir = Application.get_env(:emergencias, :directorio_datos, "datos")
    ruta = Path.join(dir, "#{nombre}.txt")

    case :file.consult(String.to_charlist(ruta)) do
      {:ok, terminos} -> terminos
      _ -> []
    end
  end
end
