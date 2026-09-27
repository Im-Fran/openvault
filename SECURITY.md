# Política de seguridad

OpenVault guarda secretos, así que nos tomamos en serio cualquier vulnerabilidad.

## Reportar una vulnerabilidad

**No abras un issue público.** Repórtala en privado desde
[Security → Report a vulnerability](https://github.com/Im-Fran/openvault/security/advisories/new).

Incluye, si puedes:
- Versión o commit afectado.
- Pasos para reproducirla y el impacto (p. ej. lectura de secretos sin la contraseña maestra).
- Una prueba de concepto mínima.

Responderemos en un plazo de 7 días y te mantendremos al tanto hasta publicar el fix. Con gusto te daremos crédito en el advisory si lo deseas.

## Versiones soportadas

Solo la última versión de la rama `dev` recibe correcciones de seguridad.

## Alcance

Dentro del alcance: el cifrado y formato del vault, la app macOS, el CLI `ovault` y el manejo de claves (Keychain, portapapeles, archivos temporales).

Fuera del alcance: ataques que requieren que el Mac ya esté comprometido con privilegios del usuario mientras el vault está desbloqueado.
