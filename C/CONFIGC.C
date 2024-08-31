
/**********************************************************************/
/*                           C O N F I G C                            */
/*--------------------------------------------------------------------*/
/*    Fonction        : Affiche la configuration du PC sur l'‚cran    */
/*                                                                    */
/*--------------------------------------------------------------------*/
/*    Auteur          : MICHAEL TISCHER                               */
/*    D‚velopp‚ le    : 13.08.1987                                    */
/*    DerniŠre modif. : 19.02.1992                                    */
/*--------------------------------------------------------------------*/
/*    ModŠle de m‚moire : SMALL                                       */
/**********************************************************************/

/*== Int‚grer les fichiers Include ===================================*/

#include <dos.h>                      /* Int‚grer les fichiers Header */
#include <stdio.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;     /* Voil… comment se bricoler un OCTET */

/*== Macros ==========================================================*/

#ifdef MK_FP
  #undef MK_FP
#endif

#ifdef peekb
  #undef peekb
#endif

#define MK_FP(seg, ofs) ((void far *) ((unsigned long) (seg)<<16|(ofs)))
#define peekb(seg, ofs) *((BYTE far *) MK_FP(seg, ofs))

/*== Constantes ======================================================*/

#define TRUE  ( 0 == 0 )      /* Constantes pour faciliter la lecture */
#define FASLE ( 0 == 1 )      /* du texte du programme                */

/**********************************************************************/
/* CLS: Effacer l'‚cran et placer le curseur dans le coin sup‚rieur   */
/*      gauche de l'‚cran                                             */
/* Entr‚e : Aucune                                                    */
/* Sortie : Aucune                                                    */
/**********************************************************************/

void Cls( void )
{
 union REGS Register;         /* Registres pour appeler l'interruption*/

 Register.h.ah = 6;              /* Num‚ro de fonction pour Scroll-UP */
 Register.h.al = 0;                                 /* 0 pour effacer */
 Register.h.bh = 7;                  /* Ecriture claire sur fond noir */
 Register.x.cx = 0;               /* Coin sup‚rieur gauche de l'‚cran */
 Register.h.dh = 24;                 /* Coordonn‚es du coin inf‚rieur */
 Register.h.dl = 79;                             /* droit de l'‚cran  */
 int86(0x10, &Register, &Register);     /* interruption vid‚o du BIOS */

 Register.h.ah = 2;        /* Fonction pour fixer position du curseur */
 Register.h.bh = 0;                                   /* Page ‚cran 0 */
 Register.x.dx = 0;   /* Coordonn‚es coin sup‚rieur gauche de l'‚cran */
 int86(0x10, &Register, &Register);     /* Interruption vid‚o du BIOS */
}

/**********************************************************************/
/* PRINTCONFIG: Affichage de la configuration d'un PC                 */
/* Entr‚e : Aucune                                                    */
/* Sortie : Aucune                                                    */
/* Infos    : La configuration est affich‚e en fonction du type de PC */
/*                                                                    */
/**********************************************************************/

void PrintConfig( void )
{
 union REGS Register;        /* Registres pour appeler l'interruption */
 BYTE AT;                                         /* AT ou sup‚rieur? */

 Cls();                                            /* Effacer l'‚cran */
 AT = (peekb(0xF000, 0xFFFE) == 0xFC);
 printf("CONFIGC  -  (c) 1987, 92 by Michael Tischer\n\n");
 printf("Configuration de votre PC\n");
 printf("----------------------------------------------------------\n");
 printf("Type de PC                 : ");

 switch( peekb(0xF000, 0xFFFE) )                        /* Type de PC */
  {
   case 0xFF : printf("PC\n");             /* 0xFF c'est un PC normal */
               break;
   case 0xFE : printf("XT\n");                    /* 0xFE c'est un XT */
               break;
   default   : printf("AT ou sup‚rieur\n");       /* 0xFC c'est un AT */
               break;
  }
 printf("M‚moire RAM                : ");
 int86(0x12, &Register, &Register);       /* Lire la taille de la RAM */
 printf("%d Ko\n",Register.x.ax);                    /* et l'afficher */
 if ( AT )                                     /* Ce PC est-il un AT? */
  {                                                            /* OUI */
   Register.h.ah = 0x88;    /* nø de fonction pour RAM suppl‚mentaire */
   int86(0x15, &Register, &Register);     /* Lire la taille de la RAM */
   printf("RAM suppl‚mentaire         : %u Ko au-dessus de 1Mo\n",
                            Register.x.ax);
  }
 int86(0x11, &Register, &Register);           /* Configuration (BIOS) */
 printf("Mode vid‚o initial         : ");
 switch(Register.x.ax & 48)
  {
   case  0 : printf("Ind‚fini\n");
             break;
   case 16 : printf("40*25 caractŠres couleur\n");
             break;
   case 32 : printf("80*25 caractŠres couleur\n");
             break;
   case 48 : printf("80*25 caractŠres mono\n");
             break;
  }
 printf("Lecteurs de disquette      : %d\n", (Register.x.ax >> 6 & 3) + 1);
 printf("Interfaces s‚rie           : %d\n", Register.x.ax >> 9 & 0x03);
 printf("Interfaces parallŠle       : %d\n\n", Register.x.ax >> 14);
}

/**********************************************************************/
/**                        PROGRAMME PRINCIPAL                       **/
/**********************************************************************/

void main()
{
 PrintConfig();                          /* Afficher la configuration */
}

