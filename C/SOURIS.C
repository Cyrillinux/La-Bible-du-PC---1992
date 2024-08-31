/**********************************************************************/
/*                         S O U R I S C . C                          */
/*--------------------------------------------------------------------*/
/*    Fonction       : Fournit diff‚rentes fonctions pour le travail  */
/*                     avec la souris                                 */
/*--------------------------------------------------------------------*/
/*    Auteur         : MICHAEL TISCHER                                */
/*    D‚velopp‚ le   : 20/04/1989                                     */
/*    DerniŠre modif.: 22/04/1989                                     */
/*--------------------------------------------------------------------*/
/*    Microsoft C                                                     */
/*    Cr‚ation       : CL /AS SOURISC.C SOURISCA.OBJ                  */
/*    Appel          : SOURISC                                        */
/*--------------------------------------------------------------------*/
/*    Turbo C (environnement int‚gr‚)                                 */
/*    Cr‚ation       : avec fichier Project de contenu suivant :      */
/*                       SOURISC                                      */
/*                       SOURISCA.OBJ                                 */
/*                     avec le modŠle de m‚moire SMALL.               */
/*                     Le Stack Checking doit ˆtre d‚sactiv‚.         */
/*    Appel          : SOURIS                                         */
/**********************************************************************/

/*== Int‚grer les fichiers Include ===================================*/

#include <dos.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

extern void far AssHand( void );            /* D‚claration externe du */
                                        /* gestionnaire en assembleur */
/*== Typedefs ========================================================*/

typedef unsigned char BYTE;           /* Nous nous bricolons un octet */
typedef unsigned long PTRVIEW; /* Masque pour le curseur de la souris */
typedef struct {                            /* D‚crit une zone souris */
                BYTE x1,      /* Coordonn‚es du coin sup‚rieur gauche */
                     y1,             /* et du coin inf‚rieur droit de */
                     x2,                         /* la zone sp‚cifi‚e */
                     y2;
                PTRVIEW ptr_mask;    /* Masque pour le curseur souris */
               } ZONE;
typedef void (far * MOUHAPTR)( void ); /* Ptr sur driver d'‚v‚nements */

/*== Constantes ======================================================*/

#define TRUE  ( 1 == 1 )
#define FALSE ( 1 == 0 )

/*-- Codes Event -----------------------------------------------------*/

#define EV_MOU_MOVE      1                         /* Souris d‚plac‚e */
#define EV_LEFT_PRESS    2       /* Bouton gauche de la souris appuy‚ */
#define EV_LEFT_REL      4      /* Bouton gauche de la souris relƒch‚ */
#define EV_RIGHT_PRESS   8        /* Bouton droit de la souris appuy‚ */
#define EV_RIGHT_REL    16       /* Bouton droit de la souris relƒch‚ */
#define EV_MOU_ALL      31              /* Tous les ‚v‚nements souris */

#define AUCUNE_ZONE 255      /* Curseur de la souris pas dans zone xy */

/*-- Macros ----------------------------------------------------------*/

#define MouGetCol()       (ev_col)    /* Fournissent position et zone */
#define MouGetRow()       (ev_row)          /* de souris au moment de */
#define MouGetZone()      (ev_zon)   /* l'intervention de l'‚v‚nement */
#define MouAvail()        ( mavail ) /* Renvoie TRUE si souris existe */
#define MouGetActCol()    ( moucol )         /* Renvoient chaque fois */
#define MouGetActRow()    ( mourow )    /* position et zone actuelles */
#define MouGetActZon()    ( mouzon )                  /* de la souris */
#define MouIsLeftPress()  ( mouevent & EV_LEFT_PRESS )
#define MouIsLeftRel()    ( mouevent & EV_LEFT_REL )
#define MouIsRightPress() ( mouevent & EV_RIGHT_PRESS )
#define MouIsRightRel()   ( mouevent & EV_RIGHT_REL )
#define MouSetMoveAreaAll() MouSetMoveArea( 0, 0, tcol-1, tline-1 );

#define ELVEC(x) ( sizeof(x) / sizeof(x[0]) ) /* Nb d'‚l‚ments dans X */

