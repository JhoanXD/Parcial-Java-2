# Sistema de gestión de proyectos de grado

Aplicación web académica implementada con JSP, JSTL 1.2, Tomcat y MySQL/MariaDB.

## Requisitos

- Apache Tomcat con soporte para JSP y JNDI.
- MySQL o MariaDB.
- Java compatible con la versión de Tomcat instalada.

Las bibliotecas JSTL y MySQL Connector/J usadas por la aplicación están en `WEB-INF/lib`.

## Configuración local

1. Crea la base de datos ejecutando `database/01_create_schema.sql`.
2. Carga los datos iniciales con `database/02_insert_initial_data.sql`.
3. Copia `META-INF/context.xml.example` como `META-INF/context.xml`.
4. En `META-INF/context.xml`, reemplaza `REPLACE_WITH_DATABASE_USER` y `REPLACE_WITH_DATABASE_PASSWORD` por las credenciales locales de MySQL/MariaDB.
5. Despliega la carpeta del proyecto en `webapps` de Tomcat e inicia el servidor.

`META-INF/context.xml` contiene credenciales locales y está excluido de Git. No publiques ese archivo ni contraseñas reales.

## Directorio de usuarios

El directorio requiere una sesión de administrador y no muestra contraseñas. Los datos personales de usuarios no deben exponerse públicamente.
