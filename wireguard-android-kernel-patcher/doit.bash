#!/bin/bash

echo "========================================"
echo "= WireGuard for Android Kernel Patcher ="
echo "=              by zx2c4                ="
echo "========================================"
echo

if [[ $# -gt 2 || $# -lt 1 ]]; then
	echo "Usage: $0 [ --force-compat ] PATH_TO_KERNEL_SOURCE_ROOT" >&2
	exit 1
fi
FORCE_COMPAT=0
if [[ $# -eq 2 && $1 == --force-compat ]]; then
	FORCE_COMPAT=1
	shift
fi
SRC="$1"
SELF="$(readlink -f "$(dirname "$0")")"

echo "[+] Detecting kernel version..."
if [[ ! -f $SRC/include/linux/kernel.h ]] || [[ ! -f $SRC/Makefile ]] || [[ ! -d $SRC/.git ]]; then
	printf '[-] %q is not a Linux kernel source root\n' "$SRC"
	exit 1
fi
if [[ -d $SRC/net/wireguard || -d $src/drivers/net/wireguard ]]; then
	echo "[-] Kernel already has WireGuard"
	exit 1
fi
if ! [[ $(< "$SRC/Makefile") =~ VERSION[[:space:]]*=[[:space:]]*([0-9]+).*PATCHLEVEL[[:space:]]*=[[:space:]]*([0-9]+).*SUBLEVEL[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
	echo "[-] Unable to determine kernel version number"
	exit 1
fi
MAJ="${BASH_REMATCH[1]}"
MIN="${BASH_REMATCH[2]}"
SUB="${BASH_REMATCH[3]}"
echo " *  detected $MAJ.$MIN.$SUB series"
if (( (($MAJ * 65536) + ($MIN * 256) + $SUB) < ((3 * 65536) + (10 * 256) + 0) )); then
	echo "[-] WireGuard requires kernels >= 3.10"
	exit 1
fi
if [[ $FORCE_COMPAT -ne 1 && $MAJ.$MIN == 4.19 ]]; then
	echo "[+] Attemping to patch Android commons 4.19 patches of backported WireGuard"
	if git -C "$SRC" am --whitespace=nowarn -s "$SELF/for-4.19-kernels-only"/*.patch; then
		sed -i 's/tristate \("WireGuard.*\)/bool \1\n\tdefault y/' "$SRC/drivers/net/Kconfig"
		git -C "$SRC" commit -s -m "net: force CONFIG_WIREGUARD to be bool for Android kernels" "$SRC/drivers/net/Kconfig"
		echo "[+] Success! Remember to enable CONFIG_WIREGUARD=y (not =m or =n) in your kernel config"
		exit 0
	fi
	echo "[-] Failed to patch; undoing attempt and falling back"
	git am --abort
fi

echo "[+] Attempting to patch generic compat 3.10-5.5 WireGuard"
if ! patch -d "$SRC" --dry-run -s -p1 --no-backup-if-mismatch -r- < "$SELF/for-other-kernels/wireguard-linux-compat.patch"; then
	echo "[-] Patch does not apply"
	exit 1
fi
SOURCE_FILES=( )
while read -r pluses file _; do
	[[ $pluses == +++ && $file == b/* ]] || continue
	SOURCE_FILES+=( "${file#b/}" )
done < "$SELF/for-other-kernels/wireguard-linux-compat.patch"
if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
	echo "[-] Unable to account for changed files"
	exit 1
fi
if ! patch -d "$SRC" -p1 --no-backup-if-mismatch -r- < "$SELF/for-other-kernels/wireguard-linux-compat.patch"; then
	echo "[-] Unable to patch sources"
	exit 1
fi
sed -i -e 's/tristate "/bool "/' -e 's/default m/default y/' "$SRC/net/wireguard/Kconfig"
echo "[+] Committing to git repository"
if ! git -C "$SRC" add "${SOURCE_FILES[@]}" || ! git -C "$SRC" commit -s -m "net: add WireGuard from wireguard-linux-compat"; then
	echo "[-] Unable to commit source to git repository"
	exit 1
fi
echo "[+] Success! Remember to enable CONFIG_WIREGUARD=y (not =m or =n) in your kernel config"
exit 0
