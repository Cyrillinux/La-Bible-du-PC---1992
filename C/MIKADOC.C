/***********************************************************************
*                          M I K A D O C . C                           *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment mettre en service le mode 512     *
*                     caractŠres des cartes EGA et VGA.                *
*                     La routine de d‚monstration installe une fenˆtre *
*                     graphique en mode texte                          *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     :  2.04.1990                                       *
*  DerniŠre MAJ     : 14.02.1992                                       *
***********************************************************************/

/*-- Constantes et fichiers d'en-tˆte --------------------------------*/

#include <dos.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <conio.h>

#ifdef __TURBOC__                         /* Compilation par Turbo C? */
  #define CLI()           disable()
  #define STI()           enable()
  #define outpw( p, w )   outport( p, w )
  #ifndef inp
    #define outp( p, b )  outportb( p, b )
    #define inp( p )      inportb( p )
  #endif
#else                                   /* Non, par QuickC 2.0 ou MSC */
  #include <conio.h>
  #define random(x)      (rand() % ( x + 1 ))
  #define MK_FP(seg,ofs) ((void far *)\
                         (((unsigned long)(seg) << 16) | (ofs)))
  #define CLI()          _disable()
  #define STI()          _enable()
#endif

#define EGAVGA_SEQUENCER 0x3C4         /* Port adr/data du s‚quenceur */
#define EGAVGA_MONCTR    0x3D4                    /* Contr“leur vid‚o */
#define EGAVGA_GRAPHCTR  0x3CE       /* Ports adr/data du ctrlr graph */
#define CHAR_LARGEUR     8
#define CHAR_BYTES       32
#define MIKADOS          5          /* Mikados visibles simultan‚ment */

#define TRUE             (0 == 0)
#define FALSE            (0 == 1)

#define BLACK            0x00                 /* Attributs de couleur */
#define BLUE             0x01
#define GREEN            0x02
#define CYAN             0x03
#define RED              0x04
#define MAGENTA          0x05
#define BROWN            0x06
#define LIGHTGREY        0x07
#define GREY             0x01
#define LIGHTBLUE        0x09
#define LIGHTGREEN       0x0A
#define LIGHTCYAN        0x0B
#define LIGHTRED         0x0C
#define LIGHTMAGENTA     0x0D
#define YELLOW           0x0E
#define WHITE            0x0F

/*-- D‚clarations de types  ------------------------------------------*/

typedef unsigned char    BYTE;
typedef BYTE             BOOL;

typedef BYTE             PALARY[16];  /* Jeu de registres de palettes */

/*-- Variables globales ----------------------------------------------*/

BYTE far *vioptr = (BYTE far *)0xB8000000,       /* M‚moire graphique */
     far *fontptr;                  /* Pointe sur la police graphique */

BYTE CharHauteur,
     lenx;           /* Largeur en caractŠres de la fenˆtre graphique */
int  xmax,       /* Coordonn‚es max en pixels de la fenˆtre graphique */
     ymax;

/***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA.                *
**--------------------------------------------------------------------**
*  Entr‚e   : n‚ant                                                    *
*  Sortie   : EGA, VGA ou NINI                                         *
***********************************************************************/

BYTE IsEgaVga( void )
{
  union REGS Regs;          /* Registres pour g‚rer les interruptions */

  Regs.x.ax = 0x1a00;           /* La fonction 1Ah n'existe qu'en VGA */
  int86( 0x10, &Regs, &Regs );
  if( Regs.h.al == 0x1a )     /* Cette fonction est-elle disponible ? */
  {                                        /* Oui, on a une carte VGA */
    CharHauteur = 16;                /* Hauteur des caractŠres en VGA */
    return 1;
  }
  else
  {
    CharHauteur = 14;                /* Hauteur des caractŠres en EGA */
    Regs.h.ah = 0x12;                   /* Appelle l'option 10h de la */
    Regs.h.bl = 0x10;                                 /* fonction 12h */
    int86(0x10, &Regs, &Regs );     /* D‚clenche l'interruption vid‚o */
    return Regs.h.bl != 0x10;
  }
}

