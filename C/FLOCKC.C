/**********************************************************************/
/*                          F L O C K C . C                           */
/*--------------------------------------------------------------------*/
/*    Fonction       : Montre comment fonctionne le verrouillage des  */
/*                    fichiers sous r‚seau avec le module NETFILEC    */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire : SMALL                                          */
/*--------------------------------------------------------------------*/
/*    Auteur         : Michael Tischer                                */
/*    D‚velopp‚ le   : 10.02.1992                                     */
/*    DerniŠre MAJ   : 13.02.1992                                     */
/**********************************************************************/

#include <conio.h>
#include <stdio.h>
#include "netfilec.c"        /* Inclut les routines de gestion r‚seau */

/*== Constantes ======================================================*/

#define NOMFICHIER "flockc.dat"             /* Nom du fichier de test */

/*== D‚finitions de types ============================================*/

typedef char Test[ 5 ];                   /* Donn‚es d'enregistrement */
typedef unsigned char BYTE;

/*== Routines d'‚cran pour Microsoft C ==============================*/

#ifndef __TURBOC__                                    /* Microsoft C? */

  #define clrscr() clearwindow( 1, 1, 80, 25 )

  /********************************************************************/
  /* Gotoxy        : Positionne le curseur                            */
  /* Entr‚e        : Coordonn‚es du curseur                           */
  /* Sortie        : n‚ant                                            */
  /********************************************************************/

  void gotoxy( int x, int y )
  {
   regs.h.ah = 0x02;       /* Num‚ro de la fonction de l'interruption */
   regs.h.bh = 0;                                     /* Page d'‚cran */
   regs.h.dh = y - 1;
   regs.h.dl = x - 1;
   int86( 0x10, &regs, &regs );                       /* Interruption */
  }
#endif

/**********************************************************************/
/* clearwindow   : Efface une partie de l'‚cran                       */
/* Entr‚es       : cf infra                                           */
/* Sortie        : n‚ant                                              */
/**********************************************************************/

void clearwindow( int x1, int y1, int x2, int y2 )
{
 regs.h.ah = 0x07;         /* Num‚ro de la fonction de l'interruption */
 regs.h.al = 0x00;
 regs.h.bh = 0x07;
 regs.h.ch = y1 - 1;
 regs.h.cl = x1 - 1;
 regs.h.dh = y2 - 1;
 regs.h.dl = x2 - 1;
 int86( 0x10, &regs, &regs );                          /* Interruption*/
 gotoxy( x1, y1 );                           /* Positionne le curseur */
}

/**********************************************************************/
/* FMode   : G‚nŠre le mode du fichier … partir du type d'accŠs et du */
/*           mode de partage                                          */
/* Entr‚es : cf infra                                                 */
/* Sortie  : Mode du fichier                                          */
/**********************************************************************/

int FMode( int Acces,                                 /* Type d'accŠs */
        int Prot )                /* Mode de partage ou de protection */
{
 static BYTE Acces_Type[ 3 ] = { FM_R, FM_W, FM_RW };
 static BYTE Prot_Type[ 5 ]  = { SM_COMP, SM_RW, SM_R,
                  SM_W, SM_NO };

 return Acces_Type[ Acces-1 ] | Prot_Type[ Prot-1 ];
}

/**********************************************************************/
/* FichierTest : Montre les conflits d'accŠs et le jeu des protections*/
/*               avec ou sans verrouillage                            */
/* Entr‚es     : cf infra                                             */
/* Sortie      : n‚ant                                                */
/**********************************************************************/