/*-- Macros pour cr‚er le masque bits servant … d‚finir            ---*/
/*-- l'apparence du curseur de la souris.                          ---*/
/*-- L'appel de MouPtrMask se pr‚sente par exemple ainsi :         ---*/
/*--   MouPtrMask( PTRDIFCHAR( 'x' ), PTRINVCOL )                  ---*/
/*-- pour que le curseur de la souris apparaisse sous forme d'un   ---*/
/*-- petit X avec la couleur inverse du caractŠre qu'il recouvre.  ---*/

#define MouPtrMask( z, f )\
  ( (( (PTRVIEW) f) >> 8 << 24) + ((( PTRVIEW) z) >> 8 << 16) +\
    (((f) & 255) << 8) + ((z) & 255) )

#define PTRSAMECHAR   ( 0x00ff )                    /* Mˆme caractŠre */
#define PTRDIFCHAR(z) ( (z) << 8 )                 /* Autre caractŠre */
#define PTRSAMECOL    ( 0x00ff )                      /* Mˆme couleur */
#define PTRINVCOL     ( 0x7777 )                  /* Couleur invers‚e */
#define PTRSAMECOLC   ( 0x807f )          /* Mˆme couleur clignotante */
#define PTRINVCOLC    ( 0xF777 )      /* Couleur invers‚e clignotante */
#define PTRDIFCOL(f)  ( (f) << 8 )                   /* Autre couleur */
#define PTRDIFCOLC(f) (((f)|0x80) << 8)  /* Autre couleur clignotante */

#define ET  0               /* Combinaisons Event pour MouEventWait() */
#define OU 1

#define MOUINT(rin, rout) int86(0x33, &rin, &rout)
#define MOUINTX(rin, rout, sr) int86x(0x33, &rin, &rout, &sr)

/*-- Macros de conversion des coordonn‚es de la souris entre l'‚cran */
/*-- virtuel de la souris et l'‚cran de texte */

#define XTOCOL(x) ( (x) >> 3 )                      /* X divis‚ par 8 */
#define YTOROW(y) ( (y) >> 3 )                 /* Ligne divis‚e par 8 */
#define COLTOX(c) ( (c) << 3 )                            /* C fois 8 */
#define ROWTOY(r) ( (r) << 3 )                         /* Ligne par 8 */

/*== Variables globales ==============================================*/

BYTE tline,                              /* Nombre de lignes de texte */
     tcol,                             /* Nombre de colonnes de texte */
     mavail = FALSE;                /* Est TRUE, si souris disponible */

/*-- Masque pour le curseur standard de la souris --------------------*/

PTRVIEW stdptr = MouPtrMask( PTRSAMECHAR, PTRINVCOL );

BYTE    * bufz,         /* Ptr sur buffer pour identification de zone */
        nmb_zones = 0;               /* Aucune zone d‚finie jusqu'ici */

ZONE * zone_act;               /* Pointeur sur vecteur de zone actuel */
int     blen;                 /* Longueur du buffer de zone en octets */

/*-- Variables d‚finies lors de chaque appel du gestionnaire souris */

BYTE mouzon = AUCUNE_ZONE,                 /* Zone de souris actuelle */
     moucol,                 /* Colonne de la souris (‚cran de texte) */
     mourow;                   /* Ligne de la souris (‚cran de texte) */
int  mouevent = EV_LEFT_REL + EV_RIGHT_REL;    /* Masque d'‚v‚nements */

/*-- Variables qui ne sont d‚finies par le gestionnaire de la      ---*/
/*-- souris que lorsqu'intervient un ‚v‚nement attendu             ---*/

BYTE ev_zon,                   /* Zone dans laquelle figure la souris */
     ev_col,                                  /* Colonne de la souris */
     ev_row;                                    /* Ligne de la souris */

/***********************************************************************
*  Fonction         : M o u D e f i n e P t r                          *
**--------------------------------------------------------------------**
*  Fonction         : D‚finit les masques curseur et ‚cran d‚finissant *
*                     l'apparence du curseur de la souris              *
*  ParamŠtres en entr‚e : MASK = les deux masques bits combin‚s en une *
*                                valeur 32 bits du type UNSIGNED LONG  *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Les 16 bits de plus fort poids de MASK repr‚-  *
*                       sentent le masque ‚cran, les 16 bits de plus   *
*                       faible poids le masque curseur                 *
***********************************************************************/