/***********************************************************************
*  SetCursor   : Positionne le curseur clignotant                      *
**--------------------------------------------------------------------**
*  Entr‚es     : COLONNE = nouvelle colonne du curseur (0-79)          *
*                LIGNE = nouvelle ligne du curseur (0-24)              *
*  Sortie      : n‚ant                                                 *
***********************************************************************/

void SetCursor( BYTE colonne, BYTE ligne )
{
  union REGS  regs;        /*  Registres pour g‚rer les interruptions */

  regs.h.ah = 2;                /* Num‚ro de la fonction "Set Cursor" */
  regs.h.bh = 0;                                /* AccŠde … la page 0 */
  regs.h.dh = ligne;                                 /* Fixe la ligne */
  regs.h.dl = colonne;                               /* et la colonne */
  int86(0x10, &regs, &regs);        /* D‚clenche l'interruption vid‚o */
}

/***********************************************************************
*  PrintfAt : Affiche une chaŒne format‚e en n'importe quel point de   *
*             l'‚cran                                                  *
*                                                                      *
**--------------------------------------------------------------------**
*  Entr‚es  :    COLONNE = Position d'affichage                        *
*                LIGNE                                                 *
*                COULEUR = attribut des caractŠres                     *
*                STRING  = Pointe sur la chaŒne                        *
*  Sortie   : n‚ant                                                    *
*  Info     : Cette fonction ne doit ˆtre invoqu‚e qu'aprŠs            *
*             v‚rification pr‚alable de la pr‚sence d'une              *
*             carte EGA ou VGA                                         *
***********************************************************************/

void PrintfAt( BYTE colonne, BYTE ligne, BYTE couleur, char *string,...)
{
  va_list    parametre;         /* Liste de paramŠtres pour macro _VA */
  char       Affichage[255],        /* Buffer pour la chaŒne format‚e */
             *affptr;
  BYTE far   *vptr;                /* Pointeur sur la m‚moire d'‚cran */

  va_start( parametre, string );          /*Conversion des paramŠtres */
  vsprintf( Affichage, string, parametre );              /* Formatage */

  vptr = (BYTE far *) MK_FP( 0xB800, colonne * 2 + ligne * 160 );

  for( affptr = Affichage; *affptr ; )          /* Parcourt la chaŒne */
  {
    *vptr++ = *(affptr++);           /* Ecrit dans la m‚moire d'‚cran */
    *vptr++ = couleur;                    /* et de mˆme les attributs */
  }
}

/***********************************************************************
*  ClrScr : Efface l'‚cran                                             *
**--------------------------------------------------------------------**
*  Entr‚e : COULEUR  = attribut des caractŠres                         *
*  Sortie : n‚ant                                                      *
***********************************************************************/

void ClrScr( BYTE couleur )
{
  BYTE far  *vptr;                   /* Pointe sur la m‚moire d'‚cran */
  int       count = 2000;           /* Nombre de caractŠres … effacer */

  vptr = (BYTE far *) MK_FP( 0xB800, 0 );         /* Fixe le pointeur */

  for( ; count--; )                    /* Parcourt la m‚moire d'‚cran */
  {
    *vptr++ = ' ';         /* Ecrit les caractŠres en m‚moire d'‚cran */
    *vptr++ = couleur;                    /* et de mˆme les attributs */
  }
}

/***********************************************************************
*  SetCharWidth : Fixe la largeur des caractŠres des cartes VGA        *
*                 … 8 ou 9 pixels                                      *
**--------------------------------------------------------------------**
*  Entr‚e : Largeur = Largeur des caractŠres (8 ou 9)                  *
***********************************************************************/

