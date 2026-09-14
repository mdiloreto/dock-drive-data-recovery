# Registro de comandos sanitizado

Este registro conserva los comandos operativos usados durante la migracion,
pero reemplaza usuario, seriales, UUID, IDs de dispositivos moviles y nombres
de archivos personales. El transcript exacto permanece en el workspace privado
del operador y no debe publicarse.

## Variables

Los ejemplos suponen estas variables revisadas antes de cada operacion:

```bash
export SOURCE_MOUNT=/mnt/source-read-only
export BACKUP_ROOT=$HOME/recovery-backup
export BTRFS_MOUNT=/mnt/MirroredBackup
export BTRFS_UUID=$(uuidgen)
export DEVICE_1='/dev/disk/by-id/<DEVICE_1_PARTITION>'
export DEVICE_2='/dev/disk/by-id/<DEVICE_2_PARTITION>'
```

Las rutas `/dev/sdX` se usaron solo para diagnostico read-only. Todos los
comandos destructivos usaron `/dev/disk/by-id`.

## Inventario read-only

```bash
lsblk -e 7 -b -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL,SERIAL,TRAN
findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS,AVAIL,USE%
findmnt -T "$SOURCE_MOUNT" -o TARGET,SOURCE,MAJ:MIN,FSTYPE,OPTIONS,FSROOT
df -hT "$SOURCE_MOUNT" "$BACKUP_ROOT"
du -sx --block-size=1 "$SOURCE_MOUNT"
du -sx --apparent-size --block-size=1 "$SOURCE_MOUNT"
journalctl -k -b -g 'ntfs|sda|sdb|sdc|fuse' --no-pager
udisksctl info -b /dev/sdb1
udisksctl info -b /dev/sdc1
btrfs filesystem usage -b /home
btrfs filesystem df -b /home
```

Se usaron `du --max-depth` y scripts Python inline read-only para inventariar
directorios, comparar dos arboles casi duplicados por ruta/tamano/mtime,
detectar imagenes por extension y magic header, y comparar cada ruta fuente
contra el backup.

## Copia por lotes

Creacion del destino:

```bash
mkdir -p "$BACKUP_ROOT" "$BACKUP_ROOT/.recovery-logs"
```

Plantilla inicial limitada a 20 MiB/s:

```bash
rsync -aH --no-owner --no-group --no-perms --protect-args \
  --partial-dir=.rsync-partial --sparse --fsync --bwlimit=20M \
  --human-readable --info=progress2,stats2 \
  --log-file="$BACKUP_ROOT/.recovery-logs/batch-rsync.log" \
  "$SOURCE_MOUNT/priority-directory/" \
  "$BACKUP_ROOT/priority-directory/"
```

Plantilla adoptada para lotes grandes despues del control termico:

```bash
ionice -c 2 -n 7 nice -n 15 rsync -aH \
  --no-owner --no-group --no-perms --protect-args \
  --partial-dir=.rsync-partial --sparse --fsync --bwlimit=35M \
  --human-readable --info=progress2,stats2 \
  --log-file="$BACKUP_ROOT/.recovery-logs/batch-rsync.log" \
  "$SOURCE_MOUNT/selected-directory/" \
  "$BACKUP_ROOT/selected-directory/"
```

Verificacion por contenido despues de cada lote:

```bash
ionice -c 3 nice -n 19 rsync -aHnc \
  --no-owner --no-group --no-perms --protect-args \
  --checksum-choice=xxh128 --human-readable --itemize-changes --stats \
  "$SOURCE_MOUNT/selected-directory/" \
  "$BACKUP_ROOT/selected-directory/"
```

El barrido de imagenes genero un files-from delimitado por NUL y copio solo
archivos faltantes conservando rutas relativas:

```bash
ionice -c 2 -n 7 nice -n 15 rsync -aHr \
  --no-owner --no-group --no-perms --protect-args \
  --from0 --files-from="$BACKUP_ROOT/.recovery-logs/all-images.files0" \
  --partial-dir=.rsync-partial --sparse --fsync --bwlimit=35M \
  "$SOURCE_MOUNT/" "$BACKUP_ROOT/"
```

## Validacion de formatos

Se usaron comandos equivalentes sobre muestras sanitizadas:

```bash
file "$BACKUP_ROOT/path/to/photo.jpg"
file "$BACKUP_ROOT/mobile-backup/<BACKUP-ID>/path/to/extensionless-image"
ffprobe -v error -show_entries format=filename,format_name,duration,size \
  -of default=noprint_wrappers=1 "$BACKUP_ROOT/path/to/audio.wav"
ffprobe -v error -show_entries format=filename,format_name,duration,size \
  -of default=noprint_wrappers=1 "$BACKUP_ROOT/path/to/video.mp4"
gzip -t "$BACKUP_ROOT/path/to/project-file.gz"
```

## SMART

Los comandos siempre usaron paths whole-disk estables, no particiones:

```bash
sudo smartctl -a -d sat '/dev/disk/by-id/<DEVICE_1>' > /tmp/device-1-smart.txt 2>&1
sudo smartctl -a -d sat '/dev/disk/by-id/<DEVICE_2>' > /tmp/device-2-smart.txt 2>&1
sudo smartctl -t long -d sat '/dev/disk/by-id/<DEVICE_1>'
sudo smartctl -t long -d sat '/dev/disk/by-id/<DEVICE_2>'
sudo smartctl -x -d sat '/dev/disk/by-id/<DEVICE_1>' > /tmp/device-1-smart.txt 2>&1
sudo smartctl -x -d sat '/dev/disk/by-id/<DEVICE_2>' > /tmp/device-2-smart.txt 2>&1
```

