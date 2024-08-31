/**********************************************************************/
/*                            C L E T E N D C                         */
/**------------------------------------------------------------------**/
/*    Montre comment lire les touches additionnelles d'un clavier     */
/*    ‚tendu                                                          */
/**------------------------------------------------------------------**/
/*    Auteur          : MICHAEL TISCHER                               */
/*    D‚velopp‚ le    : 01.01.1992                                    */
/*    DerniŠre MAJ    : 01.01.1992                                    */
/**********************************************************************/

/*== Fichiers d'inclusion      =======================================*/

#include <stdio.h>
#include <dos.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;               /* Bricolage d'un type BYTE */
typedef unsigned int WORD;

/*== Constantes ======================================================*/

#define TRUE  ( 0 == 0 ) /* Constantes pour faciliter la compr‚hension*/
#define FALSE ( 0 == 1 )

/*== Routines d'‚cran pour Microsoft C ==============================*/

#ifndef __TURBOC__                                   /* Microsoft C? */

  /********************************************************************/
  /* Gotoxy        : Positionne le curseur                            */
  /* Entr‚e        : Coordonn‚es du curseur                           */
  /* Sortie        : n‚ant                                            */
  /********************************************************************/

  void gotoxy( int x, int y )
  {
   union REGS Register;                     /* Pour les interruptions */
   regs.h.ah = 0x02;                        /* Num‚ro de la fonction  */
   regs.h.bh = 0;                                          /* Couleur */
   regs.h.dh = y - 1;
   regs.h.dl = x - 1;
   int86( 0x10, &regs, &regs );           /* D‚clenche l'interruption */
  }

  /********************************************************************/
  /* clrscr       : Efface l'‚cran                                    */
  /* Entr‚e       : n‚ant                                             */
  /* Sortie       : n‚ant                                             */
  /********************************************************************/

  void clrscr( void )
  {
   union REGS regs;                            /* Pour l'interruption */

   regs.h.ah = 0x07;                         /* Num‚ro de la fonction */
   regs.h.al = 0x00;
   regs.h.ch = 0;
   regs.h.cl = 0;
   regs.h.dh = 24;
   regs.h.dl = 79;
   int86( 0x10, &regs, &regs );           /* D‚clenche l'interruption */
   gotoxy( 1, 1 );                                /* Place le curseur */
  }

#endif

/**********************************************************************/
/* HexByte : Convertit un octet en nombre hexad‚cimal                 */
/* Entr‚e  : VALEUR = octet … convertir                               */
/* Sortie  : chaŒne hexad‚cimale … deux chiffres                      */
/**********************************************************************/

char *HexByte( BYTE wert )
{
 char HexDigits[16] = "0123456789ABCDEF";
 static char dummy[3] = "00";

 dummy[0] = HexDigits[ wert >> 4 ];            /* Transforme les deux */
 dummy[1] = HexDigits[ wert & 0x0F ];              /* quartets en Hex */
 return dummy;
}

/**********************************************************************/
/* TestCE : Teste si les fonctions ‚tendues du BIOS pour lire         */
/*          un clavier ‚tendu sont disponibles                        */
/* Entr‚e : n‚ant                                                     */
/* Sortie : TRUE, si les fonctions sont disponibles , sinon FALSE     */
/**********************************************************************/

int TestCE( void )
{
 union REGS regs;                              /* Pour l'interruption */

 regs.x.ax = 0x1200;   /* Fonction d'‚tat ‚tendue pour clavier ‚tendu */
 int86( 0x16, &regs, &regs );
 return ( regs.x.ax != 0x1200 );      /* AX=0x1200 : Fonction absente */
}

/**********************************************************************/
/* GetCEKey : Lit une touche avec la fonction ‚tendue 0x10            */
/* Entr‚e   : n‚ant                                                   */
/* Sortie   : code de la touche frapp‚e                               */
/**********************************************************************/

WORD GetCEKey( void )
{
 union REGS regs;                              /* pour l'interruption */

 regs.h.ah = 0x10; /* Fonction de lecture ‚tendue pour clavier ‚tendu */
 int86( 0x16, &regs, &regs );
 return regs.x.ax;                    /* renvoie le code de la touche */
}

/**********************************************************************/
/*                     PROGRAMME PRINCIPAL                            */
/**********************************************************************/

void main( void )
{
 WORD touche;

 clrscr();
 printf( "CLETENDC  -  (c) 1992 by Michael Tischer\n\n" );
 if ( TestCE() )
  {
   printf("Les extensions du BIOS pour clavier ‚tendu ont ‚t‚ d‚cel‚es"\
	  "\n\nActionnez les touches ou les combinaisons de touches dont"
	  "\nvous voulez connaŒtre les codes."
	  "\n\nPour sortir du programme, tapez <Esc>\n\n");


   do                                             /* Boucle de saisie */
    {
     touche = GetCEKey();                           /* Lit une touche */
     printf( "Scan : %s ", HexByte((BYTE) (touche >> 8)) );
     printf( "ASCII: %s", HexByte((BYTE) (touche & 255)) );
     if ( ((touche & 255) == 0xe0) && ((touche & 65280 ) != 0 ) )
      printf( " <---- Touche ‚tendu" );
     printf( "\n" );
    }
   while ( touche != 0x011b );               /* R‚pŠte jusqu'… ESCAPE */
   printf( "\n\n" );
  }
 else
  printf( "Il n'y a pas d'exentsion du BIOS pour clavier ‚tendu !");
}
