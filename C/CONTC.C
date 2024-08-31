/***********************************************************************
*                             C O N T C . C                            *
**--------------------------------------------------------------------**
*  Fonction         : montre comment programmer un d‚filement continu  *
*                     de texte  ( Smooth Scrolling) avec une carte EGA *
*                     ou VGA                                           *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     : 26.08.1990                                       *
*  DerniŠre MAJ     : 14.02.1992                                       *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS Contc.c Contca;                           *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation      : Utiliser un fichier de projet avec le contenu    *
*                     suivant                                          *
*                       Contc.c                                        *
*                       Contca.obj                                     *
**--------------------------------------------------------------------**
*  Appel            : Contc                                            *
***********************************************************************/

#include <dos.h>                                  /* Fichiers en-tˆte */
#include <stdarg.h>
#include <string.h>
#include <stdio.h>

#ifdef __TURBOC__                        /* Compilation avec Turbo C? */
  #define CLI()           disable()
  #define STI()           enable()
  #define outpw( p, w )   outport( p, w )
  #ifndef inp
    #define outp( p, b )  outportb( p, b )
    #define inp( p )      inportb( p )
  #endif
#else                                  /* Non, avec QuickC 2.0 ou MSC */
  #include <conio.h>
  #define MK_FP(seg,ofs) ((void far *)\
                         (((unsigned long)(seg) << 16) | (ofs)))
  #define CLI()          _disable()
  #define STI()          _enable()
#endif

#define FAST         2        /* Valeurs de SPEED dans ShowContText() */
#define MEDIUM       1
#define SLOW         0

#define COULEUR      0x5E                     /* Jaune sur fond lilas */
#define COULEUR1     0x5F                     /* Blanc sur fond lilas */
#define LARGEUR      8            /* Largeur des caractŠres en pixels */
#define HAUTEUR      14   /* Hauteur des caractŠres (lignes de trame) */
#define COLONNES     216                /* Nb de caractŠres … l'‚cran */
#define BANDSIZE     10800                      /* Taille d'une bande */
#define BANDES       3                           /* Nombre de bandes  */
#define MAXLEN       61               /* Nombre maximal de caractŠres */
#define STARTL       5    /* Ligne de d‚part des caractŠres … l'‚cran */

#define CrtAttr      0x3C0       /* Registre du contr“leur d'attribut */
#define CrtStatus    0x3DA                             /* Port d'‚tat */
#define CrtAdr       0x3D4             /* Port d'adresses du moniteur */

#define TRUE         (0 == 0)
#define FALSE        (0 == 1)

#define EGA          0                             /* Types de cartes */
#define VGA          1
#define NINI         2

typedef unsigned char BYTE;               /* Bricolage d'un type BYTE */
typedef unsigned int  WORD;                        /* idem pour  WORD */
typedef BYTE          BOOL;

typedef WORD   VRAM[BANDES][25][COLONNES];     /* Structure m‚m ‚cran */
typedef VRAM   far *VPTR;      /* Pointeur FAR sur la m‚moire d'‚cran */

typedef BYTE   CARDEF[256][14];     /* Structure du jeu de caractŠres */
typedef CARDEF far *CARPTR;         /* Pointeur sur jeu de caractŠres */

/*-- Fonctions externes ----------------------------------------------*/

extern void    far *getfontptr( void );     /* Fonction en assembleur */

/*-- Variables globales ----------------------------------------------*/

VPTR           vp;                 /* Pointeur sur la m‚moire d'‚cran */

/***********************************************************************
*  SetOrigin : Fixe la partie visible de la m‚moire d'‚cran par        *
*              programmation du contr“leur vid‚o                       *
**--------------------------------------------------------------------**
*  Entr‚es :   Band    = Num‚ro de la bande … afficher(1-5)            *
*              Colonne,= Num‚ro de la colonne et de la ligne           *
*              Ligne     affich‚es en haut … gauche                    *
*              PixX,   = Offset en pixels                              *
*              PixY                                                    *
*  Sortie  :   n‚ant                                                   *
***********************************************************************/

void SetOrigin( BYTE band, BYTE colonne, BYTE ligne,
                BYTE pixx, BYTE pixy)
{
 int     offset;             /* Offset de d‚but de la m‚moire d'‚cran */

 offset = ( BANDSIZE >> 1) * band + ligne * COLONNES + colonne;

 /*- Attend un retour vertical du faisceau et sa fin -----------------*/

 while ( !(( inp(CrtStatus) & 8 ) == 8 ));
 while ( !(( inp(CrtStatus) & 8 ) == 0 ));

           /* Ecrit dans les registres 0x0C et 0x0D l'offset de d‚but *
            * de la m‚moire d'‚cran                                   *
            * N'est pris en compte qu'aprŠs le prochain retour de     *
            * balayage vertical                                       */

 CLI();                                   /* Inhibe les interruptions */
 outpw( CrtAdr, ( offset & 0xFF00 ) + 0x0c );
 outpw( CrtAdr, ( (BYTE) offset << 8 ) + 0x0d );
 STI();                                 /* R‚tablit les interruptions */

        /* Attend le d‚but du retour vertical du faisceau pour fixer  *
         * le nouvel offset en pixels et la nouvelle adresse de d‚but *
         * de l'‚cran                                                 */

 while ( !(( inp( CrtStatus ) & 8 ) == 8 ));

        /* Ecrit l'offset en pixels dans les registres 0x08 / 0x13 du *
         * contr“leur d'attribut                                      */

 CLI();                                   /* Inhibe les interruptions */
 outpw( CrtAdr, ( pixy << 8 ) + 0x08 );
 (void) outp( CrtAttr, 0x13 | 0x20 );
 (void) outp( CrtAttr, pixx );
 STI();                                 /* R‚tablit les interruptions */
}

