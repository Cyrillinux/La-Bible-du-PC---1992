/***********************************************************************
*                              V D A C C . C                           *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment programmer les registres DAC      *
*                     dans les 256 couleurs du mode graphique de la    *
*                     carte VGA. Le programme utilise les routines en  *
*                     assembleur du module V3240CA.ASM                 *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     :  2.01.1991                                       *
*  DerniŠre MAJ     : 14.02.1992                                       *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS vdacc.c v3240ca                           *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation      : Utilise un projet avec le contenu suivant        *
*                       vdacc.c                                        *
*                       v3240ca.obj                                    *
**--------------------------------------------------------------------**
*  Appel            : vdacc                                            *
**--------------------------------------------------------------------**
*  Info             : Le message "Structure passed by value ..."       *
*                     est normal et n'indique pas une erreur           *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <conio.h>

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;               /* Bricolade d'un type BYTE */

typedef union {                             /* D‚crit un registre DAC */
               struct { BYTE Rouge, Vert, Bleu; } b;
               BYTE RGB[3];
              } DACREG;
typedef DACREG DACARRAY[256];                   /* Table DAC complŠte */

/*-- R‚f‚rences externes aux routines en assembleur-------------------*/

extern void init320400( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void setpage( BYTE page );
extern void showpage( BYTE page );
extern void far * getfontptr( void );

/*-- Constantes ------------------------------------------------------*/

#define MAXX      319                        /* Coordonn‚es maximales */
#define MAXY      399

#define LARGEUR   10        /* Largeur d'un bloc de couleur en pixels */
#define HAUTEUR   20        /* Hauteur d'un bloc de couleur en pixels */
#define DISTANCE  2                       /* Distance entre les blocs */
#define LARGEURT  (16 * LARGEUR + ( 15 * DISTANCE ))    /* Larg. tot. */
#define HAUTEURT  (16 * HAUTEUR + ( 15 * DISTANCE ))     /* Haut tot. */
#define STARTX    (MAXX - LARGEURT ) / 2      /* Coin bloc sup gauche */
#define STARTY    (MAXY - HAUTEURT ) / 2


/***********************************************************************
*  IsVga: Teste la pr‚sence d'une carte VGA.                           *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : 0  si pas de carte VGA, sinon -1                           *
***********************************************************************/

BYTE IsVga( void )
{
 union REGS Regs;              /* Registres pour g‚rer l'interruption */

 Regs.x.ax = 0x1a00;            /* La fonction 1AH n'existe qu'en VGA */
 int86( 0x10, &Regs, &Regs );
 return ( Regs.h.al == 0x1a );               /* Est-elle disponible ? */
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
   fptr = getfontptr();       /* Non, d‚termine par fonct. assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if( cf == 255 )                           /* CaractŠre transparent ? */
   for( i = 0; i < 8; ++i )       /* Oui, dessine que pixels 1er plan */
   {
     masque = (*fptr)[caractere][i];         /* Motif bin. pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       if( masque & 128 )                       /* Pixel … dessiner ? */
         setpix( x+k, y+i, cc );                               /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
   for( i = 0; i < 8; ++i )                    /* Parcourt les lignes */
   {
     masque = (*fptr)[caractere][i];         /* Motif bin. pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       setpix( x+k, y+i, (BYTE) (( masque & 128 ) ? cc : cf) );
   }
}

/***********************************************************************
*  Line: Trace un segment dans la fenˆtre graphique en appliquant      *
*        l'algorithme de Bresenham                                     *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1 = Coordonn‚es de l'origine                         *
*            X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale             *
*            COULEUR = couleur du segment                              *
***********************************************************************/

/*-- Fonction accessoire pour ‚changer deux variables entiŠres -------*/

void SwapInt( int *i1, int *i2 )
{
 int dummy;

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
   if( y1 > y2 )                             /* y1 plus grand que y2? */
   {
     SwapInt( &x1, &x2 );                    /* Oui ‚change X1 et X2, */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
   }

   xincr = ( x2 > x1 ) ?  1 : -1;           /* Fixe le pas horizontal */

   dy    = y2 - y1;
   dx    = abs( x2-x1 );
   d     = 2 * dx - dy;
   aincr = 2 * (dx - dy);
   bincr = 2 * dx;
   x     = x1;
   y     = y1;

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

   dx    = x2 - x1;
   dy    = abs( y2-y1 );
   d     = 2 * dy - dx;
   aincr = 2 * (dy - dx);
   bincr = 2 * dy;
   x     = x1;
   y     = y1;

   setpix( x, y, couleur );               /* Dessine le premier pixel */
   for( x=x1+1; x<=x2; ++x )                  /* Parcourt l'axe des X */
   {
     if( d >= 0 )
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
*  GetDac: D‚termine les contenus d'un certain nombre de registres DAC *
**--------------------------------------------------------------------**
*  Entr‚es : FIRST = Num‚ro du premier registre (0-255)                *
*            NBR   = Nombre de registres DAC                           *
*            BUFP  = Pointeur sur le buffer qui doit recevoir          *
*                    les contenus des registres DAC. Doit ˆtre une     *
*                    variable du type DACREG ou un tableau de variables*
*                    de ce type                                        *
*  Info   : Le buffer transmis doit comporter trois octets par registre*
*           DAC … lire (pour la composante rouge, verte et bleue       *
*           de chaque couleur)                                         *
***********************************************************************/

void GetDac( int First, int Nbr, void far *BufP )
{
 union REGS    Regs;       /* Registres proc. pour g‚rer interruption */
 struct SREGS  SRegs;                         /* Registres de segment */

 Regs.x.ax = 0x1017;          /* Num‚ro de la fonction et de l'option */
 Regs.x.bx = First;                 /* Num‚ro du premier registre DAC */
 Regs.x.cx = Nbr;                    /* Nombre de registres … charger */
 Regs.x.dx = FP_OFF( BufP );
 SRegs.es  = FP_SEG( BufP );                /* Pointeur sur le buffer */
 int86x( 0x10, &Regs, &Regs, &SRegs );         /* D‚clenche int. BIOS */
}

/***********************************************************************
*  SetDac: Charge un certain nombre de registres DAC                   *
**--------------------------------------------------------------------**
*  Entr‚es : FIRST = Num‚ro du premier registre DAC  (0-255)           *
*            NBR   = Nombre de registres DAC                           *
*            BUFP  = Pointeur sur le buffer d'o— seront tir‚es les     *
*                    valeurs … transf‚rer dans les registres DAC.      *
*                    Il doit s'agir d'une variable de type DACREG ou   *
*                    d'un tableau de variables de ce type.             *
*  Info    : cf GetDac()                                               *
***********************************************************************/

void SetDac( int First, int Nbr, void far *BufP )
{
 union REGS    Regs;               /* Registres proc. pour g‚rer int. */
 struct SREGS  SRegs;                         /* Registres de segment */

 Regs.x.ax = 0x1012;          /* Num‚ro de la fonction et de l'option */
 Regs.x.bx = First;                 /* Num‚ro du premier registre DAC */
 Regs.x.cx = Nbr;                    /* Nombre de registres … charger */
 Regs.x.dx = FP_OFF( BufP );
 SRegs.es  = FP_SEG( BufP );                 /* Pointeur sur le buffer*/
 int86x( 0x10, &Regs, &Regs, &SRegs );         /* D‚clenche int. BIOS */
}

/***********************************************************************
*  PrintDac: Affiche le contenu d'un registre DAC et rŠgle la couleur  *
*            dans le registre DAC 255                                  *
**--------------------------------------------------------------------**
*  Entr‚es : DREG  = Registre DAC                                      *
*            NUM   = Num‚ro de ce registre                             *
*            COULEUR = Couleur d'affichage                             *
***********************************************************************/

void PrintDac( DACREG DReg, BYTE Num, BYTE Couleur )
{
  SetDac( 255, 1, &DReg );        /* Couleur dans le registre DAC 255 */
  GrafPrintf( 60, MAXY-10, Couleur, 0,
              "DAC:%3d  R:%2d  V:%2d  B:%2d",
              Num, DReg.b.Rouge, DReg.b.Vert, DReg.b.Bleu);
}

/***********************************************************************
*  Encadre : Trace un cadre autour d'un champ de couleur               *
**--------------------------------------------------------------------**
*  Entr‚es : X     = Abscisse X du champd de couleur (0-15)            *
*            Y     = ordonn‚e Y du champ de couleur (0-15)             *
*            COULEUR = Couleur du cadre                                *
*  Info    : L'‚paisseur du cadre est de 1 pixel ind‚pendamment        *
*            de la distance qui s‚pare les champs                      *
***********************************************************************/

void Encadre( int x, int y, BYTE Couleur)
{
 int sx, sy,                              /* Coin sup gauche du cadre */
     ex, ey;                               /* Coin inf droit du cadre */

/*-- Calcule les coordonn‚es des coins du cadre ----------------------*/

 ex = ( sx = STARTX + x * (LARGEUR + DISTANCE) - 1 ) + LARGEUR + 1;
 ey = ( sy = STARTY + y * (HAUTEUR + DISTANCE) - 1 ) + HAUTEUR + 1;

 Line( sx, sy, ex, sy, Couleur );                   /* Trace le cadre */
 Line( ex, sy, ex, ey, Couleur );
 Line( ex, ey, sx, ey, Couleur );
 Line( sx, ey, sx, sy, Couleur );
}

/***********************************************************************
*  ChangeDacReg: Modifie le contenu d'un registre DAC en m‚moire       *
*                et dans la table DAC de la carte vid‚o, puis          *
*                l'affiche sur l'‚cran                                 *
**--------------------------------------------------------------------**
*  Entr‚es : DREGP = Pointeur sur le registre DAC … modifier           *
*            NUM   = Num‚ro du registre DAC                            *
*            COMP  = Num‚ro de la composante … modifier (0-2)          *
*                    0 = Rouge, 1 = Vert, 2 = Bleu                     *
*            INCR  = Incr‚ment pour cette composante                   *
***********************************************************************/

void ChangeDacReg( DACREG *DRegP, BYTE Num, BYTE Comp, BYTE Incr )
{
 if(( DRegP->RGB[ Comp ] += Incr) > 63 )  /* Incr‚mente la composante */
   DRegP->RGB[ Comp ] = 0;                    /* Sup … 53: ramŠne … 0 */
 SetDac( Num, 1, DRegP );                   /* Charge le registre DAC */
 PrintDac( *DRegP, Num, 15 );           /* Affiche le nouveau contenu */
}

/***********************************************************************
*  Demo: Pr‚sente la programmation des registres DAC et le systŠme     *
*        de couleur de la carte VGA                                    *
**--------------------------------------------------------------------**
*  Entr‚es : n‚ant                                                     *
***********************************************************************/

void Demo( void )
{
 int      x,  y,
          ix, jx,
          iy, jy,
          k,  f;                            /* Compteurs d'it‚rations */
 char     ch;                                                /* Touche*/
 DACARRAY dacbuf;                               /* Table DAC complŠte */
 DACREG   DReg;                               /* Registre DAC courant */

 /*-- Dessine l'‚cran ------------------------------------------------*/

 setpage( 0 );                                    /* Traite la page 0 */
 showpage( 0 );                                  /* Affiche la page 0 */
 GetDac( 0, 256, dacbuf );            /* Charge la table DAC complŠte */

 GrafPrintf( 10, 0, 255, 0, "VDACC  -  (c) 1991 by MICHAEL TISCHER" );

 /*-- Construit le bloc de 16*16 couleurs ----------------------------*/

 iy = STARTY;                          /* Point de d‚part sur l'‚cran */
 jy = STARTY + HAUTEUR - 1;
 f  = 0;
 for( y = 0; y < 16; ++y )         /* Parcourt les 16 lignes de blocs */
 {
   ix = STARTX;
   jx = STARTX + LARGEUR - 1;
   for( x = 0; x < 16; ++x )     /* Parcourt les 16 colonnes de blocs */
   {
     for ( k = iy; k <= jy; ++k )      /* Dessine blocs avec segments */
       Line( ix, k, jx, k, (BYTE) f );
     ix += LARGEUR + DISTANCE;              /* prochain bloc … droite */
     jx += LARGEUR + DISTANCE;
     ++f;                                         /* Couleur suivante */
   }
   iy += HAUTEUR + DISTANCE;                     /* Position suivante */
   jy += HAUTEUR + DISTANCE;
 }

/*-- Lit les entr‚es de l'utilisateur et r‚agit en cons‚quence -------*/

 ix = 0;               /* Commence en haut … gauche avec la couleur 0 */
 iy = 0;
 jx = 0;
 jy = 0;
 k  = 0;
 GetDac( 0, 1, &DReg );                           /* Lit la couleur 0 */
 Encadre( 0, 0, 15 );                  /* Encadre le champ de couleur */
 PrintDac( DReg, 0, 15 );                    /* et affiche le contenu */
 do
 {
   ch = (char) getch();                      /* Lit la touche frapp‚e */
   if( ch )                                       /* touche ‚tendue ? */
     switch( ch )                                 /* Non, on exploite */
     {
       case 'r' :
         ChangeDacReg( &DReg, (BYTE) k, 0, +1 );          /* r=Rouge+ */
         break;
       case 'v' :
         ChangeDacReg( &DReg, (BYTE) k, 1, +1 );           /* g=Vert+ */
         break;
       case 'b' :
         ChangeDacReg( &DReg, (BYTE) k, 2, +1 );           /* b=Bleu+ */
         break;
      case 'R' :
         ChangeDacReg( &DReg, (BYTE) k, 0, -1 );          /* R=Rouge- */
         break;
      case 'V' :
         ChangeDacReg( &DReg, (BYTE) k, 1, -1 );           /* G=vert- */
         break;
      case 'B' :
         ChangeDacReg( &DReg, (BYTE) k, 2, -1 );           /* B=Bleu- */
         break;
      case ' ' :
         {                    /* Space = r‚tablit la valeur d'origine */
            DReg = dacbuf[ k ];
            ChangeDacReg( &DReg, (BYTE) k, 1, 0 );
            break;
         }
     }
   else                                      /* Code de touche ‚tendu */
     switch( getch() )
     {
       case 72 : if( iy == 0 )                /* Curseur vers le haut */
                   jy = 15;
                 else
                   jy = iy - 1;
                 break;

       case 80 : if ( iy == 15 )               /* Curseur vers le bas */
                   jy = 0;
                 else
                   jy = iy + 1;
                 break;

       case 75 : if( ix == 0  )                   /* Curseur … gauche */
                   jx = 15;
                 else
                   jx = ix - 1;
                 break;

       case 77 : if( ix == 15 )                   /* Curseur … droite */
                   jx = 0;
                 else
                   jx = ix + 1;
     }

   if( ix != jx  ||  iy != jy )      /* Nouvelle position du curseur ?*/
   {                                                           /* Oui */
     Encadre( ix, iy, 0 );                   /* Efface l'ancien cadre */
     Encadre( jx, jy, 15 );                 /* Trace le nouveau cadre */
     ix = jx;                 /* M‚morise le nouveau champ de couleur */
     iy = jy;
     k  = iy*16+ix;             /* Calcule le num‚ro du nouveau champ */
     GetDac( k, 1, &DReg );                 /* Charge le registre DAC */
     PrintDac( DReg, (BYTE) k, 15 );                  /* et l'affiche */
   }
 }
 while( ch != 13 );              /* r‚pŠte jusqu'… frappe de <Entr‚e> */

 SetDac( 0, 256, dacbuf );                   /* restaure la table DAC */
}

/*--------------------------------------------------------------------*/
/*--                    PROGRAMME PRINCIPAL                         --*/
/*--------------------------------------------------------------------*/

void main( void )
{
 union REGS   regs;

 if( IsVga() )                              /* A-t-on une carte VGA ? */
 {                                                /* Oui, c'est parti */
   init320400();                      /* Initialise le mode graphique */
   Demo();
   regs.x.ax = 0x0003;                      /* r‚tablit le mode texte */
   int86( 0x10, &regs, &regs );
 }
 else
   printf( "VDACC  -  (c) 1991, 92 by MICHAEL TISCHER\n\nATTENTION"\
           "Ce programme exige une carte VGA.\n\n" );
}
