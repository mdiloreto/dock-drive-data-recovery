# Runbook

Definir valores locales antes de usar los ejemplos:

```bash
export BTRFS_MOUNT=/mnt/MirroredBackup
export BACKUP_ROOT=$HOME/recovery-backup
export BTRFS_UUID='<BTRFS_UUID>'
export DEVICE_1='/dev/disk/by-id/<DEVICE_1_PARTITION>'
export DEVICE_2='/dev/disk/by-id/<DEVICE_2_PARTITION>'
export SERIAL_1='<DEVICE_1_SERIAL>'
export SERIAL_2='<DEVICE_2_SERIAL>'
```

## Mientras corre el balance de datos

No desmontar, apagar, suspender ni desconectar el dock. No iniciar otro balance
ni scrub.

Controles read-only:

```bash
./scripts/status.sh "$BTRFS_MOUNT" "$BTRFS_UUID" "$DEVICE_1" "$SERIAL_1" "$DEVICE_2" "$SERIAL_2"
btrfs balance status "$BTRFS_MOUNT"
btrfs filesystem df -b "$BTRFS_MOUNT"
btrfs filesystem usage -b "$BTRFS_MOUNT"
btrfs device stats -c "$BTRFS_MOUNT"
journalctl -k -b --since '10 minutes ago' -g 'BTRFS|Buffer I/O|I/O error|critical' --no-pager
```

`btrfs balance status` puede requerir privilegios. El script usa
`/sys/fs/btrfs/.../exclusive_operation`, que informa `balance` mientras la
operacion esta activa. La presencia de un proceso llamado `btrfs` por si sola
no es un gate autoritativo.

Durante la conversion es normal observar simultaneamente `Data,single` y
`Data,RAID1`. El primero debe disminuir y el segundo aumentar.

## Cuando termine el balance

Primero verificar perfiles y errores:

```bash
sudo btrfs balance status "$BTRFS_MOUNT"
btrfs filesystem df -b "$BTRFS_MOUNT"
btrfs filesystem usage -b "$BTRFS_MOUNT"
btrfs device stats -c "$BTRFS_MOUNT"
journalctl -k -b --since '6 hours ago' -g 'BTRFS|Buffer I/O|I/O error|critical' --no-pager
```

Resultado esperado:

```text
Data, RAID1
Metadata, RAID1
System, RAID1
Device missing: 0
Todos los device stats: 0
```

Despues ejecutar scrub privilegiado y bloqueante:

```bash
systemd-inhibit --what=sleep:shutdown:idle --why='Final Btrfs RAID1 scrub' sudo btrfs scrub start -B "$BTRFS_MOUNT"
```

Verificar resultado:

```bash
btrfs scrub status "$BTRFS_MOUNT"
btrfs device stats -c "$BTRFS_MOUNT"
```

Por ultimo comparar nuevamente contra la NVMe:

```bash
systemd-inhibit --what=sleep:shutdown:idle --why='Final RAID1 checksum verification' ionice -c 3 nice -n 19 rsync -aHnc --delete --no-owner --no-group --no-perms --protect-args --checksum-choice=xxh128 --human-readable --itemize-changes --stats "$BACKUP_ROOT/" "$BTRFS_MOUNT/"
```

La combinacion `-n --delete` no elimina nada: simula eliminaciones para poder
detectar tambien archivos que existan solo en el destino.

No eliminar el backup de la laptop antes de completar todos estos gates.

## Si el balance se interrumpe

Btrfs mantiene consistencia transaccional. Tras confirmar que ambos discos
siguen presentes y que el filesystem esta montado, consultar estado:

```bash
sudo btrfs balance status "$BTRFS_MOUNT"
```

Si figura pausado:

```bash
sudo btrfs balance resume "$BTRFS_MOUNT"
```

Si termino o fue cancelado con perfiles mixtos, repetir solo bloques que no
sean RAID1:

```bash
systemd-inhibit --what=sleep:shutdown:idle --why='Resume Btrfs RAID1 conversion' sudo ionice -c 2 -n 7 nice -n 15 btrfs balance start -dconvert=raid1,soft "$BTRFS_MOUNT"
```

## Si falla un disco en el futuro

1. No seguir usando el array normalmente.
2. Identificar el disco faltante por serial/devid.
3. Montar inicialmente con `ro,degraded,nologreplay` para impedir tambien el
   replay del tree log durante la inspeccion o copia.
4. Reemplazar el disco mediante `btrfs replace`, no reduciendo primero la
   redundancia con un balance.
5. Ejecutar scrub y revisar device stats despues de la reconstruccion.

La sintaxis exacta de `btrfs replace` depende del devid faltante y del nuevo
dispositivo; no debe copiarse una ruta `/dev/sdX` de este documento.

Ejemplo exclusivo para inspeccion inicial, ajustando el mountpoint:

```bash
sudo mount -o ro,degraded,nologreplay "UUID=$BTRFS_UUID" /mnt/recovery
```

Un eventual mount degradado read-write para `btrfs replace` es un paso
separado y debe decidirse despues de preservar datos importantes.

## Montaje persistente futuro

Despues de la validacion final se puede definir un mount estable por UUID. La
entrada debe revisarse antes de editar `/etc/fstab`:

```text
UUID=<BTRFS_UUID> /mnt/MirroredBackup btrfs noatime,compress=zstd:3,nofail,x-systemd.device-timeout=30s 0 0
```

No agregar `degraded` al montaje normal. Debe usarse manualmente solo durante
una recuperacion controlada.