#pragma check_stack(off)                 /* Pas de Stack Checking ici */

void MouDefinePtr( PTRVIEW mask )
{
 static PTRVIEW anciencurseur = (PTRVIEW) 0;  /* DerniŠre valeur MASK */
 union REGS regs; /* Registres du processeur pour l'appel d'interrup. */

 if ( anciencurseur != mask )      /* Modification au dernier appel ? */
  {                                                            /* Oui */
   regs.x.ax = 0x000a;         /* Nø fct pour "Set text pointer type" */
   regs.x.bx = 0;                           /* Fixer curseur logiciel */
   regs.x.cx = mask;               /* Le mot faible est le masque AND */
   regs.x.dx = mask >> 16;           /* Le mot fort est le masque XOR */
   MOUINT(regs, regs);              /* Appeler le driver de la souris */
   anciencurseur = mask;             /* Ranger le nouveau masque bits */
  }
}

/***********************************************************************
*  Fonction         : M o u E v e n t H a n d l e r                    *
**--------------------------------------------------------------------**
*  Fonction         : Est appel‚ par le driver de la souris … travers  *
*                     la routine assembleur AssHand dŠs qu'intervient  *
*                     un ‚v‚nement concernant la souris.               *
*  ParamŠtres en entr‚e : EvFlags  = Masque Event de l'‚v‚nement       *
*                         ButState = Etat des boutons de la souris     *
*                         X, Y     = Position actuelle du curseur de   *
*                                    la souris, d‚j… convertie vers le *
*                                    systŠme de coordonn‚es de texte   *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Cette fonction est seulement destin‚e … ˆtre   *
*                       appel‚e par le driver de la souris et ne doit  *
*                       pas ˆtre appel‚e par une autre fonction.       *
***********************************************************************/

void MouEventHandler( int EvFlags, int ButState, int x, int y )
{
 #define LBITS ( EV_LEFT_PRESS | EV_LEFT_REL )
 #define RBITS ( EV_RIGHT_PRESS | EV_RIGHT_REL )

 unsigned nouzon;                       /* Num‚ro de la nouvelle zone */

 mouevent &= ~1;                                  /* Masquer le bit 0 */
 mouevent |= ( EvFlags & 1 );  /* Copier le bit 0 … partir de EvFlags */

 if ( EvFlags & LBITS )/* Bouton gauche de la souris relƒch‚/appuy‚ ? */
  {                                                            /* Oui */
   mouevent &= ~LBITS;                      /* Masquer ‚tat ant‚rieur */
   mouevent |= ( EvFlags & LBITS );          /* Incruster nouvel ‚tat */
  }

 if ( EvFlags & RBITS ) /* Bouton droit de la souris relƒch‚/appuy‚ ? */
  {                                 /* Oui, masquer et incruster bits */
   mouevent &= ~RBITS;                      /* Masquer ‚tat ant‚rieur */
   mouevent |= ( EvFlags & RBITS );          /* Incruster nouvel ‚tat */
  }

 moucol = x;                /* Convertir colonne et colonnes de texte */
 mourow = y;                    /* Convertir ligne en lignes de texte */

 /*-- D‚terminer zone dans laquelle figure la souris et examiner   ---*/
 /*-- si cette zone s'est modifi‚e depuis le dernier appel. Dans   ---*/
 /*-- ce cas, l'apparence du curseur de la souris doit ˆtre        ---*/
 /*-- red‚finie.                                                   ---*/

 nouzon = *(bufz + mourow * tcol + moucol);           /* Retirer zone */
 if ( nouzon != mouzon )                           /* Nouvelle zone ? */
  MouDefinePtr((nouzon==AUCUNE_ZONE) ? stdptr :
                                        (zone_act+nouzon)->ptr_mask);
 mouzon = nouzon;      /* Ranger num‚ro de zone dans variable globale */
}

