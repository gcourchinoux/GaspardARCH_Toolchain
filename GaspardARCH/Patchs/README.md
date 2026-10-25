# Patchs Git GaspardARC — Binutils 2.25 et GCC 4.6.4

Cette série ajoute une cible expérimentale `gaspardarc-unknown-elf`, ELF64 little endian, à partir du CSV et du test d'encodage fournis dans `GaspardARCH/`. Le nom public reste **GaspardARC** ; le dossier existant `GaspardARCH` est conservé.

Les sources de travail ne sont pas modifiées : les changements sont livrés dans les fichiers `.patch`. Les constructions de validation utilisent une copie isolée.

## Contenu

Lire **Recapitulatif_patchs_GaspardARC.xlsx** : les feuilles *Patchs*, *Fichiers*, *ISA*, *Choix ABI*, *Validation* et *Mode emploi* expliquent les changements et leurs limites. La feuille ISA comporte les 246 instructions et pseudos du CSV. `series` donne l'ordre exact des neuf patchs.

| Ordre | Thème |
|---|---|
| 0001 | Triplet GNU, architecture BFD et contrat ABI v0 |
| 0002 | Table des 198 instructions matérielles et désassembleur |
| 0003 | ELF64, identifiant machine privé, relocalisations BFD |
| 0004 | Émulation GNU ld et affichage readelf |
| 0005 | GAS, opérandes, CSR, flottants, atomiques et 48 pseudos |
| 0006 | GCC : configuration, LP64, registres, pile et convention d'appel |
| 0007 | GCC : motifs RTL du cœur entier |
| 0008 | Bootstrap libgcc, démarrage RAM et tests C |
| 0009 | Script de construction et tests d'intégration |

Ces fichiers sont des **diffs Git pour `git apply`**, et non des messages `git format-patch` pour `git am`. Ils ne créent pas de commits automatiquement.

## Appliquer avec Git

Depuis la **racine du dépôt**, dans Bash MSYS2/MinGW64, après avoir sauvegardé vos changements suivis par Git :

```bash
git status --short

while IFS= read -r patch; do
  git -c core.autocrlf=false apply --check "GaspardARCH/Patchs/$patch" || break
  git -c core.autocrlf=false apply "GaspardARCH/Patchs/$patch" || break
done < GaspardARCH/Patchs/series

git diff --stat
git status --short
```

Appliquer toute la série dans cet ordre. Le contrôle de chaque patch suppose que les précédents sont déjà appliqués. `core.autocrlf=false` préserve les fins de ligne LF des scripts GNU sous Windows. Si un patch échoue, arrêter la série et examiner le message ; les patchs précédents peuvent déjà être appliqués. La série est contrôlée dans une copie isolée avec application puis annulation complète.

Les nouveaux fichiers créés par `git apply` restent non suivis jusqu'à `git add`. Examiner les changements avant de faire vos commits. Pour conserver les thèmes dans l'historique, appliquer un patch, ajouter ses fichiers avec `git add`, puis faire un commit avant de passer au suivant. Le classeur liste les fichiers de chaque patch. Il faut terminer la série avant de construire la chaîne.

Pour annuler une série fraîchement appliquée, sans modifications ultérieures sur ses fichiers :

```bash
tac GaspardARCH/Patchs/series | while IFS= read -r patch; do
  git -c core.autocrlf=false apply --reverse --check "GaspardARCH/Patchs/$patch" || break
  git -c core.autocrlf=false apply --reverse "GaspardARCH/Patchs/$patch" || break
done
```

Après création de commits, utiliser votre workflow habituel de `git revert` pour préserver l'historique partagé.

## Construire après application

Dans le terminal MSYS2 **MinGW64**, avec `gcc`, `make`, les dépendances GNU et les dépendances arithmétiques de GCC disponibles :

```bash
bash GaspardARCH/build-toolchain.sh binutils
bash GaspardARCH/build-toolchain.sh gcc
# Étape distincte, à valider avant d'utiliser les auxiliaires du runtime :
bash GaspardARCH/build-toolchain.sh libgcc
```