void FichierTest( int AccesA,             /* Type d'accŠs 1er fichier */
        int ProtA,        /* Mode de partage (protection) 1er fichier */
        int AccesB,                       /* Type d'accŠs 2me fichier */
        int ProtB )       /* Mode de partage (protection) 2me fichier */
{
 Test  TestAEcr = "AAAA\0";                          /* Enreg de test */
 Test  TestBEcr = "BBBB\0";

 Test  TestALec,                             /* Pour lire des donn‚es */
       TestBLec;

 NFILE FichierA;                /* Fichiers de test pour accŠs commun */
 NFILE FichierB;
 char  SDummy[ 50 ];                          /* Etat aprŠs ex‚cution */

 clearwindow( 1, 11, 80, 25 );
 printf( "Fichier A: Nom = %s Type d'accŠs = %2i Mode de partage    = %2i\n",
     NOMFICHIER, AccesA, ProtA );
 printf( "Fichier B: Nom = %s Type d'accŠs = %2i Mode de partage    = %2i\n\n",
     NOMFICHIER, AccesB, ProtB );

/*-- Ouvre les fichiers ----------------------------------------------*/

 printf( "Ouverture du fichier A:  " );
 NetReset( NOMFICHIER, FMode( AccesA, ProtA ),
       sizeof( Test ), &FichierA );
 if ( NetError == NE_FileNotFound )
  NetRewrite( NOMFICHIER, FMode( AccesA, ProtA ),
          sizeof( Test ), &FichierA );
 NetErrorMsg( NetError, SDummy );
 printf( "Etat %2u = %s\n", NetError, SDummy );

 printf( "Ouverture du fichier B:  " );
 NetReset( NOMFICHIER, FMode( AccesB, ProtB ),
       sizeof( Test ), &FichierB );
 NetErrorMsg( NetError, SDummy );
 printf( "Etat %2u = %s\n\n", NetError, SDummy );

/*-- Ecrit dans les fichiers -----------------------------------------*/

 printf( "Ecriture dans fichier A:" );
 if ( Is_NetWriteOk( &FichierA ) )              /* Ecriture permise ? */
 {
  NetWrite( &FichierA, TestAEcr );
  printf( " Donn‚es '%s' enregistr‚es \n", TestAEcr );
 }
 else
  printf( " Fichier interdit … l'‚criture \n" );

 printf( "Ecriture dans fichier B:" );
 if ( Is_NetWriteOk( &FichierB ) )              /* Ecriture permise ? */
 {
  NetWrite( &FichierB, TestBEcr );
  printf( " Donn‚es '%s' enregistr‚es\n\n", TestBEcr );
 }
 else
  printf( " Fichier interdit … l'‚criture \n\n" );

/*-- Repositionne au d‚but les deux pointeurs des fichiers -----------*/

 if ( Is_NetOpen( &FichierA ) )                    /* Fichier ouvert? */
  NetSeek( &FichierA, 0L );
 if ( Is_NetOpen( &FichierB ) )                    /* Fichier ouvert? */
  NetSeek( &FichierB, 0L );

/*-- Lit les fichiers   ----------------------------------------------*/

 TestALec[0] = TestBLec[0] = '\0';
 printf( "Lecture dans fichier A:" );
 if ( Is_NetReadOk( &FichierA ) )                 /* Lecture permise? */
 {
  NetRead( &FichierA, TestALec );
  printf( " Enregistrement '%s' lu\n", TestALec );
 }
 else
  printf( " Fichier interdit … la lecture \n" );

 printf( "Lecture dans fichier B:" );
 if ( Is_NetReadOk( &FichierB ) )                 /* Lecture permise? */
 {
  NetRead( &FichierB, TestBLec );
  printf( " Enregistrement '%s' lu\n\n", TestBLec );
 }
 else
  printf( " Fichier interdit … la lecture \n\n" );

 /*-- Ferme les fichiers ---------------------------------------------*/

 NetClose( &FichierA );
 NetClose( &FichierB );
}

/**********************************************************************/
/*                         PROGRAMME PRINCIPAL                        */
/**********************************************************************/

void main( void )
{
 int AccesA;                            /* Types d'accŠs des fichiers */
 int AccesB;
 int ProtA;                          /* Modes de partage (protection) */
 int ProtB;

 clrscr();
 gotoxy( 1, 1 );
 printf( "FLOCKC D‚mo de verrouillage de fichiers sous DOS   " \
     "(c) 1992 by Michael Tischer\n" );
 printf( "=====================================================" \
     "===========================\n\n" );

 if ( ShareInst() )                                /* SHARE install‚? */
 {
/*-- S‚lectionne le mode    ------------------------------------------*/

  printf( "Types d'accŠs possibles          Modes de partage possibles\n" );
  printf( " 1: Lecture seule             " );
  printf( " 1: Mode de compatibilit‚ (pas de protection)\n");
  printf( " 2: Ecriture seule            " );
  printf( " 2: Tout accŠs ‚tranger interdit \n" );
  printf( " 3: Lecture et ‚criture       " );
  printf( " 3: Lecture seule\n" );
  printf( "                              " );
  printf( " 4: Ecriture seule\n" );
  printf( "                              " );
  printf( " 5: Tout est permis (record lock)\n" );

  printf( "\nType d'accŠs pour le fichier de test A: " );
  scanf( "%i", &AccesA );
  printf( "Mode de partage pour le fichier de test A: " );
  scanf( "%i", &ProtA );
  printf( "Type d'accŠs pour le fichier de test B: " );
  scanf( "%i", &AccesB );
  printf( "Mode de partage pour le fichier de test B: " );
  scanf( "%i", &ProtB );

  FichierTest( AccesA, ProtA, AccesB, ProtB );
 }
 else
  printf( "\nTest impossible, SHARE doit ˆtre charg‚ \n" );
}
