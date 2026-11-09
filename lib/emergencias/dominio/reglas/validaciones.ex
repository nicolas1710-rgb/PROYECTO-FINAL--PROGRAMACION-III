defmodule Emergencias.Dominio.Reglas.Validaciones do
  @moduledoc "Validaciones puras para entradas de usuario y formatos de datos."

  @doc "Validar y convertir una representacion a numero entero."
  def validar_entero(val) when is_integer(val), do: {:ok, val}
  def validar_entero(val) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {num, ""} -> {:ok, num}
      _ -> {:error, :numero_invalido}
    end
  end
  def validar_entero(_), do: {:error, :numero_invalido}

  @doc "Validar que la cantidad sea un entero estrictamente positivo."
  def validar_positivo(val) do
    with {:ok, num} <- validar_entero(val) do
      if num > 0, do: {:ok, num}, else: {:error, :cantidad_invalida}
    end
  end

  @doc "Validar que la cantidad sea un entero mayor o igual a cero."
  def validar_no_negativo(val) do
    with {:ok, num} <- validar_entero(val) do
      if num >= 0, do: {:ok, num}, else: {:error, :cantidad_invalida}
    end
  end

  @doc "Validar que una cadena no sea nula ni contenga unicamente espacios."
  def validar_no_vacio(texto) when is_binary(texto) do
    limpio = String.trim(texto)
    if limpio != "", do: {:ok, limpio}, else: {:error, :campo_vacio}
  end
  def validar_no_vacio(_), do: {:error, :campo_vacio}

  @doc "Validar niveles de gravedad permitidos en zonas."
  def validar_nivel_gravedad(nivel) do
    validar_enum(nivel, ["critico", "alto", "medio", "bajo"], :nivel_invalido)
  end

  @doc "Validar prioridades permitidas en necesidades."
  def validar_prioridad(prio) do
    validar_enum(prio, ["critica", "alta", "media", "baja"], :prioridad_invalida)
  end

  @doc "Validar roles de usuario reconocidos por el sistema."
  def validar_rol(rol) do
    validar_enum(rol, ["ciudadano", "voluntario", "coordinador", "administrador"], :rol_invalido)
  end

  @doc "Validar tipo de reporte de mascota."
  def validar_tipo_mascota(tipo) do
    validar_enum(tipo, ["perdida", "encontrada"], :tipo_reporte_invalido)
  end

  @doc "Validar tamano de mascota."
  def validar_tamano_mascota(tam) do
    validar_enum(tam, ["pequeno", "mediano", "grande"], :tamano_invalido)
  end

  defp validar_enum(val, permitidos, error_atom) do
    clave = val |> to_string() |> String.downcase() |> String.trim()
    if clave in permitidos, do: {:ok, String.to_atom(clave)}, else: {:error, error_atom}
  end
end
