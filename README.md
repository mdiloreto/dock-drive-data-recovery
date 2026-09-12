# Dock Drive Data Recovery and Btrfs RAID1

Documentacion operativa de la recuperacion de datos desde un volumen NTFS
inconsistente y su migracion escalonada a un filesystem Btrfs RAID1 sobre dos
discos fisicos de 1 TB.

## Estado actual

Al primer control posterior al inicio del 2026-09-12, la conversion de los
bloques de datos a RAID1 estaba en ejecucion. Metadata y system ya estaban en
RAID1. Los valores debajo son una fotografia inicial; `scripts/status.sh`
muestra el estado actual. El backup de la laptop debe conservarse hasta
completar balance, scrub y verificacion final.

```text
Data,single:  517551947776 bytes
Data,RAID1:     4294967296 bytes
Metadata:     RAID1
System:       RAID1
Device errors: 0 en ambos discos
```

No se debe desmontar el filesystem, desconectar el dock, iniciar otro balance
ni ejecutar un scrub mientras el balance de datos este activo.

## Que estamos haciendo

Btrfs divide los datos en block groups. El comando activo relocaliza cada
block group con perfil `single` y crea dos copias, una en cada disco fisico.
Cuando termine, `Data,single` debe desaparecer y todos los perfiles deben ser
`RAID1`.

Los discos no son imagenes sector por sector. Ambos pertenecen a un unico
filesystem con un UUID compartido; Btrfs decide donde
ubicar cada copia y valida data/metadata mediante checksums `crc32c`.

## Discos

| Funcion | Modelo | Serial | Identidad estable |
|---|---|---|---|
| Primer dispositivo Btrfs, antes EXT4 | Disco CMR/SATA de 1 TB | `<DEVICE_1_SERIAL>` | `/dev/disk/by-id/<DEVICE_1_PARTITION>` |
| Segundo dispositivo Btrfs, antes NTFS | Disco CMR/SATA de 1 TB | `<DEVICE_2_SERIAL>` | `/dev/disk/by-id/<DEVICE_2_PARTITION>` |

Nunca se deben usar nombres variables como `/dev/sdb` o `/dev/sdc` para una
operacion destructiva.

## Documentos

- [Arquitectura y modelo de redundancia](docs/architecture.md)
- [Cronologia completa](docs/timeline.md)
- [Registro de comandos](docs/command-log.md)
- [Evidencia de verificacion](docs/verification.md)
- [Runbook de finalizacion y recuperacion](docs/runbook.md)
- [Compatibilidad y opciones para RouterOS](docs/routeros.md)

## Comprobar estado

```bash
./scripts/status.sh \
  /mnt/MirroredBackup \
  '<BTRFS_UUID>' \
  '/dev/disk/by-id/<DEVICE_1_PARTITION>' '<DEVICE_1_SERIAL>' \
  '/dev/disk/by-id/<DEVICE_2_PARTITION>' '<DEVICE_2_SERIAL>'
```

El script solo lee estado. No modifica discos ni filesystem.

## Privacidad

La version publica usa placeholders y categorias genericas. No se deben agregar
logs crudos, reportes SMART, manifests binarios, UUID, seriales, identificadores
de dispositivos moviles ni nombres de archivos personales.

## Referencias

- https://btrfs.readthedocs.io/en/latest/btrfs-device.html
- https://btrfs.readthedocs.io/en/latest/btrfs-balance.html
- https://btrfs.readthedocs.io/en/latest/btrfs-scrub.html
- https://download.samba.org/pub/rsync/rsync.1
- https://www.smartmontools.org/