#pragma check_stack                /* Restaurer ancien ‚tat en ce qui */
#pragma check_stack               /* concerne le Stack Checking       */

/***********************************************************************
*  Fonction         : M o u I B u f F i l l                            *
**--------------------------------------------------------------------**
*  Fonction         : Stocke le code de zone pour une zone de l'‚cran  *
*                     d‚termin‚e … l'int‚rieur de la m‚moire ‚cran     *
*                     interne du module                                *
*  ParamŠtres en entr‚e : x1, y1 = coin sup‚rieur gauche de zone ‚cran *
*                         x2, y2 = coin inf‚rieur droit de zone ‚cran  *
*                     CODE   = Code de zone                            *
*  Valeur Return    : Aucune                                           *
*  Infos            : Cette fonction ne doit ˆtre appel‚e qu'…         *
*                     l'int‚rieur de ce module.                        *
***********************************************************************/

static void MouIBufFill( BYTE x1, BYTE y1,
                         BYTE x2, BYTE y2, BYTE code )
{
 register BYTE * lptr;             /* Pointeur sur la m‚moire de zone */
 BYTE i, j;                                     /* Compteur de boucle */

 lptr = bufz + y1 * tcol + x1;      /* Pointeur sur la premiŠre ligne */

 /*-- Parcourir les diff‚rentes lignes -------------------------------*/
 for (j=x2 - x1 + 1 ; y1 <= y2; ++y1, lptr+=tcol )
  memset( lptr, code, j );                              /* Fixer code */
}

/***********************************************************************
*  Fonction         : M o u D e f Z o n e                              *
**--------------------------------------------------------------------**
*  Fonction         : Permet de d‚finir diff‚rentes zones de l'‚cran   *
*                     qui seront dot‚es de codes respectifs pour le    *
*                     travail avec la souris.                          *
*  Params. en entr‚e: - NOMBRE = Nombre de zones de l'‚cran            *
*                     - PTR    = Pointeur sur vecteur avec les des-    *
*                                cripteurs de zone du type ZONE        *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Le code AUCUNE_ZONE est affect‚ aux zones de   *
*                       l'‚cran rest‚es libres.                        *
*                     - Lorsque la souris p‚nŠtre dans l'une des zones *
*                       de l'‚cran sp‚cifi‚es, le gestionnaire de la   *
*                       souris commute automatiquement sur l'apparence *
*                       du curseur de la souris d‚finie par le         *
*                       descripteur de zone correspondant.             *
*                     - Comme seul le pointeur transmis est stock‚,    *
*                       mais que le vecteur transmis n'est pas copi‚   *
*                       dans un buffer s‚par‚, le contenu du vecteur   *
*                       ne doit pas ˆtre modifi‚ jusqu'au prochain     *
*                       appel de cette fonction.                       *
***********************************************************************/

void MouDefZone( BYTE nombre, ZONE * ptr )
{
 register BYTE i,                               /* Compteur de boucle */
               zone;                             /* Zone de la souris */

 zone_act = ptr;                       /* Ranger pointeur sur vecteur */
 nmb_zones = nombre;                            /* et nombre de zones */
 memset( bufz, AUCUNE_ZONE, blen );
 for (i=0 ; i<nombre ; ++ptr )
  MouIBufFill( ptr->x1, ptr->y1, ptr->x2, ptr->y2, i++);

 /*-- R‚d‚finir le curseur de la souris ------------------------------*/

 zone = *(bufz + mourow * tcol + moucol);       /*Zone souris actuelle*/
 MouDefinePtr( ( zone == AUCUNE_ZONE ) ? stdptr
               : (zone_act+zone)->ptr_mask );
}

