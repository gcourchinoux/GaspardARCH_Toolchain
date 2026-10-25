#!/usr/bin/env bash
# Chaîne croisée GaspardARC : lancer dans le terminal MSYS2 MinGW64.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TARGET=gaspardarc-unknown-elf
DRY_RUN=0
case ${1:-} in
  --dry-run) DRY_RUN=1 ;;
  -h|--help)
    printf 'Usage : bash %s [--dry-run]\n' "${0##*/}"
    printf 'Menu interactif : Binutils, GCC ou les deux ; libgcc facultative.\n'
    printf 'Variables : PREFIX, JOBS, BUILD_TRIPLET, HOST_TRIPLET, CFLAGS,\n'
    printf '            CXXFLAGS, CC_FOR_BUILD, CFLAGS_FOR_TARGET.\n'
    printf '%s\n' '--dry-run affiche les commandes sans construire ni installer.'
    exit 0 ;;
  '') ;;
  *) printf 'Argument inconnu : %s\n' "$1" >&2; exit 2 ;;
esac

die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }
ask() {
  local answer
  if ! IFS= read -r -p "$1 [$2] : " answer; then
    die 'Saisie interrompue ; aucune étape supplémentaire ne sera lancée.'
  fi
  REPLY=${answer:-$2}
}
run() {
  printf '+ '; printf '%q ' "$@"; printf '\n'
  if (( ! DRY_RUN )); then "$@"; fi
}

printf '\nGaspardARC — ELF64 little endian, bare metal\n'
printf '  1) Binutils uniquement\n  2) GCC uniquement\n'
printf '  3) Binutils puis GCC\n  0) Quitter\n\n'
while :; do
  ask 'Votre choix' 3
  CHOICE=$REPLY
  case $CHOICE in 0) exit 0 ;; 1|2|3) break ;; *) printf 'Choisir 0, 1, 2 ou 3.\n' ;; esac
done

