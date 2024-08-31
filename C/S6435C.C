/***********************************************************************
*                            S 6 4 3 5 C . C                           *
**--------------------------------------------------------------------**
*  Fonction          : Montre comment travailler avec des sprites      *
*                      dans le mode graphique 640*350 des cartes EGA   *
*                      et VGA avec 16 couleurs et deux pages d'‚cran   *
*                      Le programme utilise les routines en assembleur *
*                      des modules S6435CA.ASM et V16COLCA.ASM         *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le :  5.12.1990                                           *
*  DerniŠre MAJ : 14.02.1992                                           *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation       : CL /AS s6435c.c s6435ca v16colca                *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation       : Utiliser un fichier de projet avec le contenu   *
*                      suivant:                                        *
*                      s6435c.c                                        *
*                      v16colca.obj                                    *
*                      s6435ca.obj                                     *
**--------------------------------------------------------------------**
*  Appel           : s6435c                                            *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <conio.h>

/*-- D‚clarations d‚pendantes du compilateur--------------------------*/

#ifdef __TURBOC__
  #include <alloc.h>
#else
  #include <malloc.h>
  #define random(x) ( rand() % (x+1) )          /* Fonction al‚atoire */
#endif

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;
typedef BYTE BOOL;

typedef struct {    /* Buffer de pixels pour GetVideo() et PutVideo() */
        BYTE largeurbyte,             /* Largeur de la zone en octets */
             hauteur;                             /* Nombre de lignes */
        int  pixblen;                   /* taille du buffer de pixels */
        void *pixbptr;            /* Pointeur sur le buffer de pixels */
               } PIXBUF;
typedef PIXBUF *PIXPTR;           /* Pointeur sur un buffer de pixels */

typedef struct {                                 /* Image d'un sprite */
        BYTE   largeur,                             /* Largeur totale */
               hauteur;                /* Hauteur en lignes de pixels */
        void   *bmskp[8];       /* Pointeur sur le masque binaire AND */
        PIXPTR pixmp[8];         /* Pointeur sur d‚finition de pixels */
               } SPLOOK;

typedef struct {                        /* Descripteur de sprite (ID) */
        SPLOOK *splookp;                      /* Pointeur sur l'image */
        int    x[2], y[2];             /* Coordonn‚es en pages 0 et 1 */
        PIXPTR hgptr[2];            /* Pointeur sur le buffer du fond */
               } SPID;

typedef struct {                           /* d‚crit un champ de bits */
        BYTE *champptr, /* Pointe sur le buffer avec le champ de bits */
             *courptr,                /* Pointeur sur l'octet courant */
             bitcour,               /* Bit courant dans octet courant */
             bytecour;                   /* valeur de l'octet courant */
               } CHAMPBITS;
typedef CHAMPBITS *CBPTR;            /* Pointeur sur un champ de bits */

/*-- R‚f‚rences externes aux routines en assembleur----------------*/