void SetCharWidth( BYTE largeur )
{
  union REGS Regs;          /* Registres pour g‚rer les interruptions */
  unsigned char x;                             /* Variable de travail */
  Regs.x.bx = ( largeur == 8 ) ? 0x0001 : 0x0800;

  x = inp( 0x3CC ) & (255-12);     /* Passe de la r‚solution de 720 … */
  if ( largeur == 9 )                     /* 640 pixels ou vice-versa */
    x |= 4;
  (void)outp( 0x3C2, x);

  CLI();                    /* Programme le s‚quenceur en cons‚quence */
  outpw( EGAVGA_SEQUENCER, 0x0100 );
  outpw( EGAVGA_SEQUENCER, 0x01 + ( Regs.h.bl << 8 ) );
  outpw( EGAVGA_SEQUENCER, 0x0300 );
  STI();

  Regs.x.ax = 0x1000;               /* Ajuste l'‚cran horizontalement */
  Regs.h.bl = 0x13;
  int86( 0x10, &Regs, &Regs );
}

/***********************************************************************
*  SelectMaps : S‚lectionne les jeux de caractŠres accessibles par     *
*               le bit 3 de l'attribut de caractŠre                    *
*---------------------------------------------------------------------**
*  Entr‚e : MAP0 = Num‚ro du premier jeu de caractŠres  (Bit 3 = 0 )   *
*           MAP1 = Num‚ro du deuxiŠme jeu de caractŠres (Bit 3 = 1 )   *
*  Info   : - avec une carte EGA on peut choisir les jeux 0 … 3,       *
*           - avec une carte VGA les jeux 0 … 7                        *
***********************************************************************/

void SelectMaps( BYTE map0, BYTE map1)
{
  union REGS   Regs;       /*  Registres pour g‚rer les interruptions */

  Regs.x.ax = 0x1103;         /* Registre de s‚lection des caractŠres */
  Regs.h.bl = ( map0 & 3 ) + ( ( map0 & 4 ) << 2 ) +
              ( ( map1 & 3 ) << 2 ) + ( ( map1 & 4 ) << 3 );
  int86( 0x10, &Regs, &Regs );    /* D‚clenche l'interruption du BIOS */
}

/***********************************************************************
*  GetFontAccess : Permet d'acc‚der directement … la deuxiŠme zone     *
*                  de m‚moire o— sont stock‚s les jeux de caractŠres   *
*                  par l'adresse A000:0000                             *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Info   : A l'issue de cette proc‚dure il n'est plus possible        *
*           d'acc‚der … la m‚moire d'‚cran par B800:0000               *
***********************************************************************/

void GetFontAccess( void )
{
  static unsigned  SeqRegs[4] = { 0x0100, 0x0402, 0x0704, 0x0300 },
                   GCRegs[3]  = { 0x0204, 0x0005, 0x0006 };
  BYTE             i;                        /* Compteur d'it‚rations */

  CLI();                             /* Pas d'interruption maintenant */

  for ( i=0; i<4; ++i )         /* Charge les registres du s‚quenceur */
    outpw( EGAVGA_SEQUENCER, SeqRegs[ i ] );

  for ( i=0; i<3; ++i )        /* Charge les registres du ctrlr graph */
    outpw( EGAVGA_GRAPHCTR, GCRegs[ i ] );

  STI();                                /* r‚tablit les interruptions */
}

/***********************************************************************
*  ReleaseFontAccess : R‚tablit l'accŠs … la m‚moire d'‚cran par       *
*                      B800:0000 mais empˆche en mˆme temps l'accŠs    *
*                      aux jeux de caractŠres                          *
*                      situ‚s en page m‚moire Nø 2.                    *
**--------------------------------------------------------------------**
*  Entr‚e            : n‚ant                                           *
***********************************************************************/

void ReleaseFontAccess( void )
{
  static unsigned    SeqRegs[4] = { 0x0100, 0x0302, 0x0304, 0x0300 },
                     GCRegs[3]  = { 0x0004, 0x1005, 0x0E06 };
  BYTE               i;                      /* Compteur d'it‚rations */

  CLI();                            /* Pas d'interruptions maintenant */

  for( i=0; i<4; ++i )          /* Charge les registres du s‚quenceur */
    outpw( EGAVGA_SEQUENCER, SeqRegs[ i ] );

  for ( i=0; i<3; ++i )         /* Charge les registres du Ctrl Graph */
    outpw( EGAVGA_GRAPHCTR, GCRegs[ i ] );

  STI();                                 /*R‚tablit les interruptions */
}

