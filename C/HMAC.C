/***********************************************************************
*                             H M A C . C                              *
**--------------------------------------------------------------------**
*  Sujet          : D‚monstration d'accŠs direct au HMA sans l'aide    *
*                   d'aucun pilote particulier.                        *
**--------------------------------------------------------------------**
*  Auteur         : MICHAEL TISCHER                                    *
*  D‚velopp‚ le   : 27.07.1990                                         *
*  DerniŠre m. … j: 29.07.1990                                         *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Cr‚ation       : CL /AS /Zp hmac.c hmaca                            *
*  Appel          : hmac                                               *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Cr‚ation       : avec un fichier de projet contenant les fichiers   *
*                     hmac.c                                           *
*                     hmaca.obj                                        *
***********************************************************************/

/*-- Int‚grer les fichiers include -----------------------------------*/

#include <dos.h>                         /* Pour appels interruptions */
#include <stdio.h>

#ifdef __TURBOC__
  #include <alloc.h>
#else
  #include <malloc.h>
#endif

/*-- Constantes ------------------------------------------------------*/


#define TRUE  ( 0 == 0 )
#define FALSE ( 0 == 1 )

/*-- Macros ----------------------------------------------------------*/

#ifndef MK_FP
  #define MK_FP(seg,ofs) \
         ((void far *) (((unsigned long)(seg) << 16) | (unsigned)(ofs)))
#endif

#define Hi(x) (*((BYTE *) &x+1))                  /* Hi Byte d'un int */
#define Lo(x) (*((BYTE *) &x))                    /* Lo Byte d'un int */

/*-- D‚clarations des types ------------------------------------------*/

typedef unsigned char BYTE;
typedef BYTE BOOL;
typedef unsigned WORD;

/*-- D‚clarations externes -------------------------------------------*/

extern BOOL HMAAvail( void );                          /* HMA dispo ? */
extern BOOL GateA20( BOOL libre );             /* lib‚rer/bloquer A20 */
extern BOOL IsA20On( void );                          /* A20 lib‚r‚ ? */

/***********************************************************************
* HMATest : D‚monstration de l'accŠs au HMA                            *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************/

void HMATest( void)

{
 BYTE far * hmap;                                 /* Pointeur sur HMA */
 WORD i,                                     /* Compteur d'it‚rations */
      err;                       /* Nombre d'erreurs en accŠs … l'HMA */

 if( IsA20On() )
   printf( "Le canal d'adresse A20 est d‚j… lib‚r‚!\n" );
 else
   if( GateA20( TRUE ) == FALSE  || IsA20On() == FALSE )
   {
     printf( "Attention! Le canal d'adresses A20 n'a pu ˆtre" \
             "lib‚r‚." );
     return;
   }
   else
     printf( "L'accŠs … l'HMA vient d'ˆtre lib‚r‚.\n" );

 hmap = MK_FP( 0xFFFF, 0x0010 );                  /* pointeur sur HMA */
 err  = 0;                                 /* aucune erreur jusqu'ici */
 for( i = 1; i < 65520; ++i, ++hmap )
 {                                 /* Teste chaque adresse s‚par‚ment */
   printf( "\rAdresse: %u", i );
   *hmap = i % 256;                          /* Ecrire dans l'adresse */
   if( *hmap != i % 256 )                             /* et la relire */
   {                                                       /* Erreur! */
     printf( " ERREUR!\n" );
     ++err;
   }
 }

 printf( "\n" );
 if ( err == 0 )                          /* Evaluer r‚sultat du test */
   printf( "HMA ok, aucune adresse incorrecte.\n" );
 else
   printf( "ATTENTIOn! %d adresses incorrectes d‚couvertes " \
           "dans le HMA!\n", err );
 GateA20( FALSE );                     /* D‚sactiver canal d'adresses */
}

/***********************************************************************
*                     P R O G R A M M E   P R I N C I P A L            *
***********************************************************************/

void main( void )
{
 int   i;                                    /* Compteur d'it‚rations */

 for( i = 1; i < 25; ++i )                         /* Effacer l'‚cran */
   printf ( "\n" );

 printf("HMAC  -  Programme d‚mo HMA par MICHAEL TISCHER\n\n" );
 if( HMAAvail() )
 {
   HMATest();                                             /* Test HMA */
   printf( "\n" );
 }
 else
   printf( "Aucun accŠs possible … l'HMA.\n" );
}