extern void init640350( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void setpage( int page );
extern void showpage( int page );
extern void far * getfontptr( void );

extern void copybuf2video( BYTE *bufptr, BYTE page,
                           int ax, int ay, BYTE largeur,
                           BYTE hauteur );
extern void copyvideo2buf( BYTE *bufptr, BYTE page,
                           int dex, int dey, BYTE largeur,
                           BYTE hauteur );
extern void mergeandcopybuf2video( void * spribufptr, void * hgbufptr,
                                   void * andbufptr, BYTE page,
                                   int  ax, int  ay,
                                   BYTE largeur, BYTE hauteur );

/*-- Constantes ------------------------------------------------------*/

#define TRUE  ( 0 == 0 )
#define FALSE ( 0 == 1 )

#define MAXX 639                             /* Coordonn‚es maximales */
#define MAXY 349

#define OUT_LEFT   1    /* Indicateurs de collision dans SpriteMove() */
#define OUT_TOP    2
#define OUT_RIGHT  4
#define OUT_BOTTOM 8
#define OUT_NO     0                              /* Pas de collision */

#define EGA       0                                /* Types de cartes */
#define VGA       1
#define NINI      2

#define ALLOCBUF ((PIXPTR) 0)         /* GetVideo(): alloue un buffer */

/***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : EGA, VGA ou NINI                                          *
***********************************************************************/

BYTE IsEgaVga( void )
{
 union REGS  Regs;              /* Registes pour g‚rer l'interruption */

 Regs.x.ax = 0x1a00;            /* La fonction 1Ah n'existe qu'en VGA */
 int86( 0x10, &Regs, &Regs );
 if( Regs.h.al == 0x1a )                     /* Est-elle disponible ? */
   return VGA;
 else
 {
   Regs.h.ah = 0x12;                          /* Appelle l'option 10h */
   Regs.h.bl = 0x10;                            /* de la fonction 12h */
   int86(0x10, &Regs, &Regs );       /*D‚clenche l'interruption vid‚o */
   return (BYTE) (( Regs.h.bl != 0x10 ) ? EGA : NINI);
 }
}

/***********************************************************************
*  PrintChar : Ecrit un caractŠre en dehors de la zone visible         *
*              de la m‚moire d'‚cran                                   *
**--------------------------------------------------------------------**
*  Entr‚e  :   caractere = caractŠre … afficher                        *
*              x, y    = Coordonn‚es du coin sup‚rieur gauche          *
*              cc      = Couleur du caractŠre                          *
*              cf      = Couleur du fond                               *
*  Info    : Le caractŠre est dessin‚ dans une matrice de 8*8 pixels - *
*            sur la base du jeu de caractŠres 8*8 en ROM               *
***********************************************************************/

void PrintChar( char caractere, int x, int y, BYTE cc, BYTE cf )
{
 typedef BYTE   CARDEF[256][8];     /* Structure du jeu de caractŠres */
 typedef CARDEF far *CARPTR;       /* Pointe sur un jeu de caractŠres */

 BYTE     i, k,                              /* Compteur d'it‚rations */
          masque;        /* Masque binaire pour dessiner le caractŠre */

 static   CARPTR fptr = (CARPTR) 0;       /* Jeu de caractŠres en ROM */

 if( fptr == (CARPTR) 0 )      /* A-t-on d‚j… d‚termin‚ ce pointeur ? */
   fptr = getfontptr();     /*Non, d‚termine avec fonction assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if( cf == 255 )                           /* CaractŠre transparent ? */
   for ( i = 0; i < 8; ++i )   /* Oui, dessine que pixels du 1er plan */
   {
     masque = (*fptr)[caractere][i];          /* Motif bin pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       if( masque & 128 )                       /* Pixel … dessiner ? */
         setpix( x+k, y+i, cc );                               /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
   for ( i = 0; i < 8; ++i )                   /* Parcourt les lignes */
   {
     masque = (*fptr)[caractere][i];          /* Motif bin pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       setpix( x+k, y+i, (BYTE) (( masque & 128 ) ? cc : cf) );
   }
}

/***********************************************************************
*  Line: Trace un segment dans la fenˆtre graphique en appliquant      *
*        l'algorithme de Bresenham                                     *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1  = Coordonn‚es de l'origine                        *
*            X2, Y2  = Coordonn‚es de l'extr‚mit‚ terminale            *
*            COULEUR = couleur dusegment                               *
***********************************************************************/

/*-- Fonction accessoire pour ‚changer deux variables entiŠres -------*/

void SwapInt( int *i1, int *i2 )
{
 int   dummy;

 dummy = *i2;  *i2   = *i1;  *i1   = dummy;
}

/*-- Proc‚dure principale --------------------------------------------*/

void Line( int x1, int y1, int x2, int y2, BYTE couleur )
{
 int d, dx, dy,
     aincr, bincr,
     xincr, yincr,
     x, y;

 if( abs(x2-x1) < abs(y2-y1) )     /* Sens du parcours : axe X ou Y ? */
 {                                                           /* Par Y */
   if ( y1 > y2 )                            /* y1 plus grand que y2? */
   {
     SwapInt( &x1, &x2 );                    /* Oui ‚change X1 et X2, */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
   }

   xincr = ( x2 > x1 ) ?  1 : -1;           /* Fixe le pas horizontal */

   dy     = y2 - y1;
   dx     = abs( x2-x1 );
   d      = 2 * dx - dy;
   aincr  = 2 * (dx - dy);
   bincr  = 2 * dx;
   x      = x1;
   y      = y1;

   setpix( x, y, couleur );               /* dessine le premier pixel */
   for( y=y1+1; y<= y2; ++y )                 /* Parcourt l'axe des Y */
   {
     if( d >= 0 )
     {
       x += xincr;
       d += aincr;
     }
     else
       d += bincr;
     setpix( x, y, couleur );
   }
 }
 else                                                        /* par X */
 {
   if( x1 > x2 )                             /* x1 plus grand que x2? */
   {
     SwapInt( &x1, &x2 );                    /* Oui, ‚change X1 et X2 */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
   }

   yincr = ( y2 > y1 ) ? 1 : -1;              /* Fixe le pas vertical */

   dx     = x2 - x1;
   dy     = abs( y2-y1 );
   d      = 2 * dy - dx;
   aincr  = 2 * (dy - dx);
   bincr  = 2 * dy;
   x      = x1;
   y      = y1;

   setpix( x, y, couleur );               /* Dessine le premier pixel */
   for( x=x1+1; x<=x2; ++x )                  /* Parcourt l'axe des X */
   {
     if ( d >= 0 )
     {
       y += yincr;
       d += aincr;
     }
     else
       d += bincr;
     setpix( x, y, couleur );
   }
 }
}

/***********************************************************************
*  GrafPrintf: Affiche une chaŒne format‚e sur l'‚cran graphique       *
**--------------------------------------------------------------------**
*  Entr‚es : X, Y   = Coordonn‚es de d‚part (0 - ...)                  *
*            CC     = Couleur des caractŠres                           *
*            CF     = Couleur du fond  (255 = transparent)             *
*            STRING = ChaŒne avec indications de formatage             *
*            ...    = Expressions comme pour printf                    *
***********************************************************************/

void GrafPrintf( int x, int y, BYTE cc, BYTE cf, char * string, ... )
{
 va_list  parameter;     /* Liste de paramŠtres pour les macros VA_...*/
 char     affichage[255],           /* Buffer pour la chaŒne format‚e */
          *cp;

 va_start( parameter, string );           /* Convertit les paramŠtres */
 vsprintf( affichage, string, parameter );                 /* Formate */
 for( cp = affichage; *cp; ++cp, x+= 8 )         /* Affiche la chaŒne */
   PrintChar( *cp, x, y, cc, cf );          /* format‚e par PrintChar */
}

/***********************************************************************
*  GetVideo: Charge le contenu d'une zone rectangualire de la m‚moire  *
*            d'‚cran dans un buffer                                    *
**--------------------------------------------------------------------**
*  Entr‚es : PAGE   = Page d'‚cran   (0 ou 1)                          *
*            X1, Y1 = Coordonn‚es de d‚part                            *
*            LARGEUR= Largeur de la zone rectangulaire en pixels       *
*            HAUTEUR= Hauteur de la zone rectangulaire en pixels       *
*            BUFPTR = Pointeur sur le buffer de pixels qui va          *
*                     m‚moriser les informations                       *
*  Sortie  : Pointeur sur le buffer cr‚‚ qui contient la zone indiqu‚e *
*  Info    : Si on donne au paramŠtre BUFPTR la valeur ALLOCBUF,       *
*            un nouveau buffer de pixels est allou‚ sur le tas et      *
*            retourn‚. Ce buffer peut ˆtre transmis lors d'un nouvel   *
*            appel si l'ancien contenu ne m‚rite pas d'ˆtre pr‚serv‚   *
*            et si la taille de la zone n'a pas chang‚                 *
*            La zone sp‚cifi‚e doit commencer … une abscisse divisible *
*            par huit et s'‚tendre sur un nombre de pixels multiple    *
*            de huit                                                   *
***********************************************************************/

PIXPTR GetVideo( BYTE page, int x1, int y1, BYTE largeur, BYTE hauteur,
                 PIXPTR bufptr )
{
 if( bufptr == ALLOCBUF )                 /* Pas de buffer transmis ? */
 {                                                  /* Non, on alloue */
   bufptr = malloc( sizeof( PIXBUF ) );             /* Cr‚e le buffer */
   bufptr->pixbptr = malloc( (largeur*hauteur) / 2 );
   bufptr->hauteur = hauteur;          /* Hauteur du buffer en lignes */
   bufptr->largeurbyte = largeur / 8;  /* Largeur d'1 ligne en octets */
   bufptr->pixblen = (largeur*hauteur) / 2;   /* Taille totale buffer */
 }

 copyvideo2buf( bufptr->pixbptr, page, x1, y1, largeur / 8, hauteur );
 return bufptr;                  /* Renvoie un pointeur sur le buffer */
}

/***********************************************************************
*  PutVideo: R‚‚crit dans la m‚moire d'‚cran le contenu d'une zone     *
*            rectangulaire pr‚alablement sauvegard‚e par GetVideo()    *
**--------------------------------------------------------------------**
*  Entr‚es : BUFPTR = Pointeur renvoy‚ par Getvideo() et r‚f‚ren‡ant   *
*                     un buffer de pixels                              *
*            PAGE   = Page d'‚cran(0 ou 1)                             *
*            X1, Y1 = Coordonn‚es de d‚but                             *
*  Info    : Le buffer de pixels n'est pas effac‚ par cette proc‚dure, *
*            cette tƒche ‚tant men‚e … bien par FreePixBuf()           *
*            L'abscisse X sp‚cifi‚e doit ˆtre un multiple de huit      *
***********************************************************************/

void PutVideo( PIXPTR bufptr, BYTE page, int x1, int y1 )
{
 copybuf2video( bufptr->pixbptr, page, x1, y1,
                bufptr->largeurbyte, bufptr->hauteur );
}

/***********************************************************************
*  FreePixBuf: Efface un buffer de pixels allou‚ sur le tas            *
*              par GetVideo                                            *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR = Pointeur renvoy‚ par Getvideo() et r‚f‚ren‡ant    *
*                     un buffer de pixels                              *
***********************************************************************/

void FreePixBuf( PIXPTR bufptr )
{
 free( bufptr->pixbptr );
 free( bufptr );
}

/***********************************************************************
*  CreateSprite: Cr‚e un sprite … l'aide d'un motif de pixels          *
*                pr‚alablement compil‚                                 *
**--------------------------------------------------------------------**
*  Entr‚e  : SPLOOKP = Pointeur sur la structure de donn‚e produite    *
*                      par CompileSprite()                             *
*  Sortie  : Pointeur sur la structure du sprite cr‚‚e                 *
*  Info    : la m‚morisation du fond du sprite n‚cessite               *
*            deux zones contigu‰s de la taille du sprite               *
***********************************************************************/

SPID *CreateSprite( SPLOOK *splookp )
{
 SPID   *spidp;          /* Pointeur sur la structure du sprite cr‚‚e */

 spidp = (SPID *) malloc( sizeof(SPID) );     /* Alloue de la m‚moire */
 spidp->splookp = splookp;   /* Reporte les donn‚es dans la structure */

 /*- Cr‚e desx buffers de fond en sauvegardant par GetVideo une zone -*/
                                           /*- de la m‚moire d'‚cran -*/

 spidp->hgptr[0] = GetVideo( 0, 0, 0, splookp->largeur,
                             splookp->hauteur, ALLOCBUF );
 spidp->hgptr[1] = GetVideo( 0, 0, 0, splookp->largeur,
                             splookp->hauteur, ALLOCBUF );
 return spidp;      /* Renvoie un pointeur sur la structure du sprite */
}

/***********************************************************************
*  CBInit: Cr‚e un champ de bits et pr‚pare son traitement             *
**--------------------------------------------------------------------**
*  Entr‚e  : NBBIT = Nombre de bits … placer dans le champ             *
*  Sortie  : Pointeur sur un descripteur de champ de bits              *
***********************************************************************/

CBPTR CBInit( int NbBit )
{
 CBPTR   cbptr;                 /* Pointeur sur le descripteur g‚n‚r‚ */

 cbptr = malloc( sizeof( CHAMPBITS ) );        /* Cr‚e le descripteur */

           /*-- Cr‚ation et initialisation du champ de bits ----------*/

 cbptr->champptr = cbptr->courptr  = malloc( ( NbBit + 7 ) / 8 );
 cbptr->bitcour  = cbptr->bytecour = 0;

 return cbptr;             /* Retourne un pointeur sur le descripteur */
}

/***********************************************************************
*  CBAppendBit: Ajoute un bit … un champ de bits                       *
**--------------------------------------------------------------------**
*  Entr‚e  : BFID = Pointeur sur le descripteur de champ de bits       *
*                    renvoy‚ par CBInit()                              *
*            BIT  = Valeur du bit … ajouter (0 ou 1)                   *
*  Sortie  : n‚ant                                                     *
***********************************************************************/

void CBAppendBit( CBPTR bfid, BYTE bit )
{
 bfid->bytecour |= bit;                 /* Place le bit e, position 0 */
 if( bfid->bitcour == 7 )                           /* octet rempli ? */
 {                                                             /* Oui */
   *(bfid->courptr++) = bfid->bytecour;       /* Octet dans le buffer */
   bfid->bytecour = bfid->bitcour = 0;                  /* Remise … 0 */
 }
 else                                     /* L'octet n'est pas rempli */
 {
   ++bfid->bitcour;                          /* Traite un bit de plus */
   bfid->bytecour <<= 1;                  /* D‚cale le masque binaire */
 }
}

/***********************************************************************
*  CBEnd : Cl“ture l'exploitation d'un champ de bits et efface son     *
*          descripteur sans effacer le champ proprement dit            *
**--------------------------------------------------------------------**
*  Entr‚e  : BFID = Pointeur sur le descripteur de champ de bit renvoy‚*
*                   par CBInit()                                       *
*  Sortie  : Pointeur sur le champ proprement dit dont le buffer peut  *
*            ˆtre lib‚r‚ par FREE().                                   *
***********************************************************************/

void *CBEnd( CBPTR bfid )
{
 void *retptr;        /* Pointeur sur le champ de bits proprement dit */

 if( bfid->bitcour )                       /* Dernier octet rempli  ? */
   *bfid->courptr = bfid->bytecour << (7 - bfid->bitcour );    /* Non */

 retptr = bfid->champptr;           /* M‚morise ptr sur champ de bits */
 free( bfid );                               /* Efface le descripteur */

 return retptr;          /* Retourne un pointeur sur le champ de bits */
}

/***********************************************************************
*  CompileSprite: Cr‚e le motif binaire d'un sprite … l'aide d'une     *
*                 d‚finition connus au moment de l'ex‚cution           *
**--------------------------------------------------------------------**
*  Entr‚es : BUFP    = Pointeur sur un tableau de pointeurs r‚f‚ren‡ant*
*                      des chaŒnes de caractŠres qui repr‚sentent le   *
*                      sprite                                          *
*            HAUTEUR = Hauteur du sprite et nombre de chaŒnes de       *
*                      caractŠres                                      *
*  Info    : Dans le motif transmis, un espace correspond … un pixel du*
*            fond, A au code de couleur 0, B … 1, C … 2, etc...        *
***********************************************************************/

SPLOOK *CompileSprite( char **bufp, BYTE hauteur )
{
 BYTE   slargeur,          /* Longueur des chaŒnes = largeur du motif */
        largeurspr,                            /* Largeur des sprites */
        c,                                   /* M‚morise un caractŠre */
        i, k, l, y;                         /* Compteurs d'it‚rations */
 SPLOOK *splookp;        /* Pointeur sur la structure du sprite cr‚‚e */
 PIXPTR tpix;                      /* M‚morise temporairement le fond */
 CBPTR  cbptr;
           /*-- Cr‚e une structure d'image et la remplit -------------*/

 splookp    = (SPLOOK *) malloc( sizeof(SPLOOK) );
 slargeur   = (BYTE) strlen( *bufp );   /* Long. chaŒnes = larg. logo */
 largeurspr = ( ( slargeur + 7 + 7 ) / 8 ) * 8;     /* Largeur totale */
 splookp->largeur = largeurspr;
 splookp->hauteur = hauteur;

 setpage( 1 );                     /* Construit les sprites en page 1 */
 showpage( 0 );                             /* mais affiche la page 0 */

 tpix = GetVideo( 1, 0, 0, largeurspr, hauteur, ALLOCBUF );   /* Fond */

       /*-- Elabore et code huit fois le sprite ----------------------*/

 for( l = 0; l < 8; ++l )
 {                         /* Remplit d'abord le fond de pixels noirs */
   for( y = 0; y < hauteur; ++y )
     Line( 0, y, largeurspr-1, y, 0 );

   cbptr = CBInit( largeurspr*hauteur );     /* M‚moire pour buf. AND */

   for( i = 0; i < hauteur ; ++i )             /* Parcourt les lignes */
   {
     for( y = l; y; --y )    /* Cr‚e les bits AND pour le bord gauche */
       CBAppendBit( cbptr, 1 );

     for( k = 0; k < slargeur; ++k )         /* Parcourt les colonnes */
     {
       if( ( c = *(*(bufp+i)+k) ) == 32 )          /* Pixel de fond ? */
       {                                       /* Oui, code couleur 0 */
         setpix( k+l, i, 0 );
         CBAppendBit( cbptr, 1 );           /* Le pixel de fond reste */
        }
        else                      /* Non, met le code couleur indiqu‚ */
        {
          setpix( k+l, i, c-64 );
          CBAppendBit( cbptr, 0 );         /* EnlŠve le pixel de fond */
        }
     }

     for( y = largeurspr-slargeur-l; y ; --y )     /* Ajoute bits AND */
       CBAppendBit( cbptr, 1 );                 /* pour le bord droit */
   }
   splookp->bmskp[ l ] = CBEnd( cbptr );

  /*-- Cherche le motif de pixels du sprite dans la m‚moire d'‚cran --*/
   splookp->pixmp[ l ] = GetVideo( 1, 0, 0,
                                   largeurspr, hauteur, ALLOCBUF );
 }                                         /* Passe au sprite suivant */

 PutVideo( tpix, 1, 0, 0 );   /* Restaure le fond du sprite en page 1 */
 FreePixBuf( tpix );                           /* et efface le buffer */

 return splookp;       /* Renvoie un pointeur sur le buffer du sprite */
}

/***********************************************************************
*  PrintSprite : Affiche un sprite dans une page donn‚e                *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE = Page concern‚e (0 ou 1)                            *
***********************************************************************/

void PrintSprite( register SPID *spidp, BYTE page )
{
 int   x;                                     /* Abscisse X du sprite */

 x = spidp->x[page];
 mergeandcopybuf2video( spidp->splookp->pixmp[x % 8]->pixbptr,
                        spidp->hgptr[page]->pixbptr,
                        spidp->splookp->bmskp[x % 8],
                        page,
                        x & (~7),
                        spidp->y[page],
                        spidp->splookp->largeur / 8,
                        spidp->splookp->hauteur );
}

/***********************************************************************
*  GetSpriteBg: Lit le fond du sprite et le m‚morise … l'emplacement   *
*                pr‚vu                                                 *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page d'o— est tir‚ le fond (0 ou 1)               *
***********************************************************************/

void GetSpriteBg( register SPID *spidp, BYTE page )
{
 GetVideo( page, spidp->x[page] & (~7),  spidp->y[page],
           spidp->splookp->largeur, spidp->splookp->hauteur,
           spidp->hgptr[page] );
}

/***********************************************************************
*  RestoreSpriteBg: R‚tablit dans la page d'origine le fond d'un sprite*
*                   sauvegard‚ au pr‚alable                            *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page o— doit ˆtre recopi‚ le fond (0 ou 1)        *
***********************************************************************/

void RestoreSpriteBg( register SPID *spidp, BYTE page )
{
 PutVideo( spidp->hgptr[page], page,
           spidp->x[page] & (~7), spidp->y[page] );
}

/***********************************************************************
*  MoveSprite: D‚place le sprite                                       *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP  = Pointeur sur la structure du sprite              *
*            PAGE   = Page o— doit ˆtre recopi‚ le fond (0 ou 1)       *
*            DELTAX = D‚placements dans les directions X et Y          *
*            DELTAY                                                    *
*  Sortie  : Indicateur de collision , cf constantes OUT_...           *
***********************************************************************/

BYTE MoveSprite( SPID *spidp, BYTE page, int deltax, int deltay )
{
 int  nouvx, nouvy;                /* Nouvelles coordonn‚es du sprite */
 BYTE out;                     /* M‚morise un indicateur de collision */

          /*-- D‚cale l'abscisse X et d‚tecte les collisions ---------*/

 if( ( nouvx = spidp->x[page] + deltax ) < 0 )
 {
   nouvx = 0 - deltax - spidp->x[page];
   out = OUT_LEFT;
 }
 else
   if( nouvx > MAXX - spidp->splookp->largeur )
   {
     nouvx = (2*(MAXX+1))-nouvx-2*(spidp->splookp->largeur);
     out = OUT_RIGHT;
   }
   else
     out = OUT_NO;

          /*-- D‚cale l'ordonn‚e Y et d‚tecte les collisions ---------*/
 if((nouvy=spidp->y[page]+deltay) <0)                   /* Bord sup ? */
 {                                    /* oui deltay doit ˆtre n‚gatif */
   nouvy = 0 - deltay - spidp->y[page];
   out |= OUT_TOP;
 }
 else
   if( nouvy + spidp->splookp->hauteur > MAXY+1  )      /* bord inf ? */
   {                                  /* Ja, deltay doit ˆtre positif */
     nouvy = (2*(MAXY+1))-nouvy-2*(spidp->splookp->hauteur);
     out |= OUT_BOTTOM;
   }

/*-- Fixe une nouvelle position que si diff‚rente de l'ancienne */

 if( nouvx != spidp->x[page]  ||  nouvy != spidp->y[page] )
 {                                               /* Nouvelle position */
   RestoreSpriteBg( spidp, page );                /* Restaure le fond */
   spidp->x[page] = nouvx;                  /* M‚morise les nouvelles */
   spidp->y[page] = nouvy;                             /* coordonn‚es */
   GetSpriteBg( spidp, page );                 /* Lit le nouveau fond */
   PrintSprite( spidp, page );   /* Dessine sprite dans page indiqu‚e */
 }
 return out;
}

/***********************************************************************
*  SetSprite: Place le sprite … une position donn‚e                    *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            x0, y0 = Coordonn‚es du sprite en page 0                  *
*            x1, y1 = Coordonn‚es du sprite en page  1                 *
*  Info    : Cette fonction doit ˆtre d‚clench‚e avant le premier      *
*            appel … MoveSprite()                                      *
***********************************************************************/

void SetSprite( SPID *spidp, int x0, int y0, int x1, int y1 )
{
 spidp->x[0] = x0;      /* M‚morise les coordonn‚es dans la structure */
 spidp->x[1] = x1;
 spidp->y[0] = y0;
 spidp->y[1] = y1;

 GetSpriteBg( spidp, 0 );                    /* Lit le fond du sprite */
 GetSpriteBg( spidp, 1 );                           /* en page 0 et 1 */
 PrintSprite( spidp, 0 );                        /* Dessine le sprite */
 PrintSprite( spidp, 1 );                           /* en page 0 et 1 */
}

/***********************************************************************
*  RemoveSprite: Retire le sprite de l'emplacement qu'il occupe        *
*                le rendant ainsi invisible                            *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*  Info   : A l'issue de cette fonction il faut appeler SetSprite()    *
*           avant de d‚placer le sprite par MoveSprite()               *
***********************************************************************/

void RemoveSprite( SPID *spidp )
{
 RestoreSpriteBg( spidp, 0 );                     /* R‚tablit le fond */
 RestoreSpriteBg( spidp, 1 );                       /* en page 0 et 1 */
}

/***********************************************************************
*  Demo: D‚montre l'usage des diff‚rentes fonctions de ce module       *
***********************************************************************/

void Demo( void )
{
 static char *VaisseauMontant[20] =
                { "               AA               ",
                  "              AAAA              ",
                  "              AAAA              ",
                  "               AA               ",
                  "             GGBBGG             ",
                  "            GBBCCBBG            ",
                  "           GBBBCCBBBG           ",
                  "          GBBBBBBBBBBG          ",
                  "          GBBBBBBBBBBG          ",
                  " G       GBBBBBBBBBBBBG       G ",
                  "GCG     GGDBBBBBBBBBBDGG     GCG",
                  "GCG   GGBBBDBBB  BBBDBBBGG   GCG",
                  "GCBGGGBBBBBDBB    BBDBBBBBGGGBCG",
                  "GCBBBBBBBBBBDB    BDBBBBBBBBBBCG",
                  "BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB",
                  "GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ",
                  "  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ",
                  "    GGBBDDDDDGGGGGDDDDDDBBG     ",
                  "      GDDDDGGG    GGGDDDDG      ",
                  "       DDDD          DDDD       "  };


 static char *VaisseauDescendant[20] =
                {
                  "       DDDD          DDDD       ",
                  "      GDDDDGGG    GGGDDDDG      ",
                  "    GGBBDDDDDGGGGGDDDDDDBBG     ",
                  "  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ",
                  "GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ",
                  "BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB",
                  "GCBBBBBBBBBBDB    BDBBBBBBBBBBCG",
                  "GCBGGGBBBBBDBB    BBDBBBBBGGGBCG",
                  "GCG   GGBBBDBBB  BBBDBBBGG   GCG",
                  "GCG     GGDBBBBBBBBBBDGG     GCG",
                  " G       GBBBBBBBBBBBBG       G ",
                  "          GBBBBBBBBBBG          ",
                  "          GBBBBBBBBBBG          ",
                  "           GBBBCCBBBG           ",
                  "            GBBCCBBG            ",
                  "             GGBBGG             ",
                  "               AA               ",
                  "              AAAA              ",
                  "              AAAA              ",
                  "               AA               " };

 #define NBSPR 6                                 /* Nombre de sprites */
 #define LARGEUR 42    /* Nombre de caractŠres de l'avis de copyright */
 #define HAUTEUR  6                 /* Hauteur du mˆme avis en lignes */
 #define SX     (MAXX-(LARGEUR*8)) / 2               /* Coordonn‚s de */
 #define SY     (MAXY-(HAUTEUR*8)) / 2                      /* d‚part */

 struct {                                 /* D‚crit les sprites g‚r‚s */
      SPID *spidp;                   /* Pointeur sur l'identificateur */
      int  deltax[2],       /* D‚placement horizontale en page 0 et 1 */
           deltay[2];          /* D‚placement vertical en page 0 et 1 */
        } sprites[ NBSPR ];
 BYTE   page,                                        /* Page courante */
        out;                   /* M‚morise un indicateur de collision */
 int    x, y, i,                             /* Compteur d'it‚rations */
        dx, dy;                                       /* D‚placements */
 char   lc;
 SPLOOK *vaisseauupp, *vaisseaudnp;      /* Pointeurs sur les sprites */

 srand( *(int far *) 0x0040006cl );   /* Init. g‚n‚r. nbr. al‚atoires */

       /*-- Construit les motifs binaires des sprites ----------------*/

 vaisseauupp = CompileSprite( VaisseauMontant,    20 );
 vaisseaudnp = CompileSprite( VaisseauDescendant, 20 );

       /*-- Remplit de caractŠres les deux pages graphqiues ----------*/

 for( page = 0; page < 2; ++ page )
 {
   setpage( page );
   showpage( page );
   for( lc = 0, y = 0; y < (MAXY+1)-8; y += 12 )
     for( x = 0; x < (MAXX+1)-8; x += 8 )
       GrafPrintf( x, y, lc & 15, 255, "%c", lc++ & 127 );

     /*-- Affiche l'avis de copyright---------------------------------*/

   Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
   Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
   Line( SX+LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
   Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
   GrafPrintf( SX, SY,    15, 4,
               "                                          "  );
   GrafPrintf( SX, SY+8,  15, 4,
               "  S6435C (c) 1990, 92 by Michael Tischer  " );
   GrafPrintf( SX, SY+16, 15, 4,
               "                                          "  );
   GrafPrintf( SX, SY+24, 15, 4,
               "  D‚monstration de sprites dans le mode   "  );
   GrafPrintf( SX, SY+32, 15, 4,
               "       EGA/VGA 640x350 16 couleurs        "  );
   GrafPrintf( SX, SY+40, 15, 4,
               "                                          "  );
  }

               /*-- R‚alise les diff‚rents sprites -------------------*/

 for( i = 0; i < NBSPR ; ++ i)
 {
   sprites[ i ].spidp = CreateSprite( vaisseauupp );
   do                                 /* S‚lectionne les d‚placements */
   {
     dx = 0;
     dy = random(8) - 4;
   }
   while ( dx==0  &&  dy==0 );

   sprites[ i ].deltax[0] = sprites[ i ].deltax[1] = dx * 2;
   sprites[ i ].deltay[0] = sprites[ i ].deltay[1] = dy * 2;

   x = ( MAXX / NBSPR * i ) + (MAXX / NBSPR - 40) / 2 ;
   y = random( (MAXY+1) - 40 );
   SetSprite( sprites[ i ].spidp, x, y, x - dx, y - dy );
 }

/* D‚place les sprites et les fait rebondir aux extr‚mit‚s de l'‚cran */

 page = 1;                                      /* Commence en page 1 */
 while( !kbhit() )       /* Une frappe de touche interrompt la boucle */
 {
   showpage( (BYTE) (1 - page) );             /* AFfiche l'autre page */

   for( i = 0; i < NBSPR; ++ i)               /* Parcourt les sprites */
   {                 /* D‚place les sprites et d‚tecte les collisions */
     out = MoveSprite( sprites[i].spidp, page,
                       sprites[i].deltax[page],
                       sprites[i].deltay[page] );
     if( out & OUT_TOP  ||  out & OUT_BOTTOM )           /* Contact ? */
     {                /* Oui change le sens du d‚placement et l'image */
       sprites[i].deltay[page] = 0 - sprites[i].deltay[page];
       sprites[i].spidp->splookp = ( out & OUT_TOP ) ? vaisseaudnp
                                                     : vaisseauupp;
     }
     if( out & OUT_LEFT  ||  out & OUT_RIGHT )
       sprites[i].deltax[page] = 0 - sprites[i].deltax[page];
   }
   page = (page+1) & 1;               /* Passe de 1 … 0 et vice versa */
  }
}

/*--------------------------------------------------------------------*/
/*--                       PROGRAMME PRINCIPAL                      --*/
/*--------------------------------------------------------------------*/

void main( void )
{
 union REGS  regs;

 if( IsEgaVga() != NINI )       /*Dispose-t-on d'une carte EGA ou VGA */
 {                                                /* Oui, c'est parti */
   init640350();                      /* Initialise le mode graphique */
   Demo();
   getch();                             /*Attend une frappe de touche */
   regs.x.ax = 0x0003;                       /* Revient au mode texte */
   int86( 0x10, &regs, &regs );
 }
 else
   printf( "S6435C.C - (c) 1990, 92 by MICHAEL TISCHER\n\nATTENTION "\
           "Ce programme n‚cessite une carte EGA ou VGA.\n\n" );
}
