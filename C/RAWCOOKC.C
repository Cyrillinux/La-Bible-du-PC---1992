/***********************************************************************
*                         R A W _ C O O K C                            *
**--------------------------------------------------------------------**
*    Fonction       : offre deux fonctions permettant de faire passer  *
*                     un driver de caractŠre en mode RAW ou en mode    *
*                     COOKED.                                          *
**--------------------------------------------------------------------**
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 16/08/1987                                       *
*    DerniŠre modif.: 29/02/1989                                       *
**--------------------------------------------------------------------**
*    (MICROSOFT C)                                                     *
*    Cr‚ation       : CL /AS RAW_COOK.C                                *
*    Appel          : RAW_COOK                                         *
**--------------------------------------------------------------------**
*    (BORLAND TURBO C)                                                 *
*    Cr‚ation       : Avec instruction RUN dans ligne d'instruction    *
*                     (sans fichier Project)                           *
***********************************************************************/

/*== Int‚grer fichiers Include =======================================*/
#include <dos.h>
#include <stdio.h>
#include <conio.h>

/*== Constantes ======================================================*/
#define ENTSTAND 0                 /* handle 0 = p‚riph. d'entr‚e std */
#define SORSTAND 1                /* handle 1 = p‚riph. de sortie std */

/***********************************************************************
* GETMODE: lit l'attribut d'un driver de p‚riph‚rique                  *
* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …        *
*          appeler.                                                    *
* Sortie : L'attribut de p‚riph‚rique                                  *
***********************************************************************/

int GetMode( int Handle )
{
 union REGS Register;                  /* Reg. d'appel d'interruption */

 Register.x.ax = 0x4400;   /* Num‚ro de fonction pour IOCTL: Get Mode */
 Register.x.bx = Handle;
 intdos(&Register, &Register);   /* Appeler interruption du DOS 21(h) */
 return(Register.x.dx);       /* Transmettre attribut de p‚riph‚rique */
}

/***********************************************************************
* SETRAW: fait passer un driver de caractŠre en mode RAW               *
* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …        *
*          appeler                                                     *
* Sortie : Aucune                                                      *
***********************************************************************/

void SetRaw( int Handle )
{
 union REGS Register;                  /* Reg. d'appel d'interruption */

 Register.x.ax = 0x4401;              /* Nø fonction IOCTL : Set Mode */
 Register.x.bx = Handle;
 Register.x.dx = (GetMode(Handle) & 255) | 32;  /* Nvl attrb. p‚riph. */
 intdos(&Register, &Register);   /* Appeler interruption du DOS 21(h) */
}

/***********************************************************************
* SETCOOKED: fait passer un driver de caractŠre en mode COOKED         *
* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …        *
*          appeler.                                                    *
* Sortie : Aucune                                                      *
***********************************************************************/

void SetCooked( int Handle )
{
 union REGS Register;                  /* Reg. d'appel d'interruption */

 Register.x.ax = 0x4401;              /* Nø fonction IOCTL : Set Mode */
 Register.x.bx = Handle;
 Register.x.dx = GetMode(Handle) & 223; /* Nouvel attribut de p‚riph. */
 intdos(&Register, &Register);   /* Appeler interruption du DOS 21(h) */
}

/***********************************************************************
* SORTIETEST: sort une chaŒne de test 1000 fois sur le p‚riph‚rique    *
*             de sortie standard.                                      *
* Entr‚e : Aucune                                                      *
* Sortie : Aucune                                                      *
***********************************************************************/

void SortieTest( void )
{
 int          i;                                /* Variable de boucle */
 static char  Test[] = "Test.... ";              /* Le texte … sortir */

 printf("\n");
 for( i = 0; i < 1000; i++ )                      /* Sortir 1000 fois */
   fputs( Test, stdout );  /* Sortir chaŒne sur p‚riph. de sortie std */
 printf("\n");
}

/**********************************************************************/
/**                         PROGRAMME PRINCIPAL                      **/
/**********************************************************************/

void main()

{
 printf("\nRAWCOOKC (c) 1987, 92 by Michael TISCHER\n\n");
 printf("Le driver de console (Clavier, ‚cran) se trouve maintenant\n");
 printf("en mode RAW. C'est pourquoi, lors des sorties suivantes,\n");
 printf("les caractŠres de commande comme <CTRL-S> par exemple ne\n");
 printf("seront pas identifi‚s.\n");
 printf("Essayez et vous verrez.\n\n");
 printf("Frappez une touche pour commencer...");
 getch();                                      /* Attendre une touche */
 SetRaw(ENTSTAND);      /* Faire passer driver de console en mode RAW */
 SortieTest();
 while( kbhit())            /* Eliminer du buffer clavier les touches */
                                              /* entr‚es entre-temps. */
 printf("Le driver de console se trouve maintenant en mode COOKED.\n");
 printf("Les touches de commande comme <CTRL-S> par exemple, sont \n");
 printf("identifi‚es lors de la sortie et trait‚es en cons‚quence !\n");
 printf("Veuillez frapper une touche pour commencer...");
 getch();                                      /* Attendre une touche */
 SetCooked(ENTSTAND);   /* Faire passer driver console en mode COOKED */
 SortieTest();
}