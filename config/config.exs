import Config

config :emergencias,
  puerto_usuarios: Emergencias.Infraestructura.Procesos.GestorUsuarios,
  puerto_zonas: Emergencias.Infraestructura.Procesos.GestorZonas,
  puerto_necesidades: Emergencias.Infraestructura.Procesos.GestorNecesidades,
  puerto_recursos: Emergencias.Infraestructura.Procesos.GestorRecursos,
  puerto_personas: Emergencias.Infraestructura.Procesos.GestorPersonas,
  puerto_mascotas: Emergencias.Infraestructura.Procesos.GestorMascotas,
  puerto_albergues: Emergencias.Infraestructura.Procesos.AdaptadorAlbergues,
  puerto_bitacora: Emergencias.Infraestructura.Procesos.BitacoraActividad,
  puerto_reloj: Emergencias.Aplicacion.Puertos.Salida.Reloj,
  directorio_datos: "datos"
