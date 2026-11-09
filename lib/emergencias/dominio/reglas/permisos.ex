defmodule Emergencias.Dominio.Reglas.Permisos do
  @moduledoc """
  Matriz de control de acceso basada en roles (RBAC) utilizando MapSet para verificación O(1).
  """

  @operaciones_ciudadano MapSet.new([
                           :registrar_necesidad,
                           :listar_necesidades,
                           :reportar_persona,
                           :buscar_persona,
                           :enviar_mensaje,
                           :listar_mensajes,
                           :reportar_mascota,
                           :consultar_albergue,
                           :listar_recursos
                         ])

  @operaciones_voluntario MapSet.union(
                            @operaciones_ciudadano,
                            MapSet.new([
                              :registrar_recurso,
                              :registrar_entrada_albergue,
                              :registrar_salida_albergue
                            ])
                          )

  @operaciones_coordinador MapSet.union(
                             @operaciones_voluntario,
                             MapSet.new([
                               :registrar_zona,
                               :registrar_albergue,
                               :asignar_recurso,
                               :transferir_recurso,
                               :actualizar_necesidad,
                               :actualizar_persona,
                               :emparejar_mascotas,
                               :resolver_mascota,
                               :generar_resumen,
                               :recursos_criticos,
                               :necesidades_pendientes
                             ])
                           )

  @matriz_permisos %{
    ciudadano: @operaciones_ciudadano,
    voluntario: @operaciones_voluntario,
    coordinador: @operaciones_coordinador
  }

  @doc """
  Evaluar si un rol específico tiene permiso para ejecutar una operación.
  El rol administrador posee permisos irrestrictos sobre cualquier operación.
  """
  @spec tener_permiso?(atom(), atom()) :: boolean()
  def tener_permiso?(:administrador, _operacion), do: true

  def tener_permiso?(rol, operacion) when is_atom(rol) and is_atom(operacion) do
    @matriz_permisos
    |> Map.get(rol, MapSet.new())
    |> MapSet.member?(operacion)
  end

  def tener_permiso?(_, _), do: false

  @doc """
  Autorizar la ejecución de una operación según el rol provisto.
  Retorna `:ok` o `{:error, :sin_permiso}`.
  """
  @spec autorizar(atom(), atom()) :: :ok | {:error, :sin_permiso}
  def autorizar(rol, operacion) do
    if tener_permiso?(rol, operacion) do
      :ok
    else
      {:error, :sin_permiso}
    end
  end
end
