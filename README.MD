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

