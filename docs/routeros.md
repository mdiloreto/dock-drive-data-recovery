# RouterOS y el Btrfs RAID1

## Respuesta corta

RouterOS si soporta Btrfs y Btrfs-RAID1, pero el soporte avanzado no esta
disponible en cualquier version o dispositivo:

- Las funciones Btrfs documentadas requieren RouterOS `7.18beta2` o posterior;
  para produccion se considera `7.18` estable como minimo.
- Requieren el paquete `ROSE-storage` de la misma version y arquitectura.
- ROSE-storage esta documentado para `arm`, `arm64`, `x86` y `tile`.
- El router necesita conectividad USB/SATA adecuada para ambos discos y el
  dock debe tener alimentacion propia.

La guia oficial de MikroTik describe el mismo modelo usado en esta migracion:
formatear un disco Btrfs, agregar el segundo, ejecutar balance con perfiles
RAID1 y comprobar que data, metadata y system no conserven perfil `single`.
RouterOS `7.19` agrego soporte de montaje Btrfs degradado, aunque la guia no
documenta su sintaxis ni lo recomienda como mecanismo de importacion.

Referencias oficiales:

- https://help.mikrotik.com/docs/spaces/ROS/pages/91193346/Disks
- https://help.mikrotik.com/docs/spaces/ROS/pages/295239711/Btrfs
- https://help.mikrotik.com/docs/spaces/ROS/pages/259031065/ROSE-storage

## Importar este array creado en Linux

Btrfs es un formato on-disk compartido con Linux, pero MikroTik no documenta ni
garantiza la importacion directa de un filesystem multi-device creado en Linux.
No se debe asumir compatibilidad completa sin una prueba controlada. Este
filesystem fue creado por `mkfs.btrfs 7.1` con:

```text
extref
skinny-metadata
no-holes
free-space-tree
block-group-tree
```

`block-group-tree` es una feature incompatible soportada upstream desde Linux
6.1. La documentacion de RouterOS confirma Btrfs-RAID, pero no enumera todas
las features on-disk que acepta su kernel/backport. RouterOS podria montar el
array normalmente o rechazarlo por una feature desconocida.

Linux dispone de `btrfstune --convert-from-block-group-tree` para convertir un
filesystem desmontado, pero no debe ejecutarse preventivamente ni durante un
balance. Solo se consideraria despues del scrub/checksum final, con el backup
NVMe intacto y si una prueba RouterOS confirma incompatibilidad.

## Prueba segura propuesta

No mover el dock mientras el balance, scrub o checksum esten activos.

Despues de la validacion final en Linux:

1. Confirmar modelo, arquitectura, version RouterOS y paquete ROSE-storage.
2. Expulsar/desmontar limpiamente el filesystem en Linux.
3. Mover juntos ambos discos en su dock autoalimentado; nunca un solo miembro.
4. Identificar slots y seriales con `/disk print detail`.
5. Evitar que RouterOS monte ambos miembros como dos paths visibles; la guia
   indica `mount-filesystem=no` para el segundo miembro.
6. Configurar `mount-read-only=yes` tan pronto como RouterOS identifique el
   slot principal y consultar
   `/disk/btrfs/filesystem print`.
7. Verificar UUID, ambos DEV-ID, ausencia de missing devices, perfiles RAID1 y
   contadores de error antes de habilitar escrituras o compartir por red.

RouterOS intenta montar automaticamente filesystems reconocidos. Su opcion
`mount-read-only=yes` no garantiza un montaje forense porque MikroTik no
documenta una opcion equivalente a `nologreplay`, y Btrfs upstream puede
reproducir el tree log incluso en un mount read-only. Por eso la prueba debe
hacerse solo despues de un unmount Linux limpio y manteniendo intacto el backup
NVMe.

Si RouterOS no reconoce la feature on-disk, no formatear ni ejecutar
`wipe-quick` desde RouterOS. Ejectar ambos discos, volver a Linux y decidir la
conversion de compatibilidad con el backup conservado.

## Opciones de arquitectura

### Discos conectados directamente al MikroTik

Ventajas:

- El router puede exponer SMB/NFS/DLNA sin mantener la laptop encendida.
- RouterOS con ROSE puede balancear, scrub, snapshot y reemplazar miembros
  Btrfs.

Riesgos:

- Depende de version, arquitectura, paquete y compatibilidad on-disk.
- USB/CPU/RAM del router pueden limitar rendimiento.
- El router y el dock pasan a ser puntos unicos de fallo y mantenimiento.
- Una actualizacion RouterOS puede cambiar el comportamiento del driver.

### Discos conectados a Linux y compartidos por red

Ventajas:

- Compatibilidad completa con el filesystem creado y herramientas Btrfs.
- Mejor diagnostico, automatizacion SMART, scrub y reemplazo.
- RouterOS solo enruta; los clientes consumen SMB/NFS desde Linux.

Riesgos:

- La laptop o servidor Linux debe permanecer encendido.
- El storage deja de estar disponible si Linux o el dock se desconectan.

### Recomendacion

Para datos importantes, un host Linux dedicado de bajo consumo conectado al
dock y compartiendo SMB/NFS es la opcion mas predecible. Conectar directamente
al MikroTik es viable si el hardware cumple los requisitos y el array supera
una prueba controlada de compatibilidad; no puede prometerse una primera monta
forense read-only con las opciones actualmente documentadas por MikroTik.

## Informacion necesaria del MikroTik

Ejecutar en RouterOS y revisar antes de mover discos:

```routeros
/system resource print
/system package print
/disk print detail
```

Se necesitan como minimo version, architecture-name, board-name, memoria libre,
paquete `rose-storage`, puertos disponibles y velocidad USB/SATA.
