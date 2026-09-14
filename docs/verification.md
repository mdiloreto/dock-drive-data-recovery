# Evidencia de verificacion

## Backup NVMe

| Control | Resultado |
|---|---|
| Ruta | `$HOME/recovery-backup` |
| Bytes aparentes finales | `523306931473` |
| Btrfs write/read/flush errors | `0/0/0` |
| Btrfs corruption/generation errors | `0/0` |
| Comparaciones por lote | Sin diferencias xxh128 |
| Imagenes detectables | 8,403, verificadas |

Se validaron muestras locales JPEG, HEIF, WAV, MP4, pelicula y archivo de
proyecto comprimido. Los logs de transferencia originales estan fuera de este repo,
en el backup y en el workspace de seguimiento.

## Restauracion al primer Btrfs

| Control | Resultado |
|---|---|
| UUID | `<BTRFS_UUID>` |
| Label | `MirroredBackup` |
| Mount | `/mnt/MirroredBackup` |
| Archivos regulares | 29,937 |
| Directorios | 3,493 |
| Bytes fuente/destino | `523306931473` / `523306931473` |
| Full xxh128 dry-run | Cada archivo fuente coincidio; no verifico archivos extra en destino |
| Errores Btrfs post-lectura | 0 en todas las categorias |

## SMART

| Disco | Extended test | Reallocated | Pending | Offline uncorrectable | Temp captura |
|---|---|---:|---:|---:|---:|
| Device 1 | Completed without error | 0 | 0 | 0 | 37 C |
| Device 2 | Completed without error | 0 | 0 | 0 | 34 C |

Los error logs historicos contienen comandos abortados antiguos, no errores
UNC actuales. El WD10EZRX sigue clasificado como envejecido por horas y load
cycles.

## Errores operativos explicados

- Un rsync de un segundo arbol de grabaciones fallo antes de copiar porque faltaba el directorio
  padre del destino. Se creo el padre, se repitio y se verifico completo.
- El primer barrido de imagenes tuvo un argumento fuente mal escrito. No copio
  datos; la ejecucion corregida y su checksum pasaron.
- Un inventario Python tuvo un SyntaxError y otro `du` una ruta mal escrita.
  Ninguno modifico datos; ambos se repitieron correctamente.
- `udisksctl unmount` del NTFS expiro. Los dos montajes FUSE se desmontaron
  manualmente y se verifico cero montajes antes de agregar el disco.
- Los Buffer I/O errors de `/dev/sda1` ocurrieron al retirar un montaje fantasma
  cuyo dispositivo ya no existia; no correspondian al WD10EZEX actual.
- `btrfs filesystem show` sin root marco dispositivos `MISSING` porque no podia
  abrir nodos `root:disk`. `btrfs filesystem usage` reporto siempre
  `Device missing: 0`, y los ioctls mostraron ambos dispositivos.

## Gate final completado

La migracion fue aceptada con estos resultados:

1. El balance termino con status 0.
2. `btrfs filesystem df` no muestra `Data,single`.
3. Data, metadata y system aparecen exclusivamente como RAID1.
4. Ambos juegos de device stats estan en cero.
5. Ambos miembros terminaron scrub con status 0 y sin errores.
6. La comparacion final `-n --delete` reporto cero archivos faltantes,
   diferentes o adicionales sin borrar archivos.

La comparacion original sin `--delete` demostro que todos los archivos fuente
coincidian por contenido, pero no podia detectar archivos presentes solamente
en el destino. El gate final corrigio esta limitacion.
