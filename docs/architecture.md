# Arquitectura

## Estado inicial

La maquina tenia dos discos Western Digital de 1 TB conectados por el mismo
puente USB Prolific. El disco visible como NTFS presentaba una geometria
inconsistente: el filesystem declaraba aproximadamente 1.863 TiB dentro de una
particion de 931.5 GiB. El kernel tambien habia detectado ambos discos como
miembros Windows LDM/dynamic-disk antes de que uno fuese formateado EXT4.

El objetivo principal fue rescatar primero la informacion seleccionada sin
escribir sobre el NTFS, mantener una copia verificada en la NVMe y solo despues
reutilizar los discos externos.

## Copias conservadas durante la migracion

```text
Fase de rescate:
  NTFS read-only -> backup verificado en NVMe

Fase Btrfs inicial:
  NVMe -> WD10EZRX Btrfs single
  NVMe y WD10EZRX se verifican con xxh128

Fase RAID1:
  WD10EZEX se agrega al mismo filesystem
  Metadata/system: DUP -> RAID1
  Data: single -> RAID1

Final esperado:
  NVMe: backup independiente
  WD10EZRX + WD10EZEX: Btrfs RAID1
```

## Btrfs con dos discos

Btrfs administra directamente los dispositivos; no hay una capa `mdadm`.
Data, metadata y system tienen perfiles independientes. Con dos discos y
perfil RAID1, cada bloque logico tiene dos copias en dispositivos distintos.

```text
Logical extent A  -> copia A1 en WD10EZRX
                  -> copia A2 en WD10EZEX

Logical extent B  -> copia B1 en WD10EZEX
                  -> copia B2 en WD10EZRX
```

Dos discos de 1 TB entregan aproximadamente 1 TB utilizable, no 2 TB. La
redundancia protege contra la perdida de un disco, pero no contra eliminacion
accidental, malware, corrupcion de aplicaciones, robo ni fallos comunes del
dock USB, cable o fuente.

## Checksums y scrub

Btrfs almacena checksums de datos y metadata. Una lectura puede detectar una
copia corrupta y usar la copia sana. `btrfs scrub` recorre los bloques,
comprueba checksums y, con RAID1 completo, puede reparar una copia usando la
otra.

El scrub final no debe comenzar hasta que el balance termine y no queden block
groups `Data,single`.

## Hardware y riesgo residual

Ambos extended SMART self-tests terminaron sin error y no hay sectores
reasignados, pendientes ni offline-uncorrectable. Sin embargo:

- WD10EZEX Blue: aproximadamente 50,993 horas de encendido.
- WD10EZRX Green: aproximadamente 74,342 horas y 365,860 load cycles.
- El Green es hardware envejecido y debe reemplazarse proactivamente.
- Ambos discos comparten el mismo puente USB, que sigue siendo un punto unico
  de fallo.
