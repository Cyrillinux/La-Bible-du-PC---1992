/***********************************************************************
*                           V O N O F F C . C                          *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment ‚teindre et rallumer un ‚cran     *
*                     EGA ou VGA                                       *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     : 26.08.1990                                       *
*  DerniŠre MAJ     : 14.02.1992                                       *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS vonoffc.c                                 *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation      : dans l'environnement de d‚veloppement int‚gr‚    *
***********************************************************************/

#include <dos.h>                              /* Fichiers d'inclusion */
#include <conio.h>
#include <stdio.h>

#ifdef __TURBOC__                        /* Compilation par  Turbo C? */
  #define CLI()         disable()
  #define STI()         enable()
  #define outpw( p, w ) outport( p, w )
  #ifndef inp
    #define outp( p, b )  outportb( p, b )
    #define inp( p )      inportb( p )
  #endif
#else                                  /* Non , par QuickC 2.0 ou MSC */
  #include <conio.h>
  #define MK_FP(seg,ofs) ((void far *)\
                         (((unsigned long)(seg) << 16) | (ofs)))
  #define CLI()          _disable()
  #define STI()          _enable()
#endif

/*-- Constantes ------------------------------------------------------*/

#define EV_STATC 0x3DA             /* Registre d'‚tat couleur EGA/VGA */
#define EV_STATM 0x3BA                /* Registre d'‚tat mono EGA/VGA */
#define EV_ATTR  0x3C0               /* Contr“leur d'attribut EGA/VGA */

/***********************************************************************
*  ScrOff : D‚sactive un ‚cran EGA ou VGA                              *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************/

void ScrOff( void )
{
 CLI();                                   /* Inhibe les interruptions */
 inp( EV_STATC );                 /* Reset du registre d'‚tat couleur */
 inp( EV_STATM );                    /* Reset du registre d'‚tat Mono */
(void)outp( EV_ATTR, 0x00 );       /* Efface le bit 5 ce qui supprime */
                             /* la liaison avec le contr“leur d'‚cran */
 STI();                                 /* R‚tablit les interruptions */
}

/***********************************************************************
*  ScrOn : R‚active un ‚cran EGA ou VGA                                *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************/

void ScrOn( void )
{
 CLI();                                   /* Inhibe les interruptions */
 inp( EV_STATC );                 /* Reset du registre d'‚tat couleur */
 inp( EV_STATM );                    /* Reset du registre d'‚tat Mono */
(void)outp( EV_ATTR, 0x20 );              /* Active le bit 5 , ce qui */
                    /* r‚tablit la liaison avec le contr“leur d'‚cran */
 STI();                                 /* R‚tablit les interruptions */
}

/***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : TRUE, si carte EGA ou VGA, sinon FALSE                    *
***********************************************************************/

int IsEgaVga( void )
{
 union REGS Regs;              /* Registres pour g‚rer l'interruption */

 Regs.x.ax = 0x1a00;            /* La fonction 1Ah n'existe qu'en VGA */
 int86( 0x10, &Regs, &Regs );
 if ( Regs.h.al == 0x1a )                    /* Est-elle disponible ? */
  return 1;
 else
  {
   Regs.h.ah = 0x12;                          /* Appelle l'option 10h */
   Regs.h.bl = 0x10;                            /* de la fonction 12h */
   int86(0x10, &Regs, &Regs);       /* D‚clenche l'interruption vid‚o */
   return ( Regs.h.bl != 0x10 );
  }
}

/***********************************************************************
*  Delay : Introduit une temporisation … l'aide du timer du BIOS       *
**--------------------------------------------------------------------**
*  Entr‚e  : Dur‚e de la temporisation en s                            *
*  Sortie  : n‚ant                                                     *
***********************************************************************/

void Delay( int pauslen )
{
 unsigned int temps_hi,                         /* Compteurs de temps */
              temps_lo,
              ticks;
 union REGS   inregs,                      /* Registres du processeur */
              outregs;

 ticks = pauslen * 182 / 10;
 inregs.h.ah = 0;                      /* Fonction 00h = Lit le timer */
 int86( 0x1a, &inregs, &outregs );
 temps_hi = outregs.x.cx;                        /* M‚morise le temps */
 temps_lo = outregs.x.dx;

 while ( ticks )                 /* R‚pŠte l'op‚ration jusqu'… ce que */
  {                                   /* le compteur de tops soit … 0 */
   int86( 0x1a, &inregs, &outregs );                  /* Lit le temps */

             /*-- Nouveau top ? --------------------------------------*/

   if ( temps_hi != outregs.x.cx  ||  temps_lo != outregs.x.dx )
    {                                                          /* Oui */
     temps_hi = outregs.x.cx;       /* Note les valeurs des compteurs */
     temps_lo = outregs.x.dx;
     --ticks;                /* D‚cr‚mente le nombre de tops restants */
    }
  }
}

/**********************************************************************/
/*--                   PROGRAMME PRINCIPAL                          --*/
/**********************************************************************/

void main( void )
{
 int i;                                      /* Compteur d'it‚rations */

 for ( i=0; i<25; ++i )                             /* Eteint l'‚cran */
  printf( "\n" );

 printf( "VONOFFC  -  (c) 1990, 92 by MICHAEL TISCHER\n\n" );
 if ( IsEgaVga() )                                    /* EGA ou VGA ? */
  {                                                   /* Oui, on y va */
   printf( "Attention l'‚cran va s'‚teindre " \
       "dans 5 secondes.\nActionnez ensuite une touche quelconque" \
       " pour le rallumer..." );
   Delay( 5 );                               /* On attend 5 secondes  */
   while ( kbhit() )       /* Retire les touches du buffer du clavier */
     getch();
   ScrOff();                                        /* Eteint l'‚cran */
   getch();                            /* Attend une frappe de touche */
   ScrOn();                                        /* Rallume l'‚cran */
   printf( "\n\n\nC'est tout ....\n" );
  }
 else                                  /* Non pas de carte EGA ou VGA */
  printf( "Attention ! Ce programme exige " \
      "une carte EGA ou VGA.\n" );
}