/***********************************************************************
*  ClearGraphArea : Efface la zone graphique en y mettant … 0 les      *
*                   motifs des caractŠres.                             *
**--------------------------------------------------------------------**
*  Entr‚e         : n‚ant                                              *
***********************************************************************/

void ClearGraphArea( void )
{
  int  caract,                              /* CaractŠres … parcourir */
       ligne;             /* Ligne … l'int‚rieur de chaque caractŠre  */

  for( caract = 0; caract < 256; ++caract )             /* CaractŠres */
    for( ligne = 0; ligne < CharHauteur; ++ ligne )         /* Lignes */
      *(fontptr + caract * CHAR_BYTES + ligne) = 0;       /* Mise … 0 */
}

/***********************************************************************
*  InitGraphArea  : Pr‚pare une zone d'‚cran … recevoir un affichage   *
*                  graphique                                           *
**--------------------------------------------------------------------**
*  Entr‚e         : X       = Colonne o— d‚bute la zone (1-80)         *
*                   Y       = Ligne o— d‚bute la zone   (1-25)         *
*                   XLEN    = Largeur de la zone en caractŠres         *
*                   YLEN    = Hauteur de la zone en caractŠres         *
*                   MAP     = Num‚ro du jeu de caractŠres graphiques   *
*                   COULEUR = Couleur de la zone graphique             *
*                             (0 … 7 ou 0xFF)                          *
*  Info    : - Si la couleur indiqu‚e est 0xFF, elle est variable      *
*              ce qui donne un effet de "mikado"                       *
*                                                                      *
***********************************************************************/

void InitGraphArea( BYTE x, BYTE y, BYTE xlen, BYTE ylen, BYTE map,
                    BYTE couleur )
{
  unsigned   offset;                      /* Offset en m‚moir d'‚cran */
  int        colonne, ligne;                 /* Compteur d'it‚rations */
  BYTE       codec;                              /* Code de caractŠre */

  if( xlen * ylen > 256 )                       /* Zone trop grande ? */
    printf( "Erreur : La zone graphique ne doit pas englober"\
            " plus de 256   caractŠres !\n" );
  else
  {
    if( CharHauteur == 16 )                                   /* VGA? */
      SetCharWidth( 8 );     /* Oui, change la largeur des caractŠres */
    SelectMaps( 0, map );         /* S‚lectionne le jeu de caractŠres */
    xmax = xlen*CHAR_LARGEUR;            /* Coordonn‚es max en pixels */
    ymax = ylen*CharHauteur;
    lenx = xlen;
    fontptr = MK_FP( 0xA000, map * 0x4000 );     /* M‚moire graphique */
    GetFontAccess();       /* Autorise l'accŠs aux jeux de caractŠres */
    ClearGraphArea();                               /* Efface la zone */
    ReleaseFontAccess();     /* R‚tablit l'accŠs … la m‚moire d'‚cran */

    /*-- remplit la zone graphique avec des caractŠres ---------------*/

    codec = 0;
    for( ligne = ylen-1; ligne >= 0; --ligne )              /* Lignes */
      for ( colonne = 0; colonne < xlen; ++colonne )      /* Colonnes */
      {                    /* Fixe le code et l'attribut du caractŠre */
        offset = ((ligne+y) * 80 + colonne+x) << 1; /* Ofst m‚m ‚cran */
        *(vioptr+offset) = codec;               /* Ecrit le caractŠre */
        *(vioptr+offset+1) = ( couleur == 0xff )
                                      ? ( codec % 6 ) + 1 + 8
                                      : couleur | 0x08;
        ++codec;                        /* Passe au caractŠre suivant */
      }
  }
}

/***********************************************************************
*  CloseGraphArea : Cl“ture l'accŠs … la zone graphique                *
**--------------------------------------------------------------------**
*  Entr‚e         : n‚ant                                              *
***********************************************************************/

void CloseGraphArea( void )
{
  ReleaseFontAccess();         /* LibŠre l'accŠs … la m‚moire d'‚cran */
  SelectMaps( 0, 0 );               /* Choisit le jeu de caractŠres 0 */
  if( CharHauteur == 16 )                                     /* VGA? */
    SetCharWidth( 9 );         /* Oui, fixe la largeur des caractŠres */
}