/***********************************************************************
*  PrintChar : Ecrit un caractŠre en dehors de la zone visible de la   *
*              m‚moire d'‚cran                                         *
**--------------------------------------------------------------------**
*  Entr‚e  :   Caractere = CaractŠre … ‚crire                          *
*              Band      = Num‚ro de la bande (0-4)                    *
*              Colonne   = Colonne en m‚moire d'‚cran o— doit commencer*
*                          le caractŠre                                *
*  Info    :   Le caractŠre ‚crit ne peut ˆtre rendu visible que       *
*              par d‚filement continu de l'‚cran .                     *
*              Le motif binaire du caractŠre est tir‚ du jeu de        *
*              caractŠres 14*8 pixels de la ROM EGA ou VGA .           *
***********************************************************************/

void PrintChar( char caractere, BYTE band, BYTE colonne )
{
 char            ch;                         /* Pour stocker un pixel */
 BYTE            i, k,                      /* Compteurs d'it‚rations */
                 masque; /* Masque binaire pour dessiner le caractŠre */
 static CARPTR   fptr = (CARPTR) 0;       /* Jeu de caractŠres en ROM */

 if ( fptr == (CARPTR) 0 )               /* Pointeur d‚j… d‚termin‚ ? */
  fptr = getfontptr();    /* Le charge avec la fonction en assembleur */

  /*- Parcourt et dessine le caractŠre ligne par ligne ---------------*/

 for ( i = 0; i < HAUTEUR; ++i )
 {
   masque = (*fptr)[caractere][i];    /* Motif binaire pour une ligne */
   for ( k = 0; k < LARGEUR; ++k )    /* Parcourt les diff‚rents bits */
   {
     ch = ( masque & 128 ) ? 219 : 32;
     (*vp)[band][STARTL+i][colonne*LARGEUR+k] =
                         (BYTE) ch+( COULEUR << 8 );
     masque <<= 1;                            /* Passe au bit suivant */
   }
 }
}

/***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : EGA, VGA ou NINI                                          *
***********************************************************************/

BYTE IsEgaVga( void )
{
 union REGS    Regs;        /* Registres pour g‚rer les interruptions */

 Regs.x.ax = 0x1a00;              /* N'existe que pour les cartes VGA */
 int86( 0x10, &Regs, &Regs );
 if( Regs.h.al == 0x1a )                  /* La fonction disponible ? */
   return VGA;
 else
 {
   Regs.h.ah = 0x12;                          /* Appelle l'option 10h */
   Regs.h.bl = 0x10;                            /* de la fonction 12h */
   int86(0x10, &Regs, &Regs );               /* Appelle le BIOS vid‚o */
   return ( Regs.h.bl != 0x10 ) ? EGA : NINI;
 }
}

/***********************************************************************
*  ShowContText : Fait d‚filer un texte sur l'‚cran                    *
**--------------------------------------------------------------------**
*  Entr‚e :  dtext = Texte … faire d‚filer sous forme de chaŒne        *
*            speed = Vitesse de d‚filement (SLOW, MEDIUM ou SLOW)      *
*            vc    = carte vid‚o (EGA ou VGA)                          *
***********************************************************************/

