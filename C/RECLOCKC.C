/**********************************************************************/
/*                         R E C L O C K C . C                        */
/*--------------------------------------------------------------------*/
/*    Fonction       : Montre comment fonctionne le verrouillage des  */
/*                     enregistrements avec les fonctions du module   */
/*                     NETFILEC                                       */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire : SMALL                                          */
/*--------------------------------------------------------------------*/
/*    Auteur         : Michael Tischer                                */
/*    D‚velopp‚ le   : 10.02.1992                                     */
/*    DerniŠre MAJ   : 13.02.1991                                     */
/**********************************************************************/

#include "netfilec.c"        /* IntŠgre les routines orient‚es r‚seau */
#include <stdio.h>
#include <conio.h>

/*== Constantes ======================================================*/

#define NOMFICHIER "rec.dat"                /* Nom du fichier de test */
#define ENREGIS    10                      /* Nombre d'enrg . de test */

/*== D‚finitions de types ============================================*/

typedef char Test[ 160 ];              /*Type de donn‚es pour le test */
typedef char TestString[ 161 ];    /* Type des donn‚es pour affichage */

#ifndef __TURBOC__                                    /* Microsoft C? */

  #define clrscr() clearwindow( 1, 1, 80, 25 )

  /********************************************************************/
  /* Gotoxy       : Positionne le curseur                             */
  /* Entr‚es      : Coordonn‚es du curseur                            */
  /* Sortie       : n‚ant                                             */
  /********************************************************************/

  void gotoxy( int x, int y )

  {
   regs.h.ah = 0x02;          /* Num‚ro de la fonction d'interruption */
   regs.h.bh = 0;                                          /* Couleur */
   regs.h.dh = y - 1;
   regs.h.dl = x - 1;
   int86( 0x10, &regs, &regs );                     /* Interruption   */
  }
#endif

/**********************************************************************/
/* clearwindow  : Efface une partie de l'‚cran                        */
/* Entr‚es      : cf infra                                            */
/* Sortie       : n‚ant                                               */
/**********************************************************************/

void clearwindow( int x1, int y1, int x2, int y2 )
{
 regs.h.ah = 0x07;             /* Num‚ro de la fonction d'interruption*/
 regs.h.al = 0x00;
 regs.h.bh = 0x07;
 regs.h.ch = y1 - 1;
 regs.h.cl = x1 - 1;
 regs.h.dh = y2 - 1;
 regs.h.dl = x2 - 1;
 int86( 0x10, &regs, &regs );                          /* Interruption*/
 gotoxy( x1, y1 );                               /* Refixe le curseur */
}

/**********************************************************************/
/* OuvreFichier : Ouvre un fichier pr‚existant. Sinon cr‚er un nouveau*/
/*                fichier de test et le remplit avec les donn‚es      */
/*                pr‚vues … cet effet                                 */
/* Entr‚es      : cf infra                                            */
/* Sortie       : Fichier                                             */
/**********************************************************************/

int OuvreFichier( NFILE *Fichier )                 /* Fichier r‚seau  */
{
 int  i;                                                   /* Compteur*/
 Test TestEnreg;      /* Indispensable pour cr‚er les donn‚es de test */

 /*-- Ouvre un fichier pour entr‚e/sortie en mode Deny-None ----------*/

 NetReset( NOMFICHIER, FM_RW | SM_NO, sizeof( Test ), Fichier );
 if ( NetError == NE_FileNotFound )              /* Fichier inconnu ? */
 {
                  /*-- Cr‚e le fichier et le remplit -----------------*/

  NetRewrite( NOMFICHIER, FM_RW | SM_NO, sizeof( Test ), Fichier );
  if ( NetError == NE_OK )                     /* Cr‚ation correcte ? */
  {
   if ( NetLock( Fichier, 0L, (long) ENREGIS ))/* Verrouille tous les */
                                                    /* enregistrement */
   {
    NetSeek( Fichier, 0L );         /* Pointe sur le d‚but du fichier */
    for ( i = 0; i < ENREGIS; i++ )
    {
     memset( TestEnreg, 'A' + i, 160 );
     NetWrite( Fichier, TestEnreg );     /* Ecrit les donn‚es de test */
    }
    return NetUnLock( Fichier, 0L, (long) ENREGIS );
   }
   else
    return FALSE;                           /* Erreur de verrouillage */
  }
  else
   return FALSE;                                /* Erreur de cr‚ation */
 }
 else
  return ( NetError == 0 );                /* Ouverture sans erreur ? */
}

/**********************************************************************/
/* ResoEdit   : D‚monstration des fonctions de r‚seau                 */
/* Entr‚es    : voir plus loin                                        */
/* Sortie     : Fichier                                               */
/**********************************************************************/