Ambos extended self-tests terminaron `Completed without error`.

Durante los tests se uso un timer de notificacion y un inhibidor temporal:

```bash
systemd-run --user --unit=disk-smart-complete-hook \
  --on-calendar='<COMPLETION-TIME>' --collect \
  /usr/bin/bash /tmp/disk-smart-complete-hook.sh
systemd-run --user --unit=disk-smart-inhibit --collect \
  /usr/bin/systemd-inhibit --what=sleep:shutdown:idle \
  --why='Allow disk SMART extended tests to finish' /usr/bin/sleep 7200
systemd-inhibit --list --no-pager
```

## Btrfs escalonado

El primer disco se desmonto, identifico y formateo solo despues del backup:

```bash
(
  set -euo pipefail
  udisksctl unmount -b "$DEVICE_1"
  sudo mkfs.btrfs -f -U "$BTRFS_UUID" -L MirroredBackup "$DEVICE_1"
  sudo mkdir -p "$BTRFS_MOUNT"
  sudo mount -o compress=zstd:3,noatime "$DEVICE_1" "$BTRFS_MOUNT"
  test "$(findmnt -n -o UUID -T "$BTRFS_MOUNT")" = "$BTRFS_UUID"
  test "$(findmnt -n -o FSTYPE -T "$BTRFS_MOUNT")" = btrfs
  sudo chown "$USER:$USER" "$BTRFS_MOUNT"
)
```

Restauracion completa:
```bash
(
  set -euo pipefail
  test "$(findmnt -n -o UUID -T "$BTRFS_MOUNT")" = "$BTRFS_UUID"
  test "$(findmnt -n -o FSTYPE -T "$BTRFS_MOUNT")" = btrfs
  systemd-inhibit --what=sleep:shutdown:idle \
    --why='Restore verified backup to Btrfs' \
    ionice -c 2 -n 7 nice -n 15 rsync -aH \
    --no-owner --no-group --no-perms --protect-args \
    --partial-dir=.rsync-partial --sparse --fsync --bwlimit=35M \
    --human-readable --info=progress2,stats2 \
    "$BACKUP_ROOT/" "$BTRFS_MOUNT/"
)
```

Verificacion completa antes de destruir el antiguo filesystem:

```bash
systemd-inhibit --what=sleep:shutdown:idle \
  --why='Verify restored Btrfs copy' \
  ionice -c 3 nice -n 19 rsync -aHnc \
  --no-owner --no-group --no-perms --protect-args \
  --checksum-choice=xxh128 --human-readable --itemize-changes --stats \
  "$BACKUP_ROOT/" "$BTRFS_MOUNT/"
```

El segundo disco se desmonto y agrego solamente despues de verificar la copia
restaurada:

```bash
sudo umount "$SOURCE_MOUNT"
sudo btrfs device add -f "$DEVICE_2" "$BTRFS_MOUNT"
sudo btrfs balance start -mconvert=raid1 "$BTRFS_MOUNT"
systemd-inhibit --what=sleep:shutdown:idle \
  --why='Convert Btrfs data to RAID1' \
  sudo ionice -c 2 -n 7 nice -n 15 \
  btrfs balance start -dconvert=raid1 "$BTRFS_MOUNT"
```

Balance, scrub y comparacion final:

```bash
systemd-inhibit --what=sleep:shutdown:idle \
  --why='Final Btrfs RAID1 scrub' \
  sudo btrfs scrub start -B "$BTRFS_MOUNT"
systemd-inhibit --what=sleep:shutdown:idle \
  --why='Final RAID1 checksum verification' \
  ionice -c 3 nice -n 19 rsync -aHnc --delete \
  --no-owner --no-group --no-perms --protect-args \
  --checksum-choice=xxh128 --human-readable --itemize-changes --stats \
  "$BACKUP_ROOT/" "$BTRFS_MOUNT/"
```

El balance y ambos scrubs terminaron con status 0. La comparacion final reporto
cero archivos creados, eliminados, transferidos o diferentes.

## Observabilidad

```bash
btrfs filesystem df -b "$BTRFS_MOUNT"
btrfs filesystem usage -b "$BTRFS_MOUNT"
btrfs device stats -c "$BTRFS_MOUNT"
journalctl -k -b --since '10 minutes ago' \
  -g 'BTRFS|Buffer I/O|I/O error|critical' --no-pager
sensors
```

## Intentos fallidos sin efecto

- Un rsync fallo antes de copiar porque faltaba el directorio padre local.
- Un barrido de imagenes recibio un argumento fuente mal escrito y mostro
  usage; la ejecucion corregida y su checksum pasaron.
- Un inventario Python tuvo SyntaxError y un `du` uso una ruta mal escrita.
- Un `udisksctl unmount` expiro sin desmontar el NTFS; se verifico estado antes
  de continuar y se desmontaron ambos FUSE manualmente.
- Los Buffer I/O errors de un `/dev/sdX` obsoleto pertenecian a un montaje
  fantasma cuyo dispositivo ya no existia.
- `btrfs filesystem show` sin root mostro `MISSING` por permisos del block
  device; `filesystem usage`, sysfs y device stats confirmaron cero faltantes.

Ninguno de estos intentos produjo perdida de datos. Cada operacion corregida
fue seguida por verificaciones de tamano, checksum y errores del filesystem.
