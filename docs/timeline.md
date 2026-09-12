# Cronologia

## 2026-09-11: diagnostico y rescate a la laptop

1. Se identificaron dos discos fisicos de 1 TB y nombres `/dev/sdX` inestables.
2. Se detecto NTFS dirty, geometria de aproximadamente 2 TB sobre una
   particion de 1 TB, historial LDM y un montaje FUSE fantasma `/dev/sda1`.
3. Se mantuvo el origen en solo lectura.
4. Se inventariaron 801 GiB visibles y se seleccionaron datos prioritarios.
5. Se copiaron y verificaron documentos, un backup movil, dos arboles de
   grabaciones, proyectos creativos, una biblioteca multimedia, todas las
   imagenes detectables y datos personales adicionales.
6. El limite de 60 MiB/s produjo un pico CPU de 93 C. Se establecio 35 MiB/s
   como limite seguro para escrituras largas.
7. Cada lote fue releido y comparado mediante rsync `xxh128`.

## 2026-09-12: validacion y construccion escalonada

1. Ambos discos completaron extended SMART self-tests sin error.
2. Se creo `MirroredBackup` sobre WD10EZRX solamente.
3. Se restauraron 523.31 GB desde la laptop al Btrfs single-device.
4. Se verificaron 29,937 archivos y 523,306,931,473 bytes mediante xxh128.
5. Se desmontaron el NTFS real y el montaje FUSE fantasma.
6. Se agrego WD10EZEX al filesystem, eliminando la firma NTFS.
7. Metadata y system se convirtieron de DUP a RAID1 con balance status 0.
8. A las 13:20:35 comenzo la conversion de data de single a RAID1.

## Contenido deliberadamente excluido

Antes de destruir NTFS se acepto excluir 312.61 GiB:

| Grupo | Tamano |
|---|---:|
| Imagenes de maquinas virtuales | 216.31 GiB |
| `$RECYCLE.BIN` | 66.14 GiB |
| instaladores | 18.10 GiB |
| Plantillas de maquinas virtuales | 11.38 GiB |
| Drivers/utilidades/sistema | menos de 1 GiB |

Las imagenes detectadas dentro de grupos excluidos si fueron preservadas por
el barrido global.