/***********************************************************************
*  Fonction         : M o u E v e n t W a i t                          *
**--------------------------------------------------------------------**
*  Fonction         : Attend l'intervention d'un ‚v‚nement d‚termin‚   *
*                     sur le clavier.                                  *
*  Params. en entr‚e: TYP        = D‚finit la combinaison entre les    *
*                                  diff‚rents ‚v‚nements.              *
*                     WAIT_EVENT = Masque bits sp‚cifiant l'‚v‚nement  *
*                                  attendu.                            *
*  Valeur Return    : Masque bits d‚crivant le ou les ‚v‚nements       *
*                     intervenu(s)                                     *
*  Infos            : - WAIT_EVENT peut ˆtre compos‚ par combinaison   *
*                       Ou entre les diverses constantes, telles que   *
*                       EV_MOU_MOVE ou EV_LEFT_PRESS par exemple       *
*                     - ET ou OU peuvent ˆtre sp‚cifi‚s pour le TYP.   *
*                       Avec ET, la fonction ne revient au programme   *
*                       d'appel qu'une fois que tous les ‚v‚nements    *
*                       attendus sont intervenus simultan‚ment, alors  *
*                       que OU se contente de l'intervention d'un      *
*                       ‚v‚nement au moins.                            *
***********************************************************************/

int MouEventWait( BYTE typ, int wait_event )
{
 int act_event;                             /* Le masque Event actuel */
 register BYTE colonne = moucol,          /* DerniŠre position souris */
               ligne  = mourow;
 BYTE fin = FALSE;             /* Devient TRUE si ‚v‚nement intervenu */

 while ( !fin )        /* R‚p‚ter jusqu'… ce qu'‚v‚nement intervienne */
  {
   /*-- Attendre que l'un des ‚v‚nements intervienne -----------------*/

   if ( typ == ET )   /* ET : tous les ‚v‚nements doivent se produire */
     while ( (act_event = mouevent) != wait_event)
      ;
   else                 /* OU : au moins un ‚v‚nement doit intervenir */
     while ( ( (act_event = mouevent) & wait_event) == 0)
      ;

   act_event &= wait_event;   /* Ne laisser que les bits d'‚v‚nements */

       /*-- Lorsqu'on attend le d‚placement de la souris, l'‚v‚nement */
        /*-- n'est accept‚ que si le curseur de la souris a ‚t‚ amen‚ */
          /*-- dans une autre ligne et/ou colonne de l'‚cran de texte */

   if ((wait_event & EV_MOU_MOVE) && colonne==moucol && ligne==mourow)
    {                     /* Souris d‚plac‚e mais mˆme position ‚cran */
     act_event &= (~EV_MOU_MOVE);                 /* Masquer bit Move */
     fin = (act_event != 0);           /* Reste-t-il des ‚v‚nements ? */
    }
   else                                        /* Ev‚nement intervenu */
    fin = TRUE;
  }
 ev_col = moucol;                       /* Conserver position et zone */
 ev_row = mourow;                        /* souris dans des variables */
 ev_zon = mouzon;                                         /* globales */
 return( act_event );                        /* Renvoyer masque Event */
}

/***********************************************************************
*  Fonction         : M o u I S e t E v e n t H a n d l e r            *
**--------------------------------------------------------------------**
*  Fonction         : Installe un gestionnaire d'‚v‚nements qui est    *
*                     appel‚ par le driver de la souris lorsqu'un      *
*                     ‚v‚nement souris d‚termin‚ intervient.           *
*  Params en entr‚e : EVENT = Masque bits sp‚cifiant l'‚v‚nement       *
*                             dont l'intervention doit entraŒner       *
*                             l'appel du gestionnaire de la souris.    *
*                     PTR   = Pointeur sur gestionnaire de la souris   *
*  Valeur Return    : Aucune                                           *
*  Infos            : - EVENT peut ˆtre compos‚ par combinaison Ou     *
*                       des diff‚rentes constantes telles que          *
*                       EV_MOU_MOVE ou EV_LEFT_PRESS du fichier        *
***********************************************************************/

static void MouISetEventHandler( unsigned event, MOUHAPTR ptr )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */
 struct SREGS sregs; /* Registre de segment pour l'appel d'interrupt. */

 regs.x.ax = 0x000C;              /* Nø fct. pour "Set Mouse Handler" */
 regs.x.cx = event;                    /* Charger masque d'‚v‚nements */
 regs.x.dx = FP_OFF( ptr );       /* Adresse d'offset du gestionnaire */
 sregs.es  = FP_SEG( ptr );     /* Adresse de segment du gestionnaire */
 MOUINTX( regs, regs, sregs );      /* Appeler le driver de la souris */
}