/***********************************************************************
*  SetPixel: Dessine ou efface un pixel dans la fenˆtre graphique      *
**--------------------------------------------------------------------**
*  Entr‚es : X,Y   = Coordonn‚es du pixel  (0-...)                     *
*            ON    = TRUE pour dessiner et FALSE pour effacer          *
***********************************************************************/

void SetPixel( int x, int y, BOOL on )
{
  BYTE charnum,                                /* Num‚ro du caractŠre */
       linenr,                    /* Ligne … l'int‚rieur du caractŠre */
       far *bptr;

  if( ( x < xmax ) && ( y < ymax ) )             /* Coordonn‚es o.k.? */
  {                 /* Oui calcule le num‚ro du caractŠre et la ligne */
    charnum = ((x / CHAR_LARGEUR) + (y / CharHauteur * lenx));
    linenr  = CharHauteur - ( y % CharHauteur ) - 1;
    bptr = fontptr + charnum * CHAR_BYTES + linenr;
    if( on )                                 /* Dessiner ou effacer ? */
      *bptr= *bptr | ( 1 << (CHAR_LARGEUR - 1 - ( x % CHAR_LARGEUR )));
    else
      *bptr= *bptr & !( 1 << (CHAR_LARGEUR - 1 - ( x % CHAR_LARGEUR )));
  }
}

/***********************************************************************
*  Line : Trace un segment dans la fenˆtre graphique en appliquant     *
*         l'algorithme de Bresenham                                    *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1 = Coordonn‚es de l'origine                         *
*            X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale             *
*            ON     = TRUE pour dessiner et FALSE pour effacer         *
***********************************************************************/

/*-- Fonction accessoire pour ‚changer deux variables entiŠres -------*/

void SwapInt( int *i1, int *i2 )
{
  int   dummy;

  dummy = *i2;
  *i2   = *i1;
  *i1   = dummy;
}

/*-- Proc‚dure principale --------------------------------------------*/

void Line( int x1, int y1, int x2, int y2, BOOL on )
{
  int d, dx, dy,
      aincr, bincr,
      xincr, yincr,
      x, y;

  if( abs(x2-x1) < abs(y2-y1) )    /* Sens du parcours : axe X ou Y ? */
  {                                                          /* Par Y */
    if( y1 > y2 )                            /* y1 plus grand que y2? */
    {
      SwapInt( &x1, &x2 );                   /* Oui ‚change X1 et X2, */
      SwapInt( &y1, &y2 );                                /* Y1 et Y2 */
    }

    xincr = ( x2 > x1 ) ?  1 : -1;          /* Fixe le pas horizontal */

    dy = y2 - y1;
    dx = abs( x2-x1 );
    d  = 2 * dx - dy;
    aincr = 2 * (dx - dy);
    bincr = 2 * dx;
    x = x1;
    y = y1;

    SetPixel( x, y, on );                 /* dessine le premier pixel */
    for( y=y1+1; y<= y2; ++y )                /* Parcourt l'axe des Y */
    {
      if( d >= 0 )
      {
        x += xincr;
        d += aincr;
      }
      else
        d += bincr;
      SetPixel( x, y, on );
    }
  }
  else                                                       /* par X */
  {
    if( x1 > x2 )                            /* x1 plus grand que x2? */
    {
      SwapInt( &x1, &x2 );                   /* Oui, ‚change X1 et X2 */
      SwapInt( &y1, &y2 );                                /* Y1 et Y2 */
    }

    yincr = ( y2 > y1 ) ? 1 : -1;             /* Fixe le pas vertical */

    dx = x2 - x1;
    dy = abs( y2-y1 );
    d  = 2 * dy - dx;
    aincr = 2 * (dy - dx);
    bincr = 2 * dy;
    x = x1;
    y = y1;

    SetPixel( x, y, on );                 /* Dessine le premier pixel */
    for( x=x1+1; x<=x2; ++x )                 /* Parcourt l'axe des X */
    {
      if( d >= 0 )
      {
        y += yincr;
        d += aincr;
      }
      else
        d += bincr;
      SetPixel( x, y, on );
    }
  }
}