void ResoEdit( NFILE *TestFile )                    /* Fichier r‚seau */
{
 unsigned long ActRecord;                  /* Num‚ro d'enreg. courant */
 TestString    ActEnreg;                         /* Donn‚es courantes */
 int           Action;                            /* Action souhait‚e */
 int           Status;                         /* Enreg. verrouill‚ ? */
 char          Caractere[ 10 ];
 char          SDummy[ 50 ];                        /* Etat du r‚seau */
 int           Verrouille[ ENREGIS ];
 int           i;                                         /* Compteur */

/*-- AFfiche le menu -------------------------------------------------*/

 printf( "Fonctions propos‚es\n" );
 printf( "  1: Positionne le pointeur\n" );
 printf( "  2: Verrouille un enregistrement\n" );
 printf( "  3: Lit un enregistrement\n" );
 printf( "  4: Modifie les donn‚es \n" );
 printf( "  5: Ecrit un enregistrement\n" );
 printf( "  6: D‚verrouille un enregistrement\n" );
 printf( "  7: Fin\n" );

 /*-- Insitialise et affiche l'‚tat des enregistrements --------------*/

 gotoxy( 58, 4 );
 printf( "Etat des enreg:" );
 for ( i = 0; i < ENREGIS; ++i )
  {
   Verrouille[i] = FALSE;
   gotoxy( 64, i+5 );
   printf( "%2d   libre", i );
  }

 ActRecord = 0;                             /* Enregistrement courant */
 Status = FALSE;                                    /* Non verrouill‚ */
 memset( ActEnreg, 32, 160 );             /* G‚nŠre des donn‚es vides */

 do
 {
 /*-- Affiche les informations ---------------------------------------*/

  gotoxy( 1, 16 );                            /* Position du pointeur */
  printf( "Enregistrement courant: %4li\n",  ActRecord );
  printf( "Etat          :    %s\n",
       Verrouille[ActRecord] ? "verrouill‚" : "libre      " );
  NetErrorMsg( NetError, SDummy );
  printf( "Etat du r‚seau : %4i = %s", NetError, SDummy );
  gotoxy( 1, 21 );                             /* Affiche les donn‚es */
  printf( "Donn‚es courantes :\n" );
  ActEnreg[ 160 ] = 0;
  printf( "%s", ActEnreg );

  NetSeek( TestFile, ActRecord );           /* Positionne le pointeur */
  gotoxy( 1, 13 );
  printf( "S‚lection:                            " );
  gotoxy( 12, 13 );
  Action = 0;
  scanf( "%i", &Action );
  switch( Action )
  {
   case 1 : gotoxy( 1, 13 );
        printf( "Nouveau num‚ro: " );
            do
             {
              gotoxy( 22, 13 );
              printf( "                      " );
              gotoxy( 22, 13 );
              scanf( "%li", &ActRecord );
             }
            while (!( ActRecord >= 0  &&  ActRecord < ENREGIS ));
            break;

   case 2 : Status = NetLock( TestFile, ActRecord, 1L );
            if ( Status )
             {
              Verrouille[ ActRecord ] = TRUE;
              gotoxy( 64, (int) ActRecord +5 );
          printf( "%2d   verrouill‚", ActRecord );
             }
            break;

   case 3 : NetRead( TestFile, ActEnreg );         /* Lit les donn‚es */
            break;

   case 4 : gotoxy( 1, 13 );
        printf( "Nouveau caractŠre:" );
            scanf( "%s", Caractere );
            memset( ActEnreg, Caractere[ 0 ], 160 );
            break;

   case 5 : NetWrite( TestFile, ActEnreg ); /* Enregistre les donn‚es */
            break;

   case 6 : Status = NetUnLock( TestFile, ActRecord, 1L );
            if ( Status )
             {
              Verrouille[ ActRecord ] = FALSE;
              gotoxy( 64, (int) ActRecord+5 );
              printf( "%2d   libre      ", ActRecord);
             }
            break;
  }

 }
 while ( Action != 7 );
}

/**********************************************************************/
/*                           Programme principal                      */
/**********************************************************************/

void main( )

{
 NFILE Fichier;                                    /* Fichier de test */

 clrscr();
 printf( "RECLOCKC D‚mo du verrouillage d'enregistrements DOS" \
         " (c) 1992 by Michael Tischer\n" );
 printf( "====================================================" \
         "===========================\n\n" );

 if ( ShareInst() )                                /* Share install‚? */
 {
  if ( OuvreFichier( &Fichier ) )         /* Fichier ouvert ou cr‚‚ ? */
  {
   ResoEdit( &Fichier );                  /* C'est parti pour la d‚mo */
   NetClose( &Fichier );                          /* Ferme le fichier */
   clrscr( );
  }
  else
   printf( "\nErreur %i … l'ouverture du fichier" , NetError );
 }
 else
  printf( "\nTest impossible, SHARE doit ˆtre install‚" );
}