/***********************************************************************
*  Fonction         : M o u I G e t X                                  *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine la colonne (de texte) dans laquelle    *
*                     figure le curseur de la souris.                  *
*  Params en entr‚e : Aucun                                            *
*  Valeur Return    : La colonne de souris par rapport … ‚cran texte   *
***********************************************************************/

static BYTE MouIGetX( void )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax= 0x0003;             /* Nø fct.: pour "Get mouse position" */
 MOUINT( regs, regs );              /* Appeler le driver de la souris */
 return XTOCOL( regs.x.cx );         /* Convertir colonne et renvoyer */
}

/***********************************************************************
*  Fonction         : M o u I G e t Y                                  *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine la ligne (de texte) dans laquelle      *
*                     figure le curseur de la souris.                  *
*  Params en entr‚e : Aucun                                            *
*  Valeur Return    : La ligne de souris par rapport … ‚cran de texte  *
***********************************************************************/

static BYTE MouIGetY( void )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax= 0x0003;             /* Nø fct.: pour "Get mouse position" */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
 return YTOROW(regs.x.dx);             /* Convertir ligne et renvoyer */
}

/***********************************************************************
*  Fonction         : M o u S h o w M o u s e                          *
**--------------------------------------------------------------------**
*  Fonction         : Afficher curseur souris sur l'‚cran.             *
*  Params en entr‚e : Aucun                                            *
*  Valeur Return    : Aucune                                           *
*  Infos            : Les appels de MouHidemMouse() et MouShowMouse()  *
*                     doivent s'‚quilibrer pour avoir un effet.        *
***********************************************************************/

void MouShowMouse( void )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax = 0x0001;                    /* Nø fct.: pour "Show Mouse" */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
}

/***********************************************************************
*  Fonction         : M o u H i d e M o u s e                          *
**--------------------------------------------------------------------**
*  Fonction         : Eliminer curseur de la souris de l'‚cran.        *
*  Params en entr‚e : Aucun                                            *
*  Valeur Return    : Aucune                                           *
*  Infos            : Les appels de MouHidemMouse() et MouShowMouse()  *
*                     doivent s'‚quilibrer pour avoir un effet.        *
***********************************************************************/

void MouHideMouse( void )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax = 0x0002;                     /* Nø fct. pour "Hide Mouse" */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
}

/***********************************************************************
*  Fonction         : M o u S e t M o v e A r e a                      *
**--------------------------------------------------------------------**
*  Fonction         : D‚finit la zone de l'‚cran … l'int‚rieur de      *
*                     laquelle le curseur de la souris peut se d‚placer*
*  Params en entr‚e : x1, y1 = coordonn‚es du coin sup‚rieur gauche    *
*                     x2, y2 = coordonn‚es du coin inf‚rieur droit     *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Les deux paramŠtres se r‚fŠrent … l'‚cran de   *
*                       texte et non … l'‚cran graphique virtuel de    *
*                       la souris                                      *
***********************************************************************/

void MouSetMoveArea( BYTE x1, BYTE y1, BYTE x2, BYTE y2 )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax = 0x0008;            /* Nø fct. pour "Set vertical Limits" */
 regs.x.cx = ROWTOY( y1 );                 /* Conversion vers l'‚cran */
 regs.x.dx = ROWTOY( y2 );                    /* virtuel de la souris */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
 regs.x.ax = 0x0007;          /* Nø fct. pour "Set horizontal limits" */
 regs.x.cx = COLTOX( x1 );                 /* Conversion vers l'‚cran */
 regs.x.dx = COLTOX( x2 );                    /* virtuel de la souris */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
}

/***********************************************************************
*  Fonction         : M o u S e t S p e e d                            *
**--------------------------------------------------------------------**
*  Fonction         : Fixe le rapport entre la longueur d'un d‚place-  *
*                     ment de la souris et le d‚placement du curseur   *
*                     de la souris qui doit en r‚sulter.               *
*  Params en entr‚e : - XSPEED = vitesse horizontalement               *
*                     - YSPEED = vitesse verticalement                 *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Les deux paramŠtres sont exprim‚s en unit‚s de *
*                       mickey / 8 points ‚cran.                       *
***********************************************************************/

