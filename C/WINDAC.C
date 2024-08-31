/***********************************************************************
*                          W I N D A C . C                             *
**--------------------------------------------------------------------**
*    Fonction       : Confirme si Windows est actif et dans            *
*                     quel mode.                                       *
**--------------------------------------------------------------------**
*    Auteur         : Michael Tischer                                  *
*    D‚velopp‚ le   : 22.08.1991                                       *
*    DerniŠre modif.: 22.03.1992                                       *
**--------------------------------------------------------------------**
*    ModŠle de m‚moire : SMALL                                         *
***********************************************************************/

/*== Ins‚rer les fichiers Include ====================================*/

#include <dos.h>
#include <stdio.h>

/*== Constantes ======================================================*/

#define MULTIPLEX    0x2F                      /* Nø d'int. Multiplex */

#define NO_WIN       0x00                        /* Windows non actif */
#define W_386_X      0x01               /* Windows /386 V2.x en cours */
#define W_REAL       0x81           /* Windows fonctionne en mode R‚el*/
#define W_STANDARD   0x82      /* Windows fonctionne en mode Standard */
#define W_ENHANCED   0x83        /* Windows fonctionne en mode Etendu */

/***********************************************************************
* windows : Confirme si Windows est actif                              *
* Entr‚e : HVERSION  = Ptr sur INT devant contenir le num‚ro de        *
*                      version principale                              *
*           NVERSION = Ptr sur INT devant contenir le num‚ro de        *
*                      version secondaire                              *
* Sortie : Statut Windows, une constante parmi NO_WIN, W_386_X,        *
*           W_STANDARD, W_STANDARD ou W_ENHANCED                       *
* Infos    : Le num‚ro de version peut ˆtre obtenu qu'en mode Etendu   *
*           de Windows 3                                               *
***********************************************************************/

int windows( int *HVersion, int *NVersion )
{
 union  REGS  regs;          /* Registres pour l'appel d'interruption */
 struct SREGS sregs;           /* Segment pour l'appel d'interruption */

 *HVersion = 0;                    /* Initialise le num‚ro de version */
 *NVersion = 0;

           /*-- Identifie Windows x.y en mode Etendu -----------------*/

 regs.x.ax = 0x1600;                /* Test d'installation de Windows */
 segread( &sregs );                  /* Lire les registres de segment */
 int86x( MULTIPLEX, &regs, &regs, &sregs );

 switch ( regs.h.al )
 {
  case 0x01:
  case 0xFF:  *HVersion = 2;                          /* Hauptversion */
              *NVersion = 0;           /* Version secondaire inconnue */
              return W_386_X;             /* Windows /386 Version 2.x */

  case 0x00:
  case 0x80:  regs.x.ax = 0x4680;           /* Modes R‚el et Standard */
              int86x( MULTIPLEX, &regs, &regs, &sregs );
              if( regs.h.al == 0x80 )
                return NO_WIN;           /* Windows ne fonctionne pas */
              else
              {
               /*-- Windows en mode R‚el ou Standard -----------------*/

                regs.x.ax = 0x1605;        /* Simuler l'initialiation */
                regs.x.bx = regs.x.si = regs.x.cx =
                            sregs.es = sregs.ds = 0x0000;
                regs.x.dx = 0x0001;
                int86x( MULTIPLEX, &regs, &regs, &sregs );
                if( regs.x.cx == 0x0000 )
                {
                 /*-- Windows en mode R‚el ---------------------------*/

                  regs.x.ax = 0x1606;
                  int86x( MULTIPLEX, &regs, &regs, &sregs );
                  return W_REAL;
                }
                else
                  return W_STANDARD;
              }

 /*-- Windows en mode Etendu, ax contient le num‚ro de version -------*/

  default:  *HVersion = regs.h.al;  /* Afficher la version de Windows */
            *NVersion = regs.h.ah;
            return W_ENHANCED;              /* Windows en mode Etendu */
 }
}

/***********************************************************************
*                  P R O G R A M M E    P R I N C I P A L              *
***********************************************************************/

int main( void )
{
 int WindowsActif,                                 /* Mode de Windows */
     HVer,                           /* Version principale de Windows */
     NVer;                           /* Version secondaire de Windows */

 printf("ÛÛÛÛÛÛÛ WINDAC  -  (c) 1991, 92 by Michael TISCHER ÛÛÛÛ\n\n" );
 WindowsActif = windows( &HVer, &NVer );
 switch ( WindowsActif )
 {
  case NO_WIN:     printf( "Windows non actif\n" );
                   break;
  case W_REAL:     printf( "Windows actif en mode R‚el\n" );
                   break;
  case W_STANDARD: printf( "Windows actif en mode Standard\n" );
                   break;
  case W_386_X:    printf( "Windows/386 V 2.x actif" );
           break;
  case W_ENHANCED: printf( "Windows V %d.%d actif en %s\n",
                           HVer, NVer, "mode Etendu" );
                   break;
 }
 return( WindowsActif );
}
