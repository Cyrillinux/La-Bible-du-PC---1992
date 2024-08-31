/***********************************************************************
*                           D V I D E O                                *
*----------------------------------------------------------------------*
*    Fonction       : D‚monstration de l'accŠs direct … la             *
*                     m‚moire d'‚cran                                  *
*----------------------------------------------------------------------*
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 01/10/1988                                       *
*    DerniŠre MAJ   : 01/02/1992                                       *
*----------------------------------------------------------------------*
*    (MICROSOFT C)                                                     *
*    Compilation    : CL /AS DVIC.C                                    *
*    Appel          : DVIC                                             *
*----------------------------------------------------------------------*
*    (BORLAND TURBO C)                                                 *
*    Compilation    : par la commande RUN de l'EDI                     *
*                     (sans fichier de projet )                        *
***********************************************************************/

/*== Fichiers en-tˆte ================================================*/

#include <dos.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <bios.h>

/*== Typedef =========================================================*/

typedef unsigned char    BYTE;            /* Bricolage d'un type BYTE */
typedef struct velb far  *VP;    /* Pointeur FAR sur la m‚moire ‚cran */
typedef BYTE             BOOL;             /* Comme BOOLEAN en Pascal */

/*== Structures ======================================================*/

struct velb
{                       /* D‚crit une position de l'‚cran en 2 octets */
  BYTE caractere,                                    /* Le code ASCII */
       attribut;                          /* L'attribut correspondant */
};

/*== Macros ==========================================================*/

/*-- MK_FP forme un pointeur FAR sur un objet … partir d'une ---------*/
/*-- adresse de segment et d'une adresse d'offset --------------------*/

#ifndef MK_FP                    /* MK_FP n'a pas encore ‚t‚ d‚fini ? */
  #define MK_FP(seg, ofs) ((void far *)((unsigned long)(seg)<<16|(ofs)))
#endif

#define COULEUR(PP, FD)   ((PP << 3) + FD)

/*== Constantes ======================================================*/

#define TRUE  (0==0)          /* Constantes pour travailler avec BOOL */
#define FALSE !TRUE

/*-- Les constantes suivantes fournissent des pointeurs --------------*/
/*-- du segment des variables du BIOS … partir du segment 0x40 -------*/

#define CRT_START         ((unsigned far *) MK_FP(0x40, 0x4E))
#define ADDR_6845         ((unsigned far *) MK_FP(0x40, 0x63))

#define NORMAL            0x07              /* Attributs de caractŠre */
#define CLAIR             0x0f              /* pour une carte d'‚cran */
#define INVERSE           0x70                          /* monochrome */
#define SOULIGNE          0x01
#define CLIGNOTANT        0x80

#define NOIR              0x00           /* Attributs couleur couleur */
#define BLEU              0x01
#define VERT              0x02
#define CYAN              0x03
#define ROUGE             0x04
#define MAGENTA           0x05
#define BRUN              0x06
#define GRISCLAIR         0x07
#define GRISFONCE         0x01
#define BLEAUCLAIR        0x09
#define VERTCLAIR         0x0A
#define CYANCLAIR         0x0B
#define ROUGECLAIR        0x0C
#define MAGENTACLAIR      0x0D
#define JAUNE             0x0E
#define BLANC             0x0F

/*== Variables globales ==============================================*/

VP      vptr;              /* Premier caractŠre de la m‚moire d'‚cran */

/***********************************************************************
*  Fonction         : D P R I N T                                      *
**--------------------------------------------------------------------**
*  Fonction         : Affiche une chaŒne dans la m‚moire d'‚cran.      *
*                                                                      *
*  Param. en entr‚e : - COLONNE  = La colonne de sortie.               *
*                     - LIGNE    = La ligne de sortie.                 *
*                     - COULEUR  = Attribut pour les caractŠres.       *
*                     - STRING   = Pointeur sur la chaŒne.             *
*  Valeur de retour : Aucune                                           *
***********************************************************************/

