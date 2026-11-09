defmodule Emergencias.Dominio.Reglas.Permisos do
  @moduledoc "Matriz de control de acceso RBAC basada en MapSet."

  @permisos_ciudadano MapSet.new([
    :registrar_necesidad, :listar_necesidades, :reportar_persona, :buscar_persona,
    :enviar_mensaje, :listar_mensajes, :reportar_mascota, :listar_mascotas,
    :consultar_albergue, :listar_albergues, :listar_recursos, :consultar_zona, :listar_zonas
  ])

  @permisos_voluntario MapSet.union(@permisos_ciudadano, MapSet.new([
    :registrar_recurso, :registrar_entrada_albergue, :registrar_salida_albergue, :actualizar_persona
  ]))

  @permisos_coordinador MapSet.union(@permisos_voluntario, MapSet.new([
    :asignar_recurso, :transferir_recurso, :registrar_zona, :registrar_sector,
    :registrar_punto, :registrar_albergue, :emparejar_mascotas, :confirmar_coincidencia,
    :actualizar_necesidad, :generar_resumen, :recursos_criticos, :necesidades_pendientes,
    :vincular_albergue, :reporte_albergues
  ]))

  @permisos_rol %{
    ciudadano: @permisos_ciudadano,
    voluntario: @permisos_voluntario,
    coordinador: @permisos_coordinador,
    administrador: @permisos_coordinador
  }

  @doc "Autorizar una accion segun el rol del usuario."
  def autorizar(rol, accion) do
    permitidos = Map.get(@permisos_rol, rol, MapSet.new())
    if MapSet.member?(permitidos, accion), do: :ok, else: {:error, :no_autorizado}
  end
end
