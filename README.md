# Proyectos Lenovo SV

Portal de solicitudes y seguimiento de Gobierno / Licitación y B2B. Sitio estático compatible con GitHub Pages, con Supabase para cuentas, registros y archivos privados.

## Funciones

- Formulario con hasta 30 productos y 5 adjuntos de hasta 10 MB.
- El canal autenticado consulta únicamente sus solicitudes.
- El PM verifica Consumo / Comercial por ítem dentro de la revisión inicial. El resto del flujo es único.
- Seguimiento de MPN, descuento, contrato, próxima acción y resultado.
- Costos, precios, contrato Lenovo y notas internas accesibles únicamente al equipo autorizado.
- Alertas de seguimiento y exportación CSV.
- Los cambios de estatus quedan registrados en el servidor.

## Activación

1. Crear el repositorio `proyectos-lenovo` en GitHub, con rama `main`.
2. Crear un proyecto Supabase independiente del scoreboard.
3. Ejecutar `database.sql` una vez desde SQL Editor.
4. En `config.js`, completar `supabaseUrl` y `supabaseKey` usando solo la URL del proyecto y la clave publicable. Nunca usar `service_role` ni una clave secreta.
5. En Supabase Authentication, configurar Site URL y Redirect URLs para la URL real de GitHub Pages. Mantener confirmación de correo para cuentas nuevas. Usar SMTP propio si el envío de correos predeterminado no cubre los canales externos.
6. Crear y confirmar la cuenta del PM a través del portal. Autorizar su UUID en `public.project_staff` desde SQL Editor. La cuenta nueva no obtiene permisos internos por registrarse.
7. En GitHub Settings → Pages → Source seleccionar GitHub Actions. El workflow publica los archivos del sitio sin incluir SQL o tests en el artefacto de Pages.

## Verificación

`node tests/domain.test.mjs`

Los tests verifican precios faltantes frente a cero, totales, registro aplicable, contrato requerido y vencimientos. Validar adicionalmente dos cuentas de canal y una de PM en la base activada: un canal no debe leer ni editar solicitudes de otro, y tampoco ver costos o contratos internos.

## Estado de esta entrega

La interfaz y el código están preparados. Sin URL/clave configuradas, el portal muestra vista previa y no simula solicitudes enviadas. La publicación, conexión real y verificación de RLS requieren el repositorio y el proyecto Supabase activos.

Los adjuntos se suben después de crear la solicitud. Si falla la carga, se informa el número de solicitud ya creado y se puede reintentar en esa misma pestaña. Los archivos no se guardan en GitHub.