/***********************************************************************
*  SetPalCol : D‚finit une couleur dans une des 16 palettes            *
*              ou la couleur du cadre d'‚cran (Overscan-Color)         *
**--------------------------------------------------------------------**
*  Entr‚e    : RegNr = Num‚ro du registre de palette (0 … 15) ou 16    *
*                    pour la couleur du cadre d'‚cran                  *
*              Col   = Code de la couleur de 0 … 15                    *
***********************************************************************/

void SetPalCol( BYTE RegNr, BYTE Col )
{
  union REGS   Regs;       /*  Registres pour g‚rer les interruptions */

  Regs.x.ax = 0x1000;          /* Option 00h de la fonction vid‚o 10h */
  Regs.h.bh = Col;                                    /* Code couleur */
  Regs.h.bl = RegNr;   /* Num‚ro du registre du contr“leur d'attribut */
  int86( 0x10, &Regs, &Regs );      /* D‚clenche l'interruption vid‚o */
}

/***********************************************************************
*  SetPalAry : installe une nouvelle palette de 16 couleurs sans       *
*              changer la couleur du cadre d'‚cran.                    *
**--------------------------------------------------------------------**
*  Entr‚e    : NewColPtr = Pointeur sur une palettes de type PALARY    *
***********************************************************************/

void SetPalAry( BYTE *NewColPtr )
{
  BYTE   i;                                  /* Compteur d'it‚rations */

  for( i = 0; i < 16; ++i )   /* Parcourt les 16 ‚l‚ments de la table */
    SetPalCol( i, NewColPtr[i] );   /* Fixe une couleur … chaque fois */
}

/***********************************************************************
*  GetPalCol: Lit le contenu d'un registre de palette                  *
**--------------------------------------------------------------------**
*  Entr‚e : RegNr = Num‚ro du registre de Palette (0 … 15) ou 16       *
*                    pour la couleur du cadre d'‚cran                  *
*  Sortie : Code de couleur                                            *
*  Info   : Avec EGA il n'est pas possible de lire le contenu          *
*           des registres de palette. On suppose que dans ce cas       *
*           les registres de palette sont en disposition standard      *
*           et la fonction retourne le num‚ro correspondant.           *
***********************************************************************/

BYTE GetPalCol( BYTE RegNr )
{
 union REGS Regs;          /*  Registres pour g‚rer les interruptions */

 if ( CharHauteur == 14 )                               /* Carte EGA? */
  return RegNr;   /*Oui, impossible de lire les registres de palettes */
 else                                                     /* Non, VGA */
 {
   Regs.x.ax = 0x1007;         /* Option 07h de la fonction vid‚o 10h */
   Regs.h.bl = RegNr;  /* Num‚ro du registre du contr“leur d'attribut */
   int86( 0x10, &Regs, &Regs );         /* Interruption vid‚o du BIOS */
   return Regs.h.bh;                /* Contenu du registre de palette */
  }
}

/***********************************************************************
*  GetPalAry: Lit les contenus des 16 registres de palette et les      *
*             enregistre dans une table         .                      *
**--------------------------------------------------------------------**
*  Entr‚e : ColAryPtr = Pointeur sur une table de palettes du type     *
*                       PALARY, qui va recevoir les codes des couleurs *
***********************************************************************/

void GetPalAry( BYTE *ColAryPtr )
{
 BYTE i;                                     /* Compteur d'it‚rations */

 for (i = 0; i < 16; ++i )     /* parcourt les 16 ‚l‚ments du tableau */
  ColAryPtr[i] = GetPalCol( i );     /* lit une couleur … chaque fois */
}

/***********************************************************************
*  Mikado: D‚monstration du maniement des routines pr‚sent‚es          *
*          dans ce programme                                           *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************/