ask "Préfixe d'installation" "${PREFIX:-$ROOT/build-gaspardarc-install}"
PREFIX=$REPLY
if command -v cygpath >/dev/null 2>&1; then PREFIX=$(cygpath -u "$PREFIX"); fi
case $PREFIX in /*) ;; *) PREFIX="$ROOT/$PREFIX" ;; esac
# Résolution sans créer le répertoire (y compris en simulation).
PREFIX=$(realpath -m -- "$PREFIX")
case $PREFIX in "$ROOT"|"$ROOT/binutils-2.25"|"$ROOT/gcc-4.6.4"|/)
  die 'Choisir un répertoire d’installation distinct des sources et de la racine.' ;;
esac

while :; do
  ask 'Nombre de tâches parallèles' "${JOBS:-4}"
  JOBS=$REPLY
  if [[ $JOBS =~ ^[1-9][0-9]*$ ]]; then break; fi
  printf 'Saisir un entier strictement positif.\n'
done

WITH_LIBGCC=0
if [[ $CHOICE != 1 ]]; then
  while :; do
    ask 'Construire aussi la libgcc entière bare metal ? (o/n)' o
    case $REPLY in o|O|oui|Oui|y|Y) WITH_LIBGCC=1; break ;; n|N|non|Non) break ;; esac
  done
fi

for tool in gcc make sh realpath; do
  command -v "$tool" >/dev/null 2>&1 || die "Outil manquant : $tool (utiliser MSYS2 MinGW64)."
done
BUILD_TRIPLET=${BUILD_TRIPLET:-$(gcc -dumpmachine)}
HOST_TRIPLET=${HOST_TRIPLET:-$BUILD_TRIPLET}
[[ $HOST_TRIPLET == "$BUILD_TRIPLET" ]] || die 'Ce script construit des outils exécutables sur la machine de construction ; HOST_TRIPLET doit égaler BUILD_TRIPLET.'
export PATH="$PREFIX/bin:$PATH"
LEGACY='-O1 -std=gnu89 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types'
export CFLAGS=${CFLAGS:-$LEGACY}
export CXXFLAGS=${CXXFLAGS:--O1}
export CC_FOR_BUILD=${CC_FOR_BUILD:-"gcc $LEGACY"}
# Les options de compatibilité du GCC hôte ne conviennent pas au GCC 4.6 cible.
export CFLAGS_FOR_TARGET=${CFLAGS_FOR_TARGET:--O2 -ffreestanding}

check_source() {
  local source=$1 required=$2
  [[ -f "$source/configure" ]] || die "Sources introuvables : $source"
  if [[ ! -f "$source/$required" ]]; then
    if (( DRY_RUN )); then
      printf 'Simulation : backend absent dans %s ; appliquer les patchs avant la construction réelle.\n' "$source"
    else
      die "Backend GaspardARC absent dans $source. Appliquer la série décrite dans GaspardARCH/Patchs/README.md."
    fi
  elif ! sh "$source/config.sub" "$TARGET" >/dev/null; then
    die "Le config.sub de $source ne reconnaît pas $TARGET ; vérifier la série de patchs."
  fi
}
if [[ $CHOICE != 2 ]]; then check_source "$ROOT/binutils-2.25" bfd/elf64-gaspardarc.c; fi
if [[ $CHOICE != 1 ]]; then check_source "$ROOT/gcc-4.6.4" gcc/config/gaspardarc/gaspardarc.md; fi

printf '\nCible : %s\nHôte : %s\nInstallation : %s\nTâches : %s\n' "$TARGET" "$HOST_TRIPLET" "$PREFIX" "$JOBS"
printf 'Binutils : %s\nGCC : %s\nLibgcc : %s\n' \
  "$([[ $CHOICE != 2 ]] && printf oui || printf non)" \
  "$([[ $CHOICE != 1 ]] && printf oui || printf non)" \
  "$((WITH_LIBGCC))"
(( ! DRY_RUN )) || printf 'SIMULATION : aucune construction ni installation.\n'
while :; do
  ask 'Lancer ? (o/n)' o
  case $REPLY in o|O|oui|Oui|y|Y) break ;; n|N|non|Non) printf 'Annulé.\n'; exit 0 ;; esac
done

# Refuser de réutiliser un cache associé à une autre cible, un autre hôte
# ou un autre préfixe. Aucun ancien répertoire n’est effacé automatiquement.
prepare_build() {
  local dir=$1 expected=$2 marker="$1/.gaspardarc-build-config"
  if [[ -f "$marker" ]]; then
    [[ $(cat "$marker") == "$expected" ]] || die "Configuration différente dans $dir. Déplacer ce dossier avant de relancer avec la nouvelle configuration."
  elif [[ -d "$dir" && -n $(ls -A -- "$dir") ]]; then
    die "Répertoire de construction existant sans marqueur : $dir. Le déplacer avant de relancer (aucune suppression automatique)."
  fi
  if (( DRY_RUN )); then
    printf '+ cd %q\n' "$dir"
  else
    mkdir -p -- "$dir"
    cd -- "$dir"
  fi
}
mark_build() {
  if (( ! DRY_RUN )); then printf '%s\n' "$2" > "$1/.gaspardarc-build-config"; fi
}
CONFIG=$(printf '%s\n' "$TARGET" "$BUILD_TRIPLET" "$HOST_TRIPLET" "$PREFIX")

if [[ $CHOICE != 2 ]]; then
  DIR="$ROOT/build-binutils-gaspardarc-interactive"
  prepare_build "$DIR" "$CONFIG"
  mark_build "$DIR" "$CONFIG"
  run "$ROOT/binutils-2.25/configure" \
    --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --target="$TARGET" \
    --prefix="$PREFIX" --disable-nls --disable-werror --disable-shared \
    --disable-gold --disable-gprof
  run make -j"$JOBS" MAKEINFO=true
  run make MAKEINFO=true install
fi

if [[ $CHOICE != 1 ]]; then
  if (( ! DRY_RUN )); then
    for tool in as ld ar ranlib nm; do
      [[ -x "$PREFIX/bin/$TARGET-$tool" || -x "$PREFIX/bin/$TARGET-$tool.exe" ]] || \
        die "Installer d’abord Binutils dans $PREFIX : $TARGET-$tool absent."
    done
  fi
  DIR="$ROOT/build-gcc-gaspardarc-interactive"
  prepare_build "$DIR" "$CONFIG"
  mark_build "$DIR" "$CONFIG"
  run "$ROOT/gcc-4.6.4/configure" \
    --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --target="$TARGET" \
    --prefix="$PREFIX" --enable-languages=c --without-headers --with-newlib \
    --with-gnu-as --with-gnu-ld --disable-bootstrap --disable-nls \
    --disable-werror --disable-multilib --disable-shared --disable-threads \
    --disable-lto --disable-libssp --disable-libgomp --disable-libquadmath \
    --disable-libmudflap --disable-decimal-float --without-ppl --without-cloog
  run make -j"$JOBS" MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" all-gcc
  run make MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" install-gcc
  if (( WITH_LIBGCC )); then
    run make -j"$JOBS" MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" all-target-libgcc
    run make MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" install-target-libgcc
  fi
fi
if (( DRY_RUN )); then
  printf '\nSimulation terminée.\n'
else
  printf '\nConstruction et installation terminées dans %s\n' "$PREFIX"
  printf 'Pour utiliser les outils : export PATH=%q/bin:$PATH\n' "$PREFIX"
fi