Le préfixe par défaut est `build-gaspardarc-install`, distinct du port i386. `PREFIX` et `JOBS` sont personnalisables. Le script n'utilise ni `--with-arch=i386` ni `-march=i386`. Il transmet explicitement `CC_FOR_BUILD` à make pour les tests historiques de GMP et sépare `CFLAGS_FOR_TARGET` des options du compilateur hôte moderne. `MAKEINFO=true` évite de régénérer les anciens manuels ; il ne désactive pas la compilation du code.

## Vérifier votre fixture d'encodage

Après installation de Binutils :

```bash
export PATH="$PWD/build-gaspardarc-install/bin:$PATH"
mkdir -p build-tests-gaspardarc
gaspardarc-unknown-elf-as GaspardARCH/Tests/isa_risc64_test.S \
  -o build-tests-gaspardarc/isa.o
gaspardarc-unknown-elf-ld -Ttext=0 -Tdata=0x10000 \
  build-tests-gaspardarc/isa.o -o build-tests-gaspardarc/isa.elf
gaspardarc-unknown-elf-readelf -h -r build-tests-gaspardarc/isa.o
gaspardarc-unknown-elf-objdump -d build-tests-gaspardarc/isa.elf
python GaspardARCH/Patchs/verifier_elf.py build-tests-gaspardarc/isa.elf
```

`verifier_elf.py` ne demande aucun module Python externe. Il compare les mots machine de `.text` au fichier attendu fourni. Si votre interpréteur Python porte un autre nom, remplacer `python` par son chemin. Le résultat réellement obtenu pendant cette tâche figure dans `VALIDATION.md` et dans le classeur.

Après application du patch 0009, les tests C sont également reproductibles :

```bash
python GaspardARCH/Tests/tester_c.py
# Après construction et installation de libgcc :
python GaspardARCH/Tests/tester_c.py --libgcc
```

Ces tests exécutent les fichiers ELF dans un **modèle entier limité** fourni avec la série. Ils vérifient la compilation, l'ABI et les résultats calculés ; ils ne simulent pas les interruptions, caches, MMU, FPU ou atomiques. Pour un préfixe différent, définir `GASPARDARC_PREFIX`.

## Choix expérimentaux et périmètre

Le CSV décrit l'ISA mais pas toute l'ABI C. La série propose LP64, pile alignée à 16 octets, arguments scalaires dans `a0-a7`, résultat dans `a0`, agrégats passés par référence. Le contrat détaillé apparaît dans `GaspardARCH/docs/ABI-v0.md` après application du patch 0001.

`EM_GASPARDARC = 0xFE64` est un identifiant **privé, non attribué officiellement**. Les branchements et JAL utilisent les champs et l'échelle ×4 de votre ISA, différents de RISC-V. Les paires PC-relatives HI20/LO12 sont adjacentes et référencent le même symbole ; elles ne suivent pas la convention des étiquettes `%pcrel_lo` de RISC-V. Leur portée est contrôlée au lien.

GAS prend en charge les encodages flottants et atomiques du CSV. Le backend GCC fournit un premier cœur entier ; la sélection FPU, les atomiques spécialisées et un runtime soft-float complet ne sont pas fournis. Les auxiliaires flottants et complexes sont exclus de `libgcc` dans ce profil. Les entiers jusqu'à 64 bits sont le périmètre validé ; les opérations et interfaces 128 bits ne sont pas validées. Les définitions de fonctions variadiques, PIC et trampolines sont rejetés. TLS, C++, exceptions, relaxation et support d'un système d'exploitation restent hors du profil initial. Le démarrage fourni vise une image entièrement en RAM ; le script mémoire est un exemple à adapter à votre carte.

Les états de compilation, de comparaison des encodages et d'exécution sont séparés dans `VALIDATION.md` : une application Git réussie ne suffit pas à valider un backend.

Référence des interfaces GCC : [GCC 4.6.4 Internals](https://gcc.gnu.org/onlinedocs/gcc-4.6.4/gccint.pdf). Les raccordements sont fondés sur les sources locales de GCC 4.6.4 et Binutils 2.25.
