/**********************************************************************/
/*                             J O Y S T C                            */
/*--------------------------------------------------------------------*/
/*  Fonction        : D‚montre l'utilisation des Joysticks            */
/*                    … l'aide du BIOS                                */
/*--------------------------------------------------------------------*/
/*  Auteur          : MICHAEL TISCHER                                 */
/*  D‚velopp‚ le    : 25.02.1991                                      */
/*  DerniŠre modif  : 25.02.1991                                      */
/*    (MICROSOFT C)                                                   */
/*    Compilation    : CL /AS JOYSTC.C                                */
/*    Appel          : JOYSTC                                         */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    Compilation    : Avec les commandes COMPILE / MAKE              */
/**********************************************************************/

/*== Fichiers Include ===============================================*/

#include <dos.h>
#include <stdio.h>
#include <stdarg.h>

/*== D‚claration de types ============================================*/

typedef unsigned char BYTE;
typedef struct {                  /* D‚crit la position d'un Joystick */
                 int x;
                 int y;
               } JSPOS;

/***********************************************************************
*  ClrScr: Effacement de l'‚cran                                       *
**--------------------------------------------------------------------**
*  ParamŠtre d'entr‚e: COULEUR  = Attribut du caractŠre                *
*  Valeur de retour      : aucun                                       *
***********************************************************************/

void ClrScr( BYTE COULEUR )
{
 union REGS regs;                  /* regs. pour appel des interrupts */

    /*--Effacer l'‚cran … l'aide de la fonction Scroll-BIOS ----------*/

 regs.h.ah = 6;                /* Num‚ro de fonction pour Scroll-Down */
 regs.h.al = 0;                 /* Scroll de 0 ligne ( = effacement ) */
 regs.h.bh = COULEUR;                         /* COULEUR du caractŠre */
 regs.x.cx = 0;                /* coin sup‚rieur gauche de la fenˆtre */
 regs.x.dx = ( 24 << 8 ) + 79;                /* coin inf‚rieur droit */
 int86(0x10, &regs, &regs);        /* Appel de l'interrupt BIOS Video */

/*-- Placer le curseur dans le coin sup‚rieur gauche … l'aide du BIOS-*/

 regs.h.ah = 2;                 /* Num‚ro de fonction pour Set Cursor */
 regs.h.bh = 0;                                /* Acc‚der … la page 0 */
 regs.x.dx = 0;                        /* Coin sup. gauche de l'‚cran */
 int86(0x10, &regs, &regs);                  /* Appel int. vid‚o BIOS */
}

/***********************************************************************
*  printfat : Affiche une chaŒne format‚e en un endroit quelconque     *
*             de l'‚cran                                               *
**--------------------------------------------------------------------**
*  ParamŠtre d'entr‚e: COLONNE = Position de sortie                    *
*                     LIGNE                                            *
*                     STRING = Pointeur sur la chaŒne                  *
*                     ...    = Argument identique …  PRINTF()          *
*  Valeur de retour      : aucune                                      *
*  Info             : Cette fonction ne peut ˆtre appel‚e que si       *
*                     l'existence d'une carte EGA- ou VGA -            *
*                     a ‚t‚ confirm‚e                                  *
***********************************************************************/

void printfat( BYTE COLONNE, BYTE LIGNE, char * string, ... )
{
 va_list parameter;         /* Liste de paramŠtres pour macros VA_... */
 union REGS regs;              /* registres pour appel d'interruption */

/*-- Placer le curseur sur la position de sortie … l'aide du BIOS ----*/

 regs.h.ah = 2;                 /* Num‚ro de fonction pour Set Cursor */
 regs.h.bh = 0;                                /* Acc‚der … la page 0 */
 regs.h.dh = LIGNE;                                   /* ranger LIGNE */
 regs.h.dl = COLONNE;                               /* ranger COLONNE */
 int86(0x10, &regs, &regs);             /* Appel d'int. vid‚o du BIOS */

 /*-- Sortie de la chaŒne --------------------------------------------*/

 va_start( parameter, string );
 vprintf( string, parameter );
}

/***********************************************************************
*  Fonction         : G E T J O Y B U T T O N                          *
**--------------------------------------------------------------------**
*  Fonction          : Retourne l'emplacement des boutons de Joystick  *
*  ParamŠtre d'entr‚e: J1B1 = Ptr sur var. pour Bouton 1 / Joystick 1  *
*                     J1B2 = Ptr sur var. pour Bouton 2 / Joystick 1   *
*                     J2B1 = Ptr sur var. pour Bouton 1 / Joystick 2   *
*                     J2B2 = Ptr sur var. pour Bouton 2 / Joystick 2   *
*  Valeur de retour      : aucune                                      *
*  Info             : Les diverses variables re‡oivent la val. 1 (TRUE)*
*                     lorsque le bouton correspondant du joystick      *
*                     est appuy‚, sinon 0 (FALSE).                     *
***********************************************************************/

void GetJoyBouton( BYTE *j1b1, BYTE *j1b2, BYTE *j2b1, BYTE *j2b2 )
{
 union REGS regs;                               /* pour les registres */

 regs.h.ah = 0x84;                                    /* Fonction 84h */
 regs.x.dx = 0;                                  /* Sous-fonction 00h */
 int86( 0x15, &regs, &regs );                        /* Appel Int 15h */
 *j1b1 = (( regs.h.al &  16 ) >> 4) ^ 1;        /* Bit 4 de AL = J1B1 */
 *j1b2 = (( regs.h.al &  32 ) >> 5) ^ 1;        /* Bit 5 de AL = J1B2 */
 *j2b1 = (( regs.h.al &  64 ) >> 6) ^ 1;        /* Bit 6 de AL = J2B1 */
 *j2b2 = (( regs.h.al & 128 ) >> 7) ^ 1;        /* Bit 7 de AL = J2B2 */
}

