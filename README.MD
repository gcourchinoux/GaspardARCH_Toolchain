# GaspardOS Toolchain 



Ce dépot contient des vieux toolchain GNU :

* GCC 4.6.4
* binutils-2.25


J'ai choisi ces vieilles toolchain car le code est bien documenté pour une utilisation dans un système CUSTOM OSDEV.


Et GCC 4.6.4 est conçu encore en C ! Ca m'évite de porter un libstdc++ pour GCC uniquement .....



# Comment construire 


Il faut MSYS2 MINGW64 (on compile sous Windows)

Il faut d'abord compiler BINUTILS et GCC pour windows vers i386-gaspardos-*

vous devez installer : 


```
pacman -S base-devel mingw-w64-x86_64-toolchain texinfo
```

Vous devez commencer par binutils : 

```
./windows_build_binutils_gaspardos.sh
```

Tout ceci étant une expérimentation : il y a encore des /c/projets/*

ensuite GCC:


```
./windows_build_gcc_gaspardos.sh
```


Vous aurez dans build/ un compilo + assembleur 

après il faut compiler Binutils et GCC avec la toolchain windows vers gaspardos 



```
./gaspardos_build_binutils_windows.sh
./gaspardos_build_gcc_windows.sh
```



Tout ceci est EXPERIMENTAL !!!! 


en release, il y a une toolchain windows et GaspardOS prebuilt

# GaspardARCH


GaspardARCH est une tentative de créer une architecture 64 bits RISC classique pour GaspardOS. 

Et en même temps, ça me permet de créer un processus pour patcher les suites de compilo GNU ancien. 

CODEX me permmet de faire une sorte de protypage qui m'aide beaucoup à bien "élaguer" l'immense jungle des docs sur les toolchain GNU....

Cette architecture se veut plûtot complete, des vecteurs de trap et un système de pagination est directement prévu. 

## Construire la toolchain GaspardARC

Appliquer d'abord les patchs dans l'ordre indiqué par [GaspardARCH/Patchs/README.md](GaspardARCH/Patchs/README.md), puis lancer depuis un terminal **MSYS2 MinGW64** :

```bash
bash gaspardarch_build_toolchain.sh
```

Le menu permet de construire **Binutils**, **GCC**, ou **Binutils puis GCC**. Il demande le préfixe d'installation, le nombre de tâches parallèles et, pour GCC, si la bibliothèque entière `libgcc` doit aussi être construite. Pour GCC seul, les Binutils GaspardARC doivent déjà être installés dans le préfixe choisi.

Les constructions utilisent `build-binutils-gaspardarc-interactive/` et `build-gcc-gaspardarc-interactive/`. L'installation se fait par défaut dans `build-gaspardarc-install/`. Aucun ancien dossier de construction n'est supprimé automatiquement.

Pour parcourir le menu et afficher les commandes sans construire ni installer :

```bash
bash gaspardarch_build_toolchain.sh --dry-run
```

