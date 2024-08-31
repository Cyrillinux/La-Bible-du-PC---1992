/**********************************************************************/
/*                               R T C C                              */
/*--------------------------------------------------------------------*/
/*    Fonction       : fournit deux fonctions permettant d'‚crire des */
/*                     donn‚es ou d'en lire sur l'horloge en temps    */
/*                     r‚el                                           */
/*--------------------------------------------------------------------*/
/*    Auteur         : MICHAEL TISCHER                                */
/*    d‚velopp‚ le   : 15/08/1987                                     */
/*    derniŠre modif.: 17/02/1992                                     */
/*--------------------------------------------------------------------*/
/*    (MICROSOFT C)                                                   */
/*    Cr‚ation       : CL /AS RTCC.C                                  */
/*    Appel          : RTCC                                           */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    Cr‚ation       : Avec instruction RUN dans ligne d'instruction  */
/*                     (sans fichier Project)                         */
/**********************************************************************/

/*== Int‚grer fichiers Include =======================================*/

#include <dos.h>                           /* Int‚grer fichier header */
#include <stdio.h>
#include <conio.h>

/*== Typedefs ========================================================*/

typedef unsigned char byte;      /* Voil… comment se bricoler un BYTE */

/*== Constantes ======================================================*/

#define RTCAdrPort  0x70              /* Registre d'adresse de la RTC */
#define RTCDtaPort  0x71             /* Registre de donn‚es de la RTC */

#define SECONDES      0        /* Adresses de cellules de m‚moire RTC */
#define MINUTES       2
#define HEURES        4
#define JOURSEMAINE   6
#define JOUR          7
#define MOIS          8
#define ANNEE         9
#define ETATA        10
#define ETATB        11
#define ETATC        12
#define ETATD        13
#define DIAGNOSTIC   14
#define SIECLE       50

/**********************************************************************/
/* RTCREAD: lire le contenu d'une des cellules de m‚moire de la RTC   */
/* Entr‚e  : adresse de la cellule de m‚moire dans la RTC             */
/* Sortie  : le contenu de cette cellule de m‚moire                   */
/**********************************************************************/

byte RTCRead(byte Adresse)
{
  (void)outp(RTCAdrPort, Adresse );   /* Communiquer adresse … la RTC */
  return( inp( RTCDtaPort ) );                 /* Lire et transmettre */
}

/**********************************************************************/
/* RTCDT: lit une des cellules de m‚moire de la date ou de l'heure    */
/*        et convertit le r‚sultat en une valeur binaire si           */
/*        l'horloge travaille en format BCD                           */
/* Entr‚e  : adresse de la cellule de m‚moire dans la RTC             */
/* Sortie  : contenu de cette cellule de m‚moire comme valeur binaire */
/* Infos   : si l'adresse sort du domaine autoris‚ (0 … 63), la       */
/*           valeur -1 sera renvoy‚e                                  */
/**********************************************************************/

byte RTCDt(byte Adresse)
{
  if( !(RTCRead( ETATB ) & 4))               /* Mode BCD ou binaire ? */
    return((RTCRead(Adresse) >> 4) * 10 + (RTCRead(Adresse) & 15));
  else
    return( RTCRead(Adresse) );              /* C'est le mode binaire */
}

/**********************************************************************/
/* RTCWRITE: ‚crire une valeur dans une des cellules de la RTC        */
/* Entr‚e  : Voir plus bas                                            */
/* Sortie  : aucune                                                   */
/* Infos   : l'adresse doit ˆtre comprise entre 0 et 63               */
/**********************************************************************/

void RTCWrite( byte Adresse, byte Contenu )
{
  (void)outp(RTCAdrPort, Adresse);    /* Communiquer adresse … la RTC */
  (void)outp(RTCDtaPort, Contenu);          /* Ecrire nouvelle valeur */
}

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()
{
  clrscr();

  printf("\nRTC (c) 1987, 92 by Michael Tischer\n\n");
  printf("Informations tir‚es de l'horloge en temps r‚el sur piles\n");
  printf("========================================================\n");

  if( !(RTCRead(DIAGNOSTIC) & 128))            /* Piles en bon ‚tat ? */
  {                                                            /* Oui */
    printf("- L'horloge est exploit‚e en mode %d heures\n",
              (RTCRead(ETATB) & 2)*6+12);
    printf("- Il est : %2d:%02d:%02d\n",
               RTCDt(HEURES), RTCDt(MINUTES), RTCDt(SECONDES));
    printf("- Nous sommes le : ");
    printf("%d.%02d.%d%d\n", RTCDt(JOUR), RTCDt(MOIS),
                             RTCDt(SIECLE), RTCDt(ANNEE));
  }
  else
    printf("       ATTENTION ! Les piles de l'horloge sont vides\n");
}