void MouSetSpeed( int xspeed, int yspeed )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 regs.x.ax = 0x000f;          /* Nø fct. "Set mickeys to pixel ratio" */
 regs.x.cx = xspeed;
 regs.x.dx = yspeed;
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
}

/***********************************************************************
*  Fonction         : M o u M o v e P t r                              *
**--------------------------------------------------------------------**
*  Fonction         : AmŠne le curseur de la souris dans une position  *
*                     d‚termin‚e de l'‚cran.                           *
*  Params en entr‚e : - COL = nouvelle colonne de l'‚cran              *
*                     - ROW = nouvelle ligne de l'‚cran                *
*  Valeur Return    : Aucune                                           *
*  Infos            : - Les deux paramŠtres se r‚fŠrent … l'‚cran de   *
*                       texte et non … l'‚cran graphique virtuel de    *
*                       la souris                                      *
***********************************************************************/

void MouMovePtr( int col, int row )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */
 unsigned nouzon;          /* Zone dans laquelle la souris est amen‚e */

 regs.x.ax = 0x0004;          /* Nø fct. "Set mouse pointer position" */
 regs.x.cx = COLTOX( moucol = col );  /* Convertir coordonn‚es et les */
 regs.x.dx = ROWTOY( mourow = row );/* stocker dans variables globales*/
 MOUINT(regs, regs);                /* Appeler le driver de la souris */

 nouzon = *(bufz + mourow * tcol + moucol);           /* Retirer zone */
 if ( nouzon != mouzon )                           /* Nouvelle zone ? */
  MouDefinePtr((nouzon==AUCUNE_ZONE) ? stdptr :
                                        (zone_act+nouzon)->ptr_mask);
 mouzon = nouzon;              /* Ranger nø de zone dans var. globale */
}

/***********************************************************************
*  Fonction         : M o u S e t D e f a u l t P t r                  *
**--------------------------------------------------------------------**
*  Fonction         : D‚finit l'apparence du curseur de la souris pour *
*                     les zones de l'‚cran qui n'ont pas ‚t‚ d‚finies  *
*                     avec MouDefZone.                                 *
*  Params en entr‚e : STANDARD = Masque bits pour curseur souris stand.*
*  Valeur Return    : Aucune                                           *
***********************************************************************/

void MouSetDefaultPtr( PTRVIEW standard )
{
 stdptr = standard;       /* Ranger masque bits dans variable globale */

 /*-- Si la souris ne figure actuellement dans aucune zone, la     ---*/
 /*-- nouvelle apparence du curseur est directement activ‚e        ---*/

 if ( MouGetZone() == AUCUNE_ZONE )             /* Dans aucune zone ? */
  MouDefinePtr( standard );                                    /* Non */
}

/***********************************************************************
*  Fonction         : M o u E n d                                      *
**--------------------------------------------------------------------**
*  Fonction         : Met fin au travail avec les fonctions du module  *
*                     Mousec.                                          *
*  Params en entr‚e : Aucun                                            *
*  Valeur Return    : Aucune                                           *
*  Infos            : Cette fonction est appel‚e automatiquement … la  *
*                     fin d'un programme, … condition que MouInstall   *
*                     ait ‚t‚ appel‚ auparavant.                       *
***********************************************************************/

void MouEnd( void )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 MouHideMouse();          /* Eliminer curseur de la souris de l'‚cran */
 regs.x.ax = 0;            /* R‚initialisation du driver de la souris */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */

 free( bufz );                   /* Lib‚rer … nouveau m‚moire allou‚e */
}

/***********************************************************************
*  Fonction         : M o u I n i t                                    *
**--------------------------------------------------------------------**
*  Fonction         : Dirige le travail avec le module Mousec et       *
*                     initialise les diff‚rentes variables             *
*  Params en entr‚e : Colonnes, = la r‚solution de l'‚cran de texte    *
*                     Lignes                                           *
*  Valeur Return    : TRUE si une souris est install‚e, sinon FALSE    *
*  Infos            : Cette fonction doit ˆtre la premiŠre fonction de *
*                     ce module … ˆtre appel‚e.                        *
***********************************************************************/

