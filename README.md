# Dock Drive Data Recovery and Btrfs RAID1

Documentacion operativa de la recuperacion de datos desde un volumen NTFS
inconsistente y su migracion escalonada a un filesystem Btrfs RAID1 sobre dos
discos fisicos de 1 TB.

## Estado final

La migracion escalonada se completo el 2026-09-12. Data, metadata y system
quedaron exclusivamente en RAID1; ambos miembros completaron scrub con status
0 y una comparacion final `xxh128` detecto cero archivos faltantes, diferentes
o adicionales. El backup independiente debe conservarse porque RAID no es un
backup.

```text
Data,RAID1:     521838526464 bytes
Metadata,RAID1:   1073741824 bytes
System,RAID1:       67108864 bytes
Device missing: 0
Device errors:  0 en ambos discos
Scrub errors:   0
```

## Que hizo la migracion

Btrfs divide los datos en block groups. El balance relocalizo cada block group
con perfil `single` y creo dos copias, una en cada disco fisico. La verificacion
final confirmo que `Data,single` desaparecio y todos los perfiles quedaron en
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
