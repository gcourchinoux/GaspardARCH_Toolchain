# ABI expérimentale GaspardARC v0

Triplet : gaspardarc-unknown-elf. ISA : CSV fourni (SHA-256 dans le manifeste).
ELF64 little endian, octets de 8 bits, instructions de 4 octets.
Identifiant ELF privé 0xFE64 : non attribué officiellement, collision possible.
Ne pas distribuer des objets comme une ABI officielle ; figer/changer cet identifiant ensemble.

Les alias du test fourni sont utilisés : r0/zero, r1/ra, r2/sp, r3/gp,
r4/tp, r5-r7/t0-t2, r8/s0/fp, r9/s1, r10-r17/a0-a7,
r18-r27/s2-s11, r28-r31/t3-t6. x0-x31 sont aussi acceptés.
ABI C proposée (absente du CSV, expérimentalement définie par cette série) :
LP64, char signé, float32/double64/long double64, alignement de pile 16 octets.
Arguments scalaires d'au plus 8 octets dans a0-a7 puis pile (slots de 8 octets).
Agrégats et valeurs de plus de 8 octets passés par référence ; agrégats retournés
en mémoire via un argument caché. Résultat scalaire dans a0.
Les registres s0-s11 sont préservés ; ra et les temporaires sont volatils.
gp/tp réservés, t6 réservé au backend pour les grandes frames.
Flottants dans les GPR selon l'ABI logicielle ; sélection FPU GCC non fournie.
Le GAS supporte les instructions flottantes du CSV indépendamment de GCC.
GCC : pas de PIC/TLS, pas de fonctions imbriquées avec trampoline, pas de C++.
Profil validé : entiers jusqu'à 64 bits. Opérations et interfaces 128 bits non validées.
Les auxiliaires flottants et complexes sont exclus de la libgcc initiale.
Les fonctions variadiques seront explicitement rejetées dans cette première série.

Relocalisations RELA privées : NONE=0, 64=1, 32=2, BRANCH=3, JAL=4,
PCREL_HI20=5, PCREL_LO12_I=6. Les deux dernières forment une paire adjacente.
HI20 calcule S+A-P ; LO12 calcule S+A-(P-4), en référençant le même symbole.
Le LO12 ne référence PAS une étiquette de la HI20 (convention distincte de RISC-V).
Portée paire : valeur dont le hi arrondi tient dans un signé 20 bits.
Branches : déplacement signé 12 bits multiplié par 4, champs S.
JAL : déplacement signé 20 bits multiplié par 4, champ contigu 31:12.
Pas de relaxation ; dépassements signalés. Toutes les relocalisations symboliques
sont conservées jusqu'au lien pour assurer le même calcul local/interobjets.
CSR nommés : numéros dérivés des mots du fichier expected fourni, pas du standard RISC-V.
