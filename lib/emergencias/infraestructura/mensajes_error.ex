defmodule Emergencias.Infraestructura.MensajesError do
  @moduledoc "Catalogo unificado de mensajes explicativos de error para adaptadores de entrada."

  @errores %{
    no_autenticado: "Debes iniciar sesion con 'connect <usuario> <clave> [rol]'.",
    no_autorizado: "No tienes permisos suficientes para ejecutar esta accion.",
    clave_incorrecta: "La clave ingresada es incorrecta.",
    usuario_no_encontrado: "El usuario especificado no existe.",
    numero_invalido: "Se esperaba un valor numerico valido.",
    cantidad_invalida: "La cantidad debe ser un entero positivo.",
    campo_vacio: "Un campo requerido no puede estar vacio.",
    nivel_invalido: "Nivel de gravedad invalido (critico, alto, medio, bajo).",
    prioridad_invalida: "Prioridad invalida (critica, alta, media, baja).",
    rol_invalido: "Rol invalido (ciudadano, voluntario, coordinador, administrador).",
    tipo_reporte_invalido: "Tipo de reporte invalido (perdida, encontrada).",
    tamano_invalido: "Tamano invalido (pequeno, mediano, grande).",
    zona_no_encontrada: "La zona especificada no existe.",
    sector_no_encontrado: "El sector barrial especificado no existe.",
    punto_no_encontrado: "El punto de atencion especificado no existe.",
    recurso_no_encontrado: "El recurso especificado no existe en inventario.",
    necesidad_no_encontrada: "La necesidad especificada no fue encontrada.",
    necesidad_ya_cerrada: "La necesidad ya fue atendida o cancelada y no admite suministros.",
    cantidad_excede_necesidad: "La cantidad supera el saldo pendiente de la necesidad.",
    tipo_recurso_incompatible: "El tipo de recurso no coincide con lo solicitado en la necesidad.",
    stock_insuficiente: "Existencias insuficientes en inventario para atender la solicitud.",
    persona_no_encontrada: "La persona especificada no fue encontrada en el censo.",
    mascota_no_encontrada: "El reporte de mascota especificado no existe.",
    ya_cerrada: "El registro ya se encuentra cerrado o resuelto.",
    albergue_no_encontrado: "El albergue indicado no existe en el sistema.",
    capacidad_excedida: "El albergue ha alcanzado su capacidad maxima permitida.",
    persona_ya_alojada: "La persona ya se encuentra registrada en este albergue.",
    persona_no_alojada: "La persona no se encuentra registrada en este albergue.",
    transicion_invalida: "La transicion de estado solicitada no es valida segun las reglas de negocio."
  }

  @doc "Obtener la descripcion en texto claro para un atomo de error."
  def obtener_mensaje(razon) when is_atom(razon) do
    Map.get(@errores, razon, "Operacion rechazada: #{razon}")
  end
  def obtener_mensaje(err), do: "#{inspect(err)}"
end
