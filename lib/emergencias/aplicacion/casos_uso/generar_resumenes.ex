defmodule Emergencias.Aplicacion.CasosUso.GenerarResumenes do
  @moduledoc "Casos de uso para metricas ejecutivas, recursos criticos y priorizacion de necesidades."

  alias Emergencias.Dominio.Modelos.Usuario
  alias Emergencias.Dominio.Reglas.{JerarquiaZona, Ordenamiento, Permisos, Validaciones}

  @doc "Generar resumen ejecutivo global consolidando informacion de todas las areas."
  def generar_resumen_ejecutivo(%Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :generar_resumen) do
      p_log = resolver_puerto(opts, :puerto_logistica)
      p_zon = resolver_puerto(opts, :puerto_zonas)
      p_per = resolver_puerto(opts, :puerto_personas)
      p_mas = resolver_puerto(opts, :puerto_mascotas)
      p_alb = resolver_puerto(opts, :puerto_albergues)

      recs = p_log.listar_recursos()
      necs = p_log.listar_necesidades()
      zonas = p_zon.listar()
      pers = p_per.listar()
      masc = p_mas.listar()
      albs = p_alb.listar()

      total_personas = Enum.reduce(zonas, 0, fn z, acc -> acc + JerarquiaZona.sumar_personas_afectadas(z) end)
      en_albergue = Enum.reduce(albs, 0, fn a, acc -> acc + MapSet.size(a.personas_alojadas) end)
      disp = Enum.reduce(recs, 0, fn r, acc -> acc + r.cantidad_disponible end)

      resumen = %{
        total_recursos_disponibles: disp,
        necesidades_pendientes: Enum.count(necs, &(&1.estado == :pendiente)),
        personas_afectadas_total: total_personas,
        personas_censadas: length(pers),
        personas_en_albergue: en_albergue,
        mensajes_enviados: length(p_per.listar_todos_mensajes()),
        mascotas_activas: Enum.count(masc, &(&1.estado != :resuelta)),
        mascotas_resueltas: Enum.count(masc, &(&1.estado == :resuelta))
      }
      {:ok, resumen}
    end
  end

  @doc "Listar recursos cuyas existencias disponibles sean inferiores o iguales al umbral."
  def listar_recursos_criticos(umbral_val, %Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :recursos_criticos),
         {:ok, umbral} <- Validaciones.validar_no_negativo(umbral_val) do
      p_log = resolver_puerto(opts, :puerto_logistica)
      criticos = p_log.listar_recursos() |> Enum.filter(&(&1.cantidad_disponible <= umbral))
      movs = p_log.listar_movimientos()
      total_movilizado = JerarquiaZona.sumar_cantidades(movs)
      {:ok, %{recursos_criticos: criticos, total_unidades_movilizadas: total_movilizado}}
    end
  end

  @doc "Listar necesidades pendientes ordenadas mediante Merge Sort por prioridad y antiguedad."
  def listar_necesidades_pendientes(%Usuario{} = u, opts \\ []) do
    with :ok <- Permisos.autorizar(u.rol, :necesidades_pendientes) do
      p_log = resolver_puerto(opts, :puerto_logistica)
      pendientes = p_log.listar_necesidades() |> Enum.filter(&(&1.estado in [:pendiente, :asignada]))
      ordenadas = Ordenamiento.ordenar(pendientes, &Ordenamiento.comparar_necesidades/2)
      {:ok, ordenadas}
    end
  end

  defp resolver_puerto(opts, clave) do
    Keyword.get(opts, clave, Application.get_env(:emergencias, clave))
  end
end