void Mikado( void )
{
 typedef struct {                         /* Coordonn‚es d'un segment */
                 int x1, y1,
                     x2, y2;
                } LIGNE;

static PALARY NewCols =
     {             /*-- Couleurs des caractŠres de texte ordinaires --*/
      BLACK,                                                  /* noir */
      BLUE,                                                   /* bleu */
      GREEN,                                                  /* vert */
      RED,                                                   /* rouge */
      CYAN,                                                   /* cyan */
      MAGENTA,                                             /* magenta */
      YELLOW,                                                /* jaune */
      WHITE,                                                 /* blanc */
                   /*---------Couleurs des graphiques ----------------*/
      LIGHTBLUE,                                        /* bleu clair */
      LIGHTGREEN,                                       /* vert clair */
      LIGHTRED,                                        /* rouge clair */
          LIGHTCYAN,                                    /* cyan clair */
          LIGHTMAGENTA,                              /* magenta clair */
          BLUE,                                               /* bleu */
          YELLOW,                                            /* jaune */
          WHITE };                                           /* blanc */

 int    i, j,                                /* Compteur d'it‚rations */
        first,                     /* Indice du mikado le plus r‚cent */
        last;                      /* Indice du mikado le plus ancien */
 BOOL   clear;                            /* Pour effacer les mikados */
 LIGNE  lar[MIKADOS];                            /* Table des mikados */
 PALARY OldCols;                      /* Table des anciennes couleurs */

 GetPalAry( OldCols );            /* D‚termine les couleurs pr‚sentes */
 SetPalAry( NewCols );                /* Installe une nouvelle palette*/
              /*TextColor( 7 );
 TextBackGround( 1 );
 GotoXY(1,1); */
 ClrScr( 0x07 );                                    /* Efface l'‚cran */
 for (i=0; i<25; ++i )   /* puis le remplit avec un jeu de caractŠres */
  for (j=0; j<80; ++j )
   PrintfAt( j, i, 0x07, "%c", 32 + (((int) i*80+j) % 224) );

 /*-- Initialise la zone graphique et fait tomber les mikados---------*/

 PrintfAt( 27,6, 0x70, "       M I K A D O       " );
 SetCursor(27,6);
 InitGraphArea( 27, 7, 25, 10, 1, 0xFF );
 GetFontAccess();            /* Assure l'accŠs aux jeux de caractŠres */

 clear = FALSE;                           /* Pour effacer les mikados */
 first = 0;                          /* Commence au d‚but de la table */
 last = 0;
 do
  {                                              /* Boucle des mikados*/
   if (first == MIKADOS )                             /* Wrap-Around? */
    first = 0;
   lar[first].x1 = random( xmax-1 );                /* Cr‚e un mikado */
   lar[first].x2 = random( xmax-1 );
   lar[first].y1 = random( ymax-1 );
   lar[first].y2 = random( ymax-1 );
   Line( lar[first].x1, lar[first].y1,               /* et le dessine */
         lar[first].x2, lar[first].y2, TRUE );
   if ( ++first == MIKADOS )                     /* faut-il effacer ? */
    clear = TRUE;
   if ( clear )                             /* On efface maintenant ? */
    {                                                          /* Oui */
     Line( lar[last].x1, lar[last].y1,
           lar[last].x2, lar[last].y2, FALSE );
     if ( ++last == MIKADOS )
      last = 0;
    }
  }
 while (!kbhit());     /* R‚pŠte l'op‚ration jusqu'… frappe de touche */
 getch();                    /* Retire la touche du buffer du clavier */
/*-- Termine le programme --------------------------------------------*/

 CloseGraphArea();
 SetPalAry( OldCols );     /* Restaure l'ancienne palette de couleurs */
 SetCursor(0,24);
 printf( "\nLe jeu de caractŠres standard est … nouveau en place .\n" );
}

/*--------------------------------------------------------------------*/
/*---------------------- PROGRAMME PRINCIPAL -------------------------*/
/*--------------------------------------------------------------------*/

void main()
{
 if ( IsEgaVga() )                   /* A-t-on une carte EGA ou VGA ? */
  Mikado();                          /* Oui, c'est parti pour la d‚mo */
 else                /* Non, impossible de faire tourner le programme */
  printf( "Attention: aucune carte EGA ou VGA n'est install‚e !" );
}
