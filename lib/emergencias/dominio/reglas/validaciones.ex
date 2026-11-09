defmodule Emergencias.Dominio.Reglas.Validaciones do
  @moduledoc """
  Conjunto de funciones puras y componibles para validación de datos de entrada.
  Todas las funciones retornan `{:ok, valor}` o `{:error, razon}`.
  """

  @niveles_gravedad [:critico, :alto, :medio, :bajo]
  @prioridades [:critica, :alta, :media, :baja]
  @roles [:ciudadano, :voluntario, :coordinador, :administrador]
  @tamanos_mascota [:pequeno, :mediano, :grande]
  @tipos_reporte_mascota [:perdida, :encontrada]

  @doc """
  Validar que un texto no sea nulo ni consista únicamente de espacios en blanco.
  """
  @spec validar_texto_no_vacio(any()) :: {:ok, String.t()} | {:error, :texto_vacio}
  def validar_texto_no_vacio(texto) when is_binary(texto) do
    limpio = String.trim(texto)
    if String.length(limpio) > 0, do: {:ok, limpio}, else: {:error, :texto_vacio}
  end

  def validar_texto_no_vacio(_), do: {:error, :texto_vacio}

  @doc """
  Validar que un número entero sea estrictamente positivo (> 0).
  """
  @spec validar_cantidad_positiva(any()) :: {:ok, pos_integer()} | {:error, :cantidad_invalida}
  def validar_cantidad_positiva(numero) when is_integer(numero) and numero > 0 do
    {:ok, numero}
  end

  def validar_cantidad_positiva(_), do: {:error, :cantidad_invalida}

  @doc """
  Validar que un número entero sea mayor o igual a cero (>= 0).
  """
  @spec validar_cantidad_no_negativa(any()) :: {:ok, non_neg_integer()} | {:error, :cantidad_negativa}
  def validar_cantidad_no_negativa(numero) when is_integer(numero) and numero >= 0 do
    {:ok, numero}
  end

  def validar_cantidad_no_negativa(_), do: {:error, :cantidad_negativa}

  @doc """
  Validar que un nivel de gravedad corresponda a uno de los valores permitidos.
  """
  @spec validar_nivel_gravedad(atom() | String.t()) :: {:ok, atom()} | {:error, :nivel_invalido}
  def validar_nivel_gravedad(nivel) when is_atom(nivel) do
    if nivel in @niveles_gravedad, do: {:ok, nivel}, else: {:error, :nivel_invalido}
  end

  def validar_nivel_gravedad(nivel) when is_binary(nivel) do
    nivel
    |> String.trim()
    |> String.downcase()
    |> String.to_existing_atom()
    |> validar_nivel_gravedad()
  rescue
    ArgumentError -> {:error, :nivel_invalido}
  end

  def validar_nivel_gravedad(_), do: {:error, :nivel_invalido}

  @doc """
  Validar que una prioridad corresponda a los niveles establecidos.
  """
  @spec validar_prioridad(atom() | String.t()) :: {:ok, atom()} | {:error, :prioridad_invalida}
  def validar_prioridad(prioridad) when is_atom(prioridad) do
    if prioridad in @prioridades, do: {:ok, prioridad}, else: {:error, :prioridad_invalida}
  end

  def validar_prioridad(prioridad) when is_binary(prioridad) do
    prioridad
    |> String.trim()
    |> String.downcase()
    |> String.to_existing_atom()
    |> validar_prioridad()
  rescue
    ArgumentError -> {:error, :prioridad_invalida}
  end

  def validar_prioridad(_), do: {:error, :prioridad_invalida}

  @doc """
  Validar que el rol corresponda a uno de los cuatro roles del sistema.
  """
  @spec validar_rol(atom() | String.t()) :: {:ok, atom()} | {:error, :rol_invalido}
  def validar_rol(rol) when is_atom(rol) do
    if rol in @roles, do: {:ok, rol}, else: {:error, :rol_invalido}
  end

  def validar_rol(rol) when is_binary(rol) do
    rol
    |> String.trim()
    |> String.downcase()
    |> String.to_existing_atom()
    |> validar_rol()
  rescue
    ArgumentError -> {:error, :rol_invalido}
  end

  def validar_rol(_), do: {:error, :rol_invalido}

  @doc """
  Validar el tamaño de una mascota.
  """
  @spec validar_tamano_mascota(atom() | String.t()) :: {:ok, atom()} | {:error, :tamano_invalido}
  def validar_tamano_mascota(tamano) when is_atom(tamano) do
    if tamano in @tamanos_mascota, do: {:ok, tamano}, else: {:error, :tamano_invalido}
  end

  def validar_tamano_mascota(tamano) when is_binary(tamano) do
    tamano
    |> String.trim()
    |> String.downcase()
    |> String.to_existing_atom()
    |> validar_tamano_mascota()
  rescue
    ArgumentError -> {:error, :tamano_invalido}
  end

  def validar_tamano_mascota(_), do: {:error, :tamano_invalido}

  @doc """
  Validar el tipo de reporte de mascota (:perdida o :encontrada).
  """
  @spec validar_tipo_reporte_mascota(atom() | String.t()) :: {:ok, atom()} | {:error, :tipo_reporte_invalido}
  def validar_tipo_reporte_mascota(tipo) when is_atom(tipo) do
    if tipo in @tipos_reporte_mascota, do: {:ok, tipo}, else: {:error, :tipo_reporte_invalido}
  end

  def validar_tipo_reporte_mascota(tipo) when is_binary(tipo) do
    tipo
    |> String.trim()
    |> String.downcase()
    |> String.to_existing_atom()
    |> validar_tipo_reporte_mascota()
  rescue
    ArgumentError -> {:error, :tipo_reporte_invalido}
  end

  def validar_tipo_reporte_mascota(_), do: {:error, :tipo_reporte_invalido}

  @doc """
  Validar que un identificador no exista previamente en un conjunto o mapa de existentes.
  """
  @spec validar_id_unico(String.t(), map() | MapSet.t()) :: {:ok, String.t()} | {:error, :id_duplicado}
  def validar_id_unico(id, %MapSet{} = existentes) do
    if MapSet.member?(existentes, id), do: {:error, :id_duplicado}, else: {:ok, id}
  end

  def validar_id_unico(id, mapa) when is_map(mapa) do
    if Map.has_key?(mapa, id), do: {:error, :id_duplicado}, else: {:ok, id}
  end

  @doc """
  Validar que un documento de identidad tenga caracteres válidos.
  """
  @spec validar_documento(any()) :: {:ok, String.t()} | {:error, :documento_invalido}
  def validar_documento(documento) when is_binary(documento) do
    limpio = String.trim(documento)
    if String.length(limpio) >= 3, do: {:ok, limpio}, else: {:error, :documento_invalido}
  end

  def validar_documento(_), do: {:error, :documento_invalido}

  @doc """
  Validar entrada para creación de usuario.
  """
  @spec validar_entrada_usuario(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_usuario(params) do
    with {:ok, nombre} <- validar_texto_no_vacio(Map.get(params, :nombre)),
         {:ok, clave} <- validar_texto_no_vacio(Map.get(params, :clave)),
         {:ok, rol} <- validar_rol(Map.get(params, :rol, :ciudadano)) do
      {:ok, %{nombre: nombre, clave: clave, rol: rol}}
    end
  end

  @doc """
  Validar entrada para creación de zona.
  """
  @spec validar_entrada_zona(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_zona(params) do
    with {:ok, nombre} <- validar_texto_no_vacio(Map.get(params, :nombre)),
         {:ok, gravedad} <- validar_nivel_gravedad(Map.get(params, :nivel_gravedad, :medio)) do
      {:ok, %{nombre: nombre, nivel_gravedad: gravedad}}
    end
  end

  @doc """
  Validar entrada para creación de necesidad.
  """
  @spec validar_entrada_necesidad(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_necesidad(params) do
    with {:ok, zona} <- validar_texto_no_vacio(Map.get(params, :codigo_zona)),
         {:ok, recurso} <- validar_texto_no_vacio(Map.get(params, :tipo_recurso)),
         {:ok, cant} <- validar_cantidad_positiva(Map.get(params, :cantidad_solicitada)),
         {:ok, prioridad} <- validar_prioridad(Map.get(params, :prioridad, :media)) do
      {:ok,
       %{
         codigo_zona: zona,
         tipo_recurso: recurso,
         cantidad_solicitada: cant,
         prioridad: prioridad
       }}
    end
  end

  @doc """
  Validar entrada para registro de recurso en inventario.
  """
  @spec validar_entrada_recurso(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_recurso(params) do
    with {:ok, tipo} <- validar_texto_no_vacio(Map.get(params, :tipo)),
         {:ok, unidad} <- validar_texto_no_vacio(Map.get(params, :unidad_medida)),
         {:ok, cant} <- validar_cantidad_positiva(Map.get(params, :cantidad_total)),
         {:ok, zona} <- validar_texto_no_vacio(Map.get(params, :codigo_zona)) do
      {:ok,
       %{
         tipo: tipo,
         unidad_medida: unidad,
         cantidad_total: cant,
         codigo_zona: zona
       }}
    end
  end

  @doc """
  Validar entrada para registro de persona.
  """
  @spec validar_entrada_persona(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_persona(params) do
    with {:ok, doc} <- validar_documento(Map.get(params, :documento)),
         {:ok, nombre} <- validar_texto_no_vacio(Map.get(params, :nombre_completo)) do
      {:ok, %{documento: doc, nombre_completo: nombre}}
    end
  end

  @doc """
  Validar entrada para reporte de mascota.
  """
  @spec validar_entrada_mascota(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_mascota(params) do
    with {:ok, tipo} <- validar_tipo_reporte_mascota(Map.get(params, :tipo_reporte)),
         {:ok, especie} <- validar_texto_no_vacio(Map.get(params, :especie)),
         {:ok, color} <- validar_texto_no_vacio(Map.get(params, :color)),
         {:ok, tamano} <- validar_tamano_mascota(Map.get(params, :tamano, :mediano)),
         {:ok, zona} <- validar_texto_no_vacio(Map.get(params, :codigo_zona)) do
      {:ok,
       %{
         tipo_reporte: tipo,
         especie: String.downcase(especie),
         nombre: Map.get(params, :nombre, ""),
         color: String.downcase(color),
         tamano: tamano,
         codigo_zona: zona,
         caracteristicas: Map.get(params, :caracteristicas, [])
       }}
    end
  end

  @doc """
  Validar entrada para registro de albergue.
  """
  @spec validar_entrada_albergue(map()) :: {:ok, map()} | {:error, atom()}
  def validar_entrada_albergue(params) do
    with {:ok, nombre} <- validar_texto_no_vacio(Map.get(params, :nombre)),
         {:ok, zona} <- validar_texto_no_vacio(Map.get(params, :codigo_zona)),
         {:ok, cap} <- validar_cantidad_positiva(Map.get(params, :capacidad_maxima)) do
      {:ok, %{nombre: nombre, codigo_zona: zona, capacidad_maxima: cap}}
    end
  end
end
