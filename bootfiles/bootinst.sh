#!/bin/sh
# Setup booting dengan deteksi otomatis perangkat fisik (USB/HDD/SSD)

# 1. Deteksi lokasi folder tempat script ini berada
BOOT="$(cd "$(dirname "$0")" && pwd)"
echo "Lokasi instalasi terdeteksi di: $BOOT"

# 2. Temukan partisi menggunakan 'df'
# Kita gunakan tail dan awk untuk mengambil path device (misal /dev/sdb1 atau /dev/nvme0n1p1)
PART="$(df "$BOOT" | tail -n 1 | awk '{print $1}')"

# 3. Validasi: Pastikan ini adalah block device fisik
if [ ! -b "$PART" ]; then
   echo "Error: Lokasi $BOOT berada di $PART (bukan disk fisik)."
   echo "Pastikan Anda menjalankan script dari USB atau HDD yang sudah di-mount."
   exit 1
fi

# 4. Deteksi Device Induk (Raw Disk)
# Logika ini untuk memisahkan partisi (/dev/sdb1) menjadi drive (/dev/sdb)
# Mendukung format /dev/sdX dan /dev/nvmeXnXpX
if echo "$PART" | grep -q "nvme"; then
   DEV=$(echo "$PART" | sed -r "s:p[0-9]+\$::") # Untuk NVMe
else
   DEV=$(echo "$PART" | sed -r "s:[0-9]+\$::")   # Untuk SATA HDD/USB
fi

echo "Partisi Aktif: $PART"
echo "Drive Utama  : $DEV"

# 5. Cek Arsitektur
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH=64; else ARCH=32; fi
EXTLINUX=extlinux.x$ARCH

# Pindah ke direktori kerja
CWD="$(pwd)"
cd "$BOOT"

if [ ! -x "./$EXTLINUX" ]; then
   chmod +x "./$EXTLINUX" 2>/dev/null
fi

# 6. Jalankan Instalasi Extlinux
echo "Menginstal bootloader ke $BOOT..."
./"$EXTLINUX" --install .

if [ $? -eq 0 ]; then
   # Pasang MBR (Master Boot Record) ke Drive Utama
   if [ -f "./mbr.bin" ]; then
      echo "Menulis MBR ke $DEV..."
      dd bs=440 count=1 conv=notrunc if="./mbr.bin" of="$DEV" 2>/dev/null
   fi

   # Set flag Bootable (Active) menggunakan fdisk
   echo "Mengaktifkan flag bootable pada $PART..."
   # Ambil nomor partisi saja
   PART_NUM=$(echo "$PART" | grep -o '[0-9]*$' | head -n 1)
   
   (
     echo a # toggle bootable flag
     echo "$PART_NUM"
     echo w # simpan perubahan
   ) | fdisk "$DEV" >/dev/null 2>&1

   echo "------------------------------------------------"
   echo "BERHASIL! Bootloader terpasang di $DEV ($PART)."
   echo "Perangkat ini sekarang bisa digunakan untuk booting."
else
   echo "Gagal menginstal extlinux. Pastikan partisi diformat FAT32/EXT4."
fi

cd "$CWD"
