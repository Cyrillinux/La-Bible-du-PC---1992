/***********************************************************************
*                              I S E V C . C                           *
**--------------------------------------------------------------------**
*  Fonction         : Teste la pr‚sence d'une carte EGA ou VGA   -     *
*                                                                      *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     :  6.08.1990                                       *
*  DerniŠre MAJ     : 14.02.1992                                       *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS isevc.c                                   *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation      : par l'EDI                                        *
**--------------------------------------------------------------------**
*  Appel            : isevc                                            *
***********************************************************************/

#include <dos.h>                                /* Fichiers d'en-tˆte */
#include <stdarg.h>
#include <stdio.h>

/*-- Constantes ------------------------------------------------------*/

#define EGA_MONO   0                         /* EGA avec moniteur MDA */
#define EGA_COLOR  1                         /* EGA avec moniteur EGA */
#define VGA_MONO   2       /* VGA avec moniteur monochrome analogique */
#define VGA_COLOR  3                         /* VGA avec moniteur VGA */
#define NINI       4                                 /* NI EGA NI VGA */

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char    BYTE;

/***********************************************************************
*  IsEgaVga : teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e   : n‚ant                                                    *
*  Sortie   : l'une des constantes EGA_MONO, EGA_COLOR etc.            *
***********************************************************************/

BYTE IsEgaVga( void )
{
  union REGS   Regs;                 /* Registres pour l'interruption */

  Regs.x.ax = 0x1a00;        /* La fonction 1Ah n'existe que pour VGA */
  int86( 0x10, &Regs, &Regs );
  if( Regs.h.al == 0x1a )        /* La fonction est-elle disponible ? */
    switch ( Regs.h.bl )                     /* Oui, exploite le code */
    {
      case 4  : return EGA_COLOR;
      case 5  : return EGA_MONO;
      case 7  : return VGA_MONO;
      case 8  : return VGA_COLOR;
      default : return NINI;
    }
  else                                  /* Non, serait-ce  une EGA  ? */
  {
    Regs.h.ah = 0x12;                         /* Appelle l'option 10h */
    Regs.h.bl = 0x10;                           /* de la fonction 12h */
    int86(0x10, &Regs, &Regs );                 /* Interruption vid‚o */
    if( Regs.h.bl != 0x10 )                                   /* EGA? */
      return Regs.h.bh == 0 ? EGA_COLOR : EGA_MONO;            /* oui */
    else                                                       /* Non */
      return NINI;
   }
}

/***********************************************************************
*                       PROGRAMME PRINCIPAL                            *
***********************************************************************/

void main( void )
{
  printf( "ISEVC  -  (c) 1990, 92 by MICHAEL TISCHER\n\n" );
  switch( IsEgaVga() )
  {
    case NINI      :
      printf( "La carte vid‚o active n'est ni une carte EGA"\
              " ni une carte VGA !");
      break;

    case EGA_MONO  :
      printf( "La carte active est une carte EGA branch‚e"\
              " sur un ‚cran MDA." );
      break;

    case EGA_COLOR :
      printf( "La carte active est une carte EGA branch‚e"\
              " sur un ‚cran EGA ou Multiscan." );
      break;

   case VGA_MONO  :
      printf( "La carte active est une carte VGA branch‚e sur"\
              " un ‚cran monochrome analogique.");
      break;

   case VGA_COLOR :
      printf( "La carte active est une carte VGA branch‚e sur"\
              " un ‚cran VGA ou Multiscan." );
  }
  printf( "\n\n" );
}

