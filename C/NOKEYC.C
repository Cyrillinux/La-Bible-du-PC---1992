/**********************************************************************/
/*                             N O K E Y C                            */
/*--------------------------------------------------------------------*/
/*    Montre comment effacer le buffer du clavier pour prot‚ger       */
/*    l'utilisateur contre des saisies r‚siduelles lorsqu'il          */
/*    doit r‚pondre … des questions importantes                       */
/*     (par ex "Voulez-vous supprimer tel fichier ?")                 */
/*--------------------------------------------------------------------*/
/*    Auteur                : MICHAEL TISCHER                         */
/*    D‚velopp‚ le          : 01.01.1992                              */
/*    DerniŠre modification : 01.01.1992                              */
/**********************************************************************/

#include <stdio.h>
#include <dos.h>
#include <bios.h>

/*== Macros ==========================================================*/

#ifndef MK_FP          /* D‚finit la macro MK_FP si elle n'existe pas */
  #define MK_FP(seg,ofs) \
    ((void far *) (((unsigned long)(seg) << 16) | (unsigned)(ofs)))
#endif

#ifdef __TURBOC__                         /* D‚finitions pour TURBO C */

   #define GetKbKey()        ( bioskey( 0 ) )
   #define GetKbReady()      ( bioskey( 1 ) != 0 )
   #define GetBiosTime(x)    ( x = biostime( 0, NULL ) )
   #define CLI()             ( disable() )
   #define STI()             ( enable() )

#else                 /* D‚finitions pour le compilateur  Microsoft C */

   #define GetKbKey()        ( _bios_keybrd( _KEYBRD_READ ) )
   #define GetKbReady()      ( _bios_keybrd( _KEYBRD_READY ) != 0 )
   #define GetBiosTime(x)    ( _bios_timeofday( _TIME_GETCLOCK, &x) )
   #define CLI()             ( _disable() )
   #define STI()             ( _enable() )

#endif

/*== Routines d'affichage pour Microsoft C ===========================*/

#ifndef __TURBOC__                                    /* Microsoft C? */

  /********************************************************************/
  /* Gotoxy        : Positionne le curseur                            */
  /* Entr‚es       : Coordonn‚es du curseur                           */
  /* Sortie        : n‚ant                                            */
  /********************************************************************/

  void gotoxy( int x, int y )
  {
   union REGS regs;                  /* Registres pour l'interruption */

   regs.h.ah = 0x02;                         /* Num‚ro de la fonction */
   regs.h.bh = 0;                                          /* Couleur */
   regs.h.dh = y - 1;
   regs.h.dl = x - 1;
   int86( 0x10, &regs, &regs );                       /* Interruption */
  }

  /********************************************************************/
  /* clrscr        : Efface l'‚cran                                   */
  /* Entr‚e        : n‚ant                                            */
  /* Sortie        : n‚ant                                            */
  /********************************************************************/

  void clrscr( void )
  {
   union REGS regs;                  /* Registres pour l'interruption */
   regs.h.ah = 0x07;                         /* Num‚ro de la fonction */
   regs.h.al = 0x00;
   regs.h.ch = 0;
   regs.h.cl = 0;
   regs.h.dh = 24;
   regs.h.dl = 79;
   int86( 0x10, &regs, &regs );                       /* Interruption */
   gotoxy( 1, 1 );                                /* Place le curseur */
  }

#endif

/**********************************************************************/
/*  Delay :  Fige l'ex‚cution du programme pendant un certain temps   */
/*           ind‚pendamment de la cadence du systŠme                  */
/*  Entr‚e  : PAUSE = temps d'arrˆt en tops d'horloge                 */
/*  Sortie  : n‚ant                                                   */
/*  Info    : un top = 1/18,2 Secondes                                */
/**********************************************************************/

void delay( unsigned int pause )
{
 long temps,                                        /* temps courant */
      tempsfinal;                                     /* temps final */

 if ( pause )                                   /* Pause non nulle ? */
  {                                                          /* Non  */
   GetBiosTime( tempsfinal );
   tempsfinal += (long) pause;             /* Calcule le temps final */

   do                                /* Boucle, lit le temps courant */
    GetBiosTime( temps );
   while ( temps <= tempsfinal );           /* temps final atteint ? */
  }                                                  /* Oui, termin‚ */
}

/**********************************************************************/
/* ClearKbBuffer : Efface le contenu du buffer du clavier             */
/* Entr‚e  : n‚ant                                                    */
/* Sortie  : n‚ant                                                    */
/**********************************************************************/

void ClearKbBuffer( void )
{
 CLI();                       /* Inhibe les interruptions mat‚rielles */
 *(int far *) MK_FP(0x40,0x1a) =  /* Plus de caractŠre dans le buffer */
 *(int far *) MK_FP(0x40,0x1C);
 STI( );                    /* R‚tablit les interruptions mat‚rielles */
}

/**********************************************************************/
/*                     Programme principal                            */
/**********************************************************************/

void main( void )
{
 int           i,                            /* Compteur d'it‚rations */
	       ccount;         /* Nombre de caractŠres dans le buffer */
 unsigned char ch;     /* M‚morise les touches */

 clrscr();
 printf( "NOKEYC  -  (c) 1992 by Michael Tischer\n\n" );
 printf( "A 0 les caractŠres du buffer vont ˆtre effac‚s \n\n" );

 for ( i = 10; i; --i )   /* Laisse le temps de saisir des caractŠres */
  {
   printf( "%5d", i );
   delay( 13 );                                /* Pause de 3/4 de sec */
  }

ClearKbBuffer();                         /* Vide le buffer du clavier */

 /*-- Efface les caractŠres qui restent dans le buffer du clavier ----*/

 ccount = 0;                  /* Initialise le compteur de caractŠres */
 printf( "\n\nCaractŠres dans le buffer :\n" );

 while GetKbReady()       /* Reste-t-il un caractŠre dans le buffer ? */
  {                             /* Oui, lit le caractŠre et l'affiche */
   ch = GetKbKey();
   printf( "   %3d   ", (int) ch );        /* Affiche d'abord le code */
   if ( (int) ch > 32 )                        /* CaractŠre sp‚cial ? */
    printf ( "(%c)", ch );               /* Non, affiche le caractŠre */
   printf("\n");
   ++ccount;
  }

 if ( ccount == 0 )                             /* Pas de caractŠre ? */
  printf( "(Aucun)\n" );                                       /* Non */
 printf( "\n" );
}
