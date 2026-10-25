# Validation de la série GaspardARC

Date : 25 octobre 2026. Sources : Binutils 2.25 et GCC 4.6.4 du dépôt.
Compilateur hôte : MinGW64 GCC 16.2.0. Constructions et installations effectuées dans une copie isolée.

## Résultats

- **Série Git — OK** : 9 patchs : git apply --check, application, contenu exact et annulation complète dans une copie isolée.
- **Construction Binutils 2.25 — OK** : BFD, opcodes, GAS, GNU ld et outils binutils construits puis installés sous MinGW64.
- **Fixture fournie, assemblage + lien — OK** : 885/885 mots conformes ; 0 différences
- **ELF et readelf — OK** : ELF64 little endian, e_machine privé 0xfe64, noms des relocalisations reconnus.
- **objdump / désassemblage — OK** : Décodage des instructions entières, FPU, atomiques, CSR et sauts.
- **Données et octets — OK** : .dword little endian et .word de 4 octets vérifiés.
- **Diagnostics GAS — OK** : 10 instructions invalides rejetées (registres, bornes, FLI/rm, suffixe, désalignement).
- **Relocalisations interobjets et ld -r — OK** : Liens direct et partiel identiques ; pointeur ABS64 vers symbole externe correct.
- **Diagnostics ld — OK** : Débordements BRANCH, JAL, HI20 et cible non alignée : liens refusés.
- **objcopy — OK** : Copie objet avec relocalisations puis lien identique ; export binaire .text identique.
- **Construction GCC 4.6.4 — OK** : Compilateur C, générateurs et backend construits et installés ; compilateur hôte MinGW GCC 16.2.0.
- **C entier -O0 — OK** : Compilation, assemblage, lien et modèle entier limité : signature 0x600d, retour 0, 789 instructions.
- **C entier -O2 — OK** : Compilation, assemblage, lien et modèle entier limité : signature 0x600d, retour 0, 443 instructions.
- **C entier -Os — OK** : Compilation, assemblage, lien et modèle entier limité : signature 0x600d, retour 0, 452 instructions.
- **Diagnostics GCC — OK** : PIC et définitions de fonctions variadiques rejetés explicitement.
- **Couverture C exécutée dans le modèle — LIMITÉE** : Récursion, 10 arguments, grandes frames, conversions signées/non signées, structures, appel indirect, switch, pointeurs globaux et décalages 64 bits. Aucun matériel ni simulateur officiel disponible.
- **libgcc entier — OK** : Construction et liens réussis ; popcount, clz, ctz et bswap 64 bits exécutés dans le modèle à -O0 et -O2. Flottants/complexes exclus.
- **Outils installés / script livré — OK** : tester_c.py --libgcc exécuté avec les outils installés : 5 scénarios réussis (-O0, -O2, -Os puis auxiliaires à -O0/-O2).
- **__clear_cache — OK** : Présence de fence.i vérifiée dans le désassemblage de l’auxiliaire libgcc.
- **Matériel / simulateur officiel — NON TESTÉ** : Aucun processeur ni simulateur officiel connecté. Le modèle entier fourni ne couvre pas MMU, FPU, caches, interruptions ou atomiques.
- **Périmètre non validé — NON TESTÉ** : ABI/opérations 128 bits, C++, PIC/TLS, exceptions, varargs et relaxation ; voir limites du profil.

## Portée des résultats

Le fichier `isa_risc64_test.S` fourni s’assemble intégralement. Après lien avec
`.text=0` et `.data=0x10000`, les **885 mots sur 885** sont identiques au fichier
attendu fourni. Cette comparaison indépendante porte aussi sur les expansions
de pseudos, notamment les grandes constantes, et sur les branchements /4 propres à l’ISA.

Les tests C vérifient récursion, dix arguments, grandes frames, conversions,
structures passées/retournées, appels indirects, switch et pointeurs globaux.
Ils s’exécutent dans le **modèle entier limité** livré par le patch 0009, avec
signature finale `0x600d` et retour `0`. Ce modèle est un outil de test du portage,
pas une validation du processeur ni un simulateur complet de l’architecture.

Le profil entier de libgcc exclut volontairement les routines flottantes,
complexes et de trampolines. Les auxiliaires popcount/clz/ctz/bswap 64 bits ont
été liés et exécutés dans ce modèle. Cela ne valide pas tous les membres de libgcc,
ni ses éventuelles interfaces 128 bits. Aucun support soft-float complet n’est annoncé.

## Reproduction et environnement

Consulter `README.md`. Les patchs ajoutent un script de construction et les sources
des tests. `verifier_elf.py` compare le binaire lié à la fixture existante ;
`GaspardARCH/Tests/tester_c.py --libgcc`, après application et installation, rejoue
les tests C et les auxiliaires avec le modèle entier.

Pendant la validation, GCC a initialement été configuré alors que les nouveaux
Binutils étaient encore en construction. Ses scripts d’outils générés ont ensuite
été renseignés avec les chemins des Binutils construits, uniquement dans la copie
isolée. Le workflow livré installe Binutils avant de configurer GCC, pour que ces
chemins soient détectés normalement. Les options de compatibilité hôte sont
séparées de `CFLAGS_FOR_TARGET` ; elles ne doivent pas être transmises à GCC 4.6.4
pour compiler libgcc cible. Les anciens outils émettent encore des avertissements
avec le compilateur hôte moderne ; les constructions finales ont réussi.

Les journaux de tests détaillés et le manifeste sont dans `validation/`.
Les journaux comprennent les diagnostics négatifs attendus : ces erreurs font
partie des tests de rejet et ne constituent pas des échecs de la série finale.

## Référence et empreintes

Commit de référence : `30f442d285d629dbd9175240360406f8406a3f8b`.

SHA-256 du CSV utilisé : `950ddfe77a5c4e0ed190e197bc8707a083c9a8b60e2a6d4c1571901de4fa4137`.

Les empreintes des livrables figurent dans `SHA256SUMS`. Les sources originales et les fixtures fournies restent inchangées.