void dprint(BYTE colonne, BYTE ligne, BYTE couleur, char * string)
{
  register VP    lptr;                        /* Pointeur de comptage */
  register BYTE  i;                         /* Compteur de caractŠres */

 /*-- Pointeur sur la position de sortie dans la m‚moire d'‚cran -----*/
  lptr = (VP) ((BYTE far *) vptr + *CRT_START) + ligne * 80 + colonne;
  for( i=0 ; *string ; ++lptr, ++i )            /* Parcourt la chaŒne */
  {
    lptr->caractere = *(string++);          /* TransfŠre le caractŠre */
    lptr->attribut = couleur;                      /* Fixe l'attribut */
  }
}

/***********************************************************************
*  Fonction         : I N I T _ D P R I N T                            *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine le segment de la m‚moire d'‚cran       *
*                     pour DPRINT:                                     *
*  Param. en entr‚e : Aucun                                            *
*  Valeur de retour : Aucune                                           *
*  Infos            : L'adresse de segment de la m‚moire d'‚cran       *
*                     est plac‚e dans la variable globale VPTR.        *
***********************************************************************/

void init_dprint()
{
  vptr = (VP) MK_FP( (*ADDR_6845 == 0x3B4) ? 0xB000 : 0xB800, 0 );
}

/***********************************************************************
*  Fonction         : C L S                                            *
**--------------------------------------------------------------------**
*  Fonction         : Efface l'‚cran … l'aide de DPRINT.               *
*                                                                      *
*  Param. en entr‚e : - COULEUR    = Attribut pour les caractŠres.     *
*  Valeur de retour : Aucune                                           *
***********************************************************************/

void cls( BYTE couleur )
{
  static char lignevide[81] =
  { ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
    ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
    ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
    ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
    ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
    ' ',' ',' ',' ',' ','\0'
  };

  register BYTE     i;                       /* Compteur d'it‚rations */

  for( i=0; i<24; ++i )            /* Parcourt les diff‚rentes lignes */
    dprint(0, i, couleur, lignevide);      /* Affiche une ligne vierge*/
}

/***********************************************************************
*  Fonction         : N O K E Y                                        *
**--------------------------------------------------------------------**
*  Fonction         : Teste si une touche a ‚t‚ actionn‚e.             *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : TRUE si une touche a ‚t‚ actionn‚e, sinon        *
*                     FALSE.                                           *
***********************************************************************/

BOOL nokey()
{
#ifdef __TURBOC__                              /* Est-on en TURBO-C ? */
  return( bioskey( 1 ) == 0 );  /* OUI, teste le clavier avec le BIOS */
#else                                /* On travaille avec Microsoft C */
  return( _bios_keybrd( _KEYBRD_READY ) == 0 );  /* Test avec le BIOS */
#endif
}

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()
{
 BYTE firstcol,          /* Couleur pour le premier carr‚ sur l'‚cran */
      couleur,                       /* Couleur pour le carr‚ courant */
      colonne,                       /* Position d'affichage actuelle */
      ligne;

  init_dprint();        /* D‚termine le segment de la m‚moire d'‚cran */
  cls( COULEUR(NOIR, VERT) );                       /* Efface l'‚cran */
  dprint(22, 0, BLANC, "DVIDEO  - (c) 1988,92 by Michael Tischer");
  firstcol = NOIR;                           /* Commencer par le NOIR */

  while( nokey() )             /* Attend qu'une touche soit actionn‚e */
  {
    if (++firstcol > BLANC)            /* DerniŠre couleur atteinte ? */
      firstcol = BLEU;                  /* OUI, on continue avec BLEU */
    couleur = firstcol;       /* Fixe la premiŠre couleur sur l'‚cran */

  /*-- Remplit l'‚cran avec des pav‚s --------------------------------*/

    for ( colonne=0; colonne < 80; colonne += 4)
      for (ligne=1; ligne < 24; ligne += 2)
      {
        dprint( colonne, ligne,   couleur, "ÛÛÛÛ");
        dprint( colonne, ligne+1, couleur, "ÛÛÛÛ");
        couleur = ++couleur & 15;
      }
  }
}