BYTE MouInit( BYTE colonnes, BYTE lignes )
{
 union REGS regs;/* Registres du processeur pour l'appel d'interrupt. */

 tline = lignes;                    /* Stocker nombre de lignes et de */
 tcol  = colonnes;            /* colonnes dans des variables globales */

 atexit( MouEnd );            /* Appeler MouEnd … la fin du programme */

 /*-- Allouer et remplir buffer pour zones souris --------------------*/

 bufz = (BYTE *) malloc( blen = tline * tcol );
 MouIBufFill( 0, 0, tcol-1, tline-1, AUCUNE_ZONE );

 regs.x.ax = 0;                    /* Initialiser driver de la souris */
 MOUINT(regs, regs);                /* Appeler le driver de la souris */
 if ( regs.x.ax != 0xffff )         /* Driver de la souris install‚ ? */
  return FALSE;                                                /* Non */

 MouSetMoveAreaAll();                    /* Fixer zone de d‚placement */

 moucol = MouIGetX();                    /* Charger position actuelle */
 mourow = MouIGetY();     /* de la souris dans des variables globales */

 /*-- Installer gestionnaire d'‚v‚nements assembleur "AssHand" -------*/
 MouISetEventHandler( EV_MOU_ALL, (MOUHAPTR) AssHand );

 return mavail = TRUE;                     /* La souris est install‚e */
}

/***********************************************************************
*                   P R O G R A M M E   P R I N C I P A L              *
***********************************************************************/

int main( void )
{
 static ZONE zones[] =          /* Les diff‚rentes zones de la souris */
  {
   {  0,  0, 79,  0, MouPtrMask( PTRDIFCHAR(0x18), PTRINVCOL)  },
   {  0,  1,  0, 23, MouPtrMask( PTRDIFCHAR(0x1b), PTRINVCOL)  },
   {  0, 24, 78, 24, MouPtrMask( PTRDIFCHAR(0x19), PTRINVCOL)  },
   { 79,  1, 79, 23, MouPtrMask( PTRDIFCHAR(0x1a), PTRINVCOL)  },
   { 79, 24, 79, 24, MouPtrMask( PTRDIFCHAR('X'),  PTRDIFCOLC(0x40) ) },
  };

 printf("\nSOURIS - (c) 1989 by MICHAEL TISCHER\n\n");
 if ( MouInit( 80, 25 ) )          /* Initialiser module de la souris */
  {              /* Tout va bien, un driver de la souris est install‚ */
   printf("Si vous d‚placez le curseur de la souris sur l'‚cran,\n"\
          "et notamment le long des bords de l'‚cran, vous\n"\
          "constatez que l'apparence du curseur de la souris se\n"\
          "modifie en fonction de sa position.\n\n"
          "Pour mettre fin … cette d‚mo, amenez le curseur de la\n"\
          "souris dans le coin inf‚rieur droit de l'‚cran puis\n"\
          "appuyez alors … la fois sur les boutons gauche et\n"\
          "droit de la souris.\n" );

   MouSetDefaultPtr( MouPtrMask( PTRDIFCHAR( 'Û' ), PTRDIFCOL( 3 ) ) );
   MouDefZone( ELVEC( zones ), zones );                 /* D‚f. zones */
   MouShowMouse();       /* Afficher curseur de la souris sur l'‚cran */

   /*-- Attendre que les boutons gauche et droit de la souris       --*/
   /*-- soient appuy‚s simultan‚ment et que le curseur de la souris --*/
   /*-- figure … ce moment dans la zone 4                           --*/

   do                                               /* Boucle de test */
    MouEventWait( ET, EV_LEFT_PRESS | EV_RIGHT_PRESS );
   while ( MouGetZone() != 4 );

   return 0;                               /* Renvoyer code OK au DOS */
  }
 else               /* Pas de souris ou pas de driver souris install‚ */
  {
   printf("Aucun driver de la souris n'est install‚ !\n");
   return 1;                         /* Renvoyer code d'erreur au DOS */
  }
}