/***********************************************************************
*  Fonction         : G E T J O Y P O S                                *
**--------------------------------------------------------------------**
*  Fonction          : Retourne la position des deux Joysticks         *
*  ParamŠtre d'entr‚e: JS1PTR =  Structure pour le 1er Joystick        *
*                      JS2PTR = Structure pour le second Joystick      *
*  Valeur de retour  : aucune                                          *
***********************************************************************/

void GetJoyPos( JSPOS *Js1Ptr, JSPOS *Js2Ptr )
{
 union REGS regs;                               /* pour les registres */

 regs.h.ah = 0x84;                                    /* Fonction 84h */
 regs.x.dx = 1;                                  /* Sous-fonction 01h */
 int86( 0x15, &regs, &regs );                       /* Appel Int 15h  */
 Js1Ptr->x = regs.x.ax;                      /* Position X Joystick 1 */
 Js1Ptr->y = regs.x.bx;                      /* Position Y Joystick 1 */
 Js2Ptr->x = regs.x.cx;                      /* Position X Joystick 2 */
 Js2Ptr->y = regs.x.dx;                      /* Position Y Joystick 2 */
}

/**********************************************************************/
/**                           PROGRAMME PRINCIPAL                    **/
/**********************************************************************/

void main()
{
 JSPOS jsp[2];                          /*  Position Joystick actuelle*/
 int   maxx, maxy,                      /* Position Joystick maximale */
       minx, miny,                      /* Position Joystick minimale */
       x, y,                                /* Position ‚cran actuelle*/
       xold, yold;                        /* DerniŠre position d'‚cran*/
 BYTE  actstick,                               /* Joystick s‚lectionn‚*/
       j1but[2],                       /* Bouton 1 du Joystick 1 et 2 */
       j2but[2];                       /* Bouton 2 du Joystick 1 et 2 */
 float xfacteur, yfacteur;           /* facteurs de conversion X et Y */


 /*-- Lire d'abord la position maximale du Joystick ------------------*/

 ClrScr( 0x07 );
 printf( "Veuillez placer le joystick dans le coin sup‚rieur droit\n"
         "et appuyez sur l'un des deux boutons");

 do                     /* Attendre l'appui sur le bouton du Joystick */
  GetJoyBouton( &j1but[0], &j2but[0], &j1but[1], &j2but[1] );
 while ( ( j1but[0] | j2but[0] | j1but[1] | j2but[1] ) == 0 );

 actstick = ( j1but[0] | j2but[0] ) ? 0 : 1; /* S‚lectionner Joystick */

 GetJoyPos( &jsp[0], &jsp[1] );                   /* Lire la position */
 maxx = jsp[actstick].x;                          /* et ranger        */
 miny = jsp[actstick].y;

 do                            /* Attendre que le bouton soit relƒch‚ */
  GetJoyBouton( &j1but[0], &j2but[0], &j1but[1], &j2but[1] );
 while ( ( j1but[actstick] | j2but[actstick] ) != 0 );

  /*-- Lire maintenant la position minimale --------------------------*/

 printf( "\n\nPlacez le Joystick dans le coin inf‚rieur gauche\n"\
         "et appuyez sur l'un des deux boutons\n" );

 do                      /*  Attendre … nouveau l'appui sur un bouton */
  GetJoyBouton( &j1but[0], &j2but[0], &j1but[1], &j2but[1] );
 while ( ( j1but[actstick] | j2but[actstick] ) == 0 );

 GetJoyPos( &jsp[0], &jsp[1] );                   /* Lire la position */
 minx = jsp[actstick].x;                          /* et ranger        */
 maxy = jsp[actstick].y;

 xfacteur = 80.0 / ( maxx - minx + 1 );  /* Calculer les facteurs de  */
 yfacteur = 23.0 / ( maxy - miny + 1 );/* conversion pour axes X et Y */

              /*-- D‚terminer le Joystick et afficher sa position ----*/
             /*-- jusqu'… ce que les deux boutons soient appuy‚s  ----*/

 ClrScr( 0x07 );
 printfat( 43, 0, "JOYSTC - (c) 1991 MICHAEL TISCHER" );
 printfat( 0, 24 , "Appuyez sur les deux boutons " \
                   "pour quitter le programme" );

 xold = yold = 0;                   /* Pr‚d‚finir l'ancienne Position */
 do
  {
   GetJoyPos( &jsp[0], &jsp[1] );                 /* Lire la position */

   /*-- Calculer la nouvelle position X du Joystick ------------------*/

   x = (int) ( xfacteur * (float) ( jsp[actstick].x - minx + 1 ) );
   if ( x < 0 )
     x = 0;
   if ( x > 79 )
     x = 79;

   /*-- Calculer la nouvelle position Y du Joystick ------------------*/

   y = (int) ( yfacteur * (float) ( jsp[actstick].y - miny + 1 ) );
   if ( y < 0 )
     y = 0;
   if ( y > 22 )
     y = 22;

   /*-- Afficher la nouvelle position si celle-ci a ‚t‚ modifi‚e -----*/

   if ( x != xold  ||  y != yold )
    {
     printfat( (BYTE) xold, (BYTE) (yold+1), " " );
     printfat( (BYTE) x, (BYTE) (y+1), "X" );
     xold = x;
     yold = y;
    }

   printfat( 0, 0, "(%3d,%3d)", jsp[actstick].x, jsp[actstick].y );
   GetJoyBouton( &j1but[0], &j2but[0], &j1but[1], &j2but[1] );
  }
 while (!( j1but[actstick] == 1  && j2but[actstick] == 1 ));
 ClrScr( 0x07 );
 printf( "Fin de programme\n" );
}