void ShowContText( char * dtext, BYTE speed, BYTE vc )
{
  int       band,                                   /* Bande courante */
            colonne,                              /* Colonne courante */
            index,     /* Indice courant dans la chaŒne de caractŠres */
            len,                      /* Longueur du texte … afficher */
            i, k,                            /* Compteur d'it‚rations */
            pixx;                     /* Valeur de panning horizontal */
 WORD far   *wptr;      /* Pointeur pour parcourir la m‚moire d'‚cran */
 union REGS Regs;              /* Registres pour g‚rer l'interruption */

 static BYTE steptable[2][3][10] =
        {
          {                             /* Pas de d‚filement pour EGA */
            {   0,   1,   2,   3,   4,   5,   6,   7, 255, 255 },
            {   0,   2,   4,   6, 255, 255, 255, 255, 255, 255 },
            {   0,   4, 255, 255, 255, 255, 255, 255, 255, 255 }
          },
          {                             /* Pas de d‚filement pour VGA */
            {   8,   0,   1,   2,   3,   4,   5,   6,   7, 255 },
            {   8,   2,   5, 255, 255, 255, 255, 255, 255, 255 },
            {   8,   3, 255, 255, 255, 255, 255, 255, 255, 255 }
          }
        };

 vp = MK_FP( 0xB800, 0x0000 );       /* Pointe sur la m‚moire d'‚cran */

 /*- Remplit toute la m‚moire d'‚cran avec des espaces ---------------*/

 for( index = 0; index < BANDES; ++index )
   for( i = 0; i < 25; ++i )
     for( k = 0; k < COLONNES; ++k )
       (*vp)[index][ i ][ k ] = ( COULEUR << 8 ) + 32;

 /*- Trace des guides horizontaux ------------------------------------*/

 for( k = 0; k < BANDES; ++k )
   for( i = 0; i < COLONNES; ++i )
   {
       (*vp)[ k ][ STARTL-2 ][ i ] =
                   (BYTE) 'Í' + ( COULEUR1 << 8 );
       (*vp)[ k ][ STARTL + HAUTEUR + 2][ i ] =
                   (BYTE) 'Í' + ( COULEUR1 << 8 );
   }

 /*- Retire le curseur cignotant -------------------------------------*/

 Regs.h.ah = 0x02;   /* Num‚ro de la fonction "Set Cursor"  */
 Regs.h.bh = 0;    /* Page d'‚cran */
 Regs.x.dx = 0;      /* Coordonn‚es */
 int86( 0x10, &Regs, &Regs );

 /*- Fixe la couleur du cadre d'‚cran --------------------------------*/

 Regs.h.ah = 0x10;      /* Num‚ro de la fonction "Fixer couleur cadre"*/
 Regs.h.al = 0x01;                                 /* Num‚ro d'option */
 Regs.h.bh = COULEUR >> 4;                        /* Couleur du cadre */
 int86( 0x10, &Regs, &Regs );

 /*- Fixe … COLONNES le nbre de colonnes/ligne dans la m‚moire ‚cran -*/

 outpw( CrtAdr, ( ( COLONNES >> 1 ) << 8 ) + 0x13 );

 /*-- Ecrit le texte d‚filant dans la m‚moire d'‚cran ----------------*/

 if ( ( len = strlen( dtext ) ) > MAXLEN )    /* ChaŒne trop longue ? */
   *(dtext + ( len = MAXLEN )) = '\0';              /* Oui, on abrŠge */

 for( colonne = band = index = 0; index < len; )
 {                                            /* Ecrit les caractŠres */
     PrintChar( *(dtext+index++), band, colonne++ );
     if ( colonne >= COLONNES / LARGEUR )    /* Changement de bande ? */
     {                                                         /* Oui */
         colonne = 0;                      /* Recommence en colonne 1 */
         ++band;                         /* Passe … la bande suivante */
         index -= 80 / LARGEUR;                /* Une page en arriŠre */
     }
 }

 /*-- Fait d‚filer le texte de droite … gauche sur l'‚cran -----------*/

  for( colonne = band = 0 , i = (len - ( 80/LARGEUR )) * LARGEUR;
       i > 0;
       --i )
  {
    for( k = 0; ( pixx = steptable[vc][speed][k]) != 255 ; ++k )
      SetOrigin( band, colonne, 0, pixx, 0 );

    if( ++colonne == COLONNES - 80 )           /* Changement de bande */
    {                                                           /* Oui*/
      colonne = 0;                         /* Recommence en colonne 0 */
      ++band;                                  /* Incr‚mente la bande */
    }
  }

 /*- Remet 80 caractŠres par ligne en m‚moire d'‚cran ----------------*/

 outpw( CrtAdr, ( 40 << 8 ) + 0x13 );

 SetOrigin( 0, 0, 0, 8, 0 );                /* Param‚trage par d‚faut */

 /*- R‚tablit le curseur ---------------------------------------------*/

 Regs.h.ah = 0x02;              /* Num‚ro de la fonction "Set Cursor" */
 Regs.h.bh = 0;                                       /* Page d'‚cran */
 Regs.x.dx = 0;                                        /* Coordonn‚es */
 int86( 0x10, &Regs, &Regs );

 /*- Restaure la couleur du cadre d'‚cran ----------------------------*/

 Regs.h.ah = 0x10;             /* "Fixer la couleur du cadre d'‚cran" */
 Regs.h.al = 0x01;                              /* Num‚ro de l'option */
 Regs.h.bh = 0;                                      /* Cadre en noir */
 int86( 0x10, &Regs, &Regs );

 /*-- Efface l'‚cran -------------------------------------------------*/

 for( wptr = (WORD far *) vp, i = 80*25; i-- ; )
   *wptr++ = 0x0720;
}

/*--------------------------------------------------------------------*/
/*--                       PROGRAMME PRINCIPAL                      --*/
/*--------------------------------------------------------------------*/

void main( void )
{
  BYTE     vc;                       /* Type de carte vid‚o install‚e */

 if( ( vc = IsEgaVga() ) == NINI )
   printf( "TEXTE DEFILANT -  (c) 1990, 92 by MICHAEL TISCHER\n" \
           "Attention : aucune carte EGA ou VGA n'est install‚e !\n" );
 else
   ShowContText( "+++ La Bible PC (c) 1990-1992 Micro Application +++ "\
                 "          ", FAST, vc );
}
