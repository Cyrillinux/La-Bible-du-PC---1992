/***********************************************************************
*                               T S R C                                *
**--------------------------------------------------------------------**
*    Fonction       : Programme ‚crit en C transformable en programme  *
*                     r‚sident grƒce … un module en assembleur         *
**--------------------------------------------------------------------**
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 15.08.1988                                       *
*    DerniŠre MAJ   : 19.03.1992                                       *
**--------------------------------------------------------------------**
*    ModŠle m‚moire : SMALL                                            *
***********************************************************************/

/*== Fichiers d'en-tˆte ==============================================*/

#include <stdlib.h>
#include <stdio.h>
#include <dos.h>
#include <conio.h>
#include <string.h>
#include <bios.h>

/*== Typedef  ========================================================*/

typedef unsigned char BYTE;               /* Bricolage d'un type BYTE */
typedef unsigned int  WORD;
typedef BYTE          BOOL;                /* Comme BOOLEAN en Pascal */
typedef union vel far *VP;          /* VP : ptr FAR sur m‚moire ‚cran */

typedef void (*SAFP)(void);    /* Pointeur sur fonction sans argument */
typedef void (*SHKFP)( WORD KeyMask, BYTE ScCode );   /* TsrSetHotkey */

/*== Macros ==========================================================*/

#ifndef MK_FP                           /* MK_FP pas encore d‚fini  ? */
 #define MK_FP(s, o) ((void far *) (((unsigned long) (s)<<16)|(o)))
#endif
#define VOFS(x,y) ( 80 * ( y ) + ( x ) )
#define VPOS(x,y) (VP) ( vptr + VOFS( x, y ) )

/*== Structures et unions ===========================================*/

struct velb
       {                   /* D‚crit une position d'‚cran en 2 octets */
         BYTE caractere,                                /* Code ASCII */
              attribut;                        /* et attribut associ‚ */
       };

struct velw
       {                      /* D‚crit une position d'‚cran en 1 mot */
         WORD contenu;        /* M‚morise le code ASCII et l'attribut */
       };

union vel
      {                                 /* D‚crit un position d'‚cran */
        struct velb h;
        struct velw x;
      };

/*== IntŠgre les fonctions du module en assembleur ===================*/

extern void TsrInit( BOOL tc, void (*fct)(void), unsigned heap );
extern BOOL TsrIsInst( BYTE i2F_fctnr );
extern void TsrUnInst( void );
extern SAFP TsrSetPtr( void far *fct );
extern BOOL TsrCanUnInst( void );
extern void TsrCall( void );
extern void far TsrSetHotkey( WORD keymask, BYTE sccode );

/*== Constantes et macros ============================================*/

#ifdef __TURBOC__                        /* Compilation par TURBO-C ? */
  #include <alloc.h>
  #define TC TRUE                                              /* Oui */
  #define KeyAvail() ( bioskey(1) != 0 )
  #define GetKey() bioskey(0)
#else                            /* Non on travaille avec Microsoft C */
  #include <malloc.h>
  #define TC FALSE
  #define KeyAvail() ( _bios_keybrd( _KEYBRD_READY ) != 0 )
  #define GetKey() _bios_keybrd( _KEYBRD_READ )
#endif

/*-- Scan codes de diff‚rentes touches -------------------------------*/

#define SC_ESC             0x01
#define SC_1               0x02
#define SC_2               0x03
#define SC_3               0x04
#define SC_4               0x05
#define SC_5               0x06
#define SC_6               0x07
#define SC_7               0x08
#define SC_8               0x09
#define SC_9               0x0A
#define SC_0               0x0B
#define SC_SCHARFES_S      0x0C
#define SC_APOSTROPH       0x0D
#define SC_BACKSPACE       0x0E
#define SC_TAB             0x0F
#define SC_Q               0x10
#define SC_W               0x11
#define SC_E               0x12
#define SC_R               0x13
#define SC_T               0x14
#define SC_Z               0x15
#define SC_U               0x16
#define SC_I               0x17
#define SC_O               0x18
#define SC_P               0x19
#define SC_UE              0x1A
#define SC_PLUS            0x1B
#define SC_RETURN          0x1C
#define SC_CONTROL         0x1D
#define SC_A               0x1E
#define SC_S               0x1F
#define SC_D               0x20
#define SC_F               0x21
#define SC_G               0x22
#define SC_H               0x23
#define SC_J               0x24
#define SC_K               0x25
#define SC_L               0x26
#define SC_OE              0x27
#define SC_AE              0x28
#define SC_PLUSGRAND       0x29
#define SC_SHIFT_GAUCHE    0x2A
#define SC_FIS             0x2B
#define SC_Y               0x2C
#define SC_X               0x2D
#define SC_C               0x2E
#define SC_V               0x2F
#define SC_B               0x30
#define SC_N               0x31
#define SC_M               0x32
#define SC_VIRGULE         0x33
#define SC_POINT           0x34
#define SC_TIRET           0x35
#define SC_SHIFT_DROIT     0x36
#define SC_PRINT_SCREEN    0x37
#define SC_ALT             0x38
#define SC_SPACE           0x39
#define SC_CAPS            0x3A
#define SC_F1              0x3B
#define SC_F2              0x3C
#define SC_F3              0x3D
#define SC_F4              0x3E
#define SC_F5              0x3F
#define SC_F6              0x40
#define SC_F7              0x41
#define SC_F8              0x42
#define SC_F9              0x43
#define SC_F10             0x44
#define SC_NUM_LOCK        0x45
#define SC_SCROLL_LOCK     0x46
#define SC_CURSOR_HOME     0x47
#define SC_CURSOR_UP       0x48
#define SC_CURSOR_PG_UP    0x49
#define SC_NUM_MOINS       0x4A
#define SC_CURSOR_LEFT     0x4B
#define SC_NUM_5           0x4C
#define SC_CURSOR_RIGHT    0x4D
#define SC_NUM_PLUS        0x4E
#define SC_CURSOR_END      0x4F
#define SC_CURSOR_DOWN     0x50
#define SC_CURSOR_PG_DOWN  0x51
#define SC_INSERT          0x52
#define SC_DELETE          0x53
#define SC_SYS_REQUEST     0x54
#define SC_F11             0x57
#define SC_F12             0x58
#define SC_NOKEY           0x80        /* Pas de touche additionnelle */

/*-- touches de commande pour cr‚ation masque de touche d'activation -*/

#define RSHIFT       1            /* Touche Majuscule Droite enfonc‚e */
#define LSHIFT       2            /* Touche Majuscule gauche enfonc‚e */
#define CTRL         4                        /* Touche CTRL enfonc‚e */
#define ALT          8                         /* Touche ALT enfonc‚e */
#define SYSREQ    1024            /* Touche SYS-REQ (sur clavier AT ) */
#define BREAK     4096                       /* Touche Break enfonc‚e */
#define NUM       8192                    /* Touche Num-Lock enfonc‚e */
#define CAPS     16384                   /* Touche Caps-Lock enfonc‚e */
#define INSERT   32768                      /* Touche INSERT enfonc‚e */

#define I2F_CODE   0xC4                     /* Fonction num‚ro INT 2F */
#define I2F_FKT_0  0xAA               /* Code pour INT 2F, fonction 0 */
#define I2F_FKT_1  0xBB                /* Code fr INT 2F, fonction 1 */

#define COULN      0x07                            /* Couleur normale */
#define INV        0x70                            /* Couleur inverse */
#define COULNC     0x0f                     /* Couleur normale claire */
#define INVC       0xf0                     /* Couleur inverse claire */

#define TAS_LIBRE  1024                     /* Laisse 1 Ko sur le tas */

#define TRUE  ( 0 == 0 )      /* Constantes pour travailler avec BOOL */
#define FALSE ( 0 == 1 )

/*== Variables globales ==============================================*/

VP         vptr;            /* Ptr sur 1er caractŠre en m‚moire ‚cran */
unsigned   atimes = 0;  /* Nombre d'activations du programme r‚sident */
union vel  *scrbuf;                    /* Pointeur sur buffer d'‚cran */
char       *lignevide;                     /* Pointeur sur ligne vide */

/***********************************************************************
*  Fonction         : D I S P _ I N I T                                *
**--------------------------------------------------------------------**
*            Donne l'adresse de base de la m‚moire d'‚cran.            *
*  Entr‚es           : n‚ant                                           *
*  Valeur retourn‚e  : n‚ant                                           *
***********************************************************************/

void disp_init(void)
{
  union REGS regs;          /* Registres pour g‚rer les interruptions */

  regs.h.ah = 15;                 /* fonction "D‚terminer mode vid‚o" */
  int86(0x10, &regs, &regs);            /* interruption vid‚o du BIOS */

/*-- Calcule adresse de base de m‚m. ‚cran en fonction du mode vid‚o -*/

  vptr = (VP) MK_FP((regs.h.al == 7) ? 0xb000 : 0xb800, 0);
}

/***********************************************************************
*  Fonction         : D I S P _ P R I N T                              *
**--------------------------------------------------------------------**
*      Affiche une chaŒne de caractŠres sur l'‚cran.                   *
*  Entr‚es: - COLONNE = Colonne d'affichage.                           *
*           - LIGNE   = Ligne d'affichage.                             *
*           - COULEUR = Attribut des caractŠres.                       *
*           - STRING  = Pointeur sur chaŒne                            *
*  Valeur retourn‚e : n‚ant                                            *
***********************************************************************/

void disp_print(BYTE colonne, BYTE ligne, BYTE couleur, char * string)
{
  register VP lptr;               /* Ptr pour acc‚der … m‚moire ‚cran */

  lptr = VPOS(colonne, ligne);                   /* ptr m‚moire ‚cran */
  for( ; *string ; ++lptr)                      /* Parcourt la chaŒne */
  {
    lptr->h.caractere = *(string++);    /* caractŠre en m‚moire ‚cran */
    lptr->h.attribut = couleur;             /* ainsi que son attribut */
  }
}

/***********************************************************************
*  Fonction         : S A V E _ S C R E N                              *
**--------------------------------------------------------------------**
*        Sauvegarde le contenu de l'‚cran dans un buffer               *
*  Entr‚es: - SPTR = Pointeur sur le buffer dans lequel                *
*                    l'‚cran va ˆtre sauvegard‚                        *
*  Valeur retourn‚e : n‚ant                                            *
*  Info             : On suppose que le buffer est assez grand         *
*                     pour m‚moriser le contenu de l'‚cran.            *
***********************************************************************/

void save_screen( union vel * sptr )
{
  register VP lptr;        /* Pointeur courant sur la m‚moire d'‚cran */
  unsigned    i;                                          /* Compteur */
  lptr = VPOS(0, 0);                        /* Positionne le pointeur */

  for(i=0; i<2000; i++)      /* Parcourt les 2000 coordonn‚es d'‚cran */
    (sptr++)->x.contenu = (lptr++)->x.contenu;  /* M‚m. car. et attr. */
}

/***********************************************************************
*  Fonction         : R E S T O R E _ S C R E E N                      *
**--------------------------------------------------------------------**
*      Copie le contenu d'un buffer dans la m‚moire d'‚cran            *
*  Entr‚e : - SPTR = Pointeur sur le buffer o— se trouve le contenu de *
*                    l'‚cran.                                          *
*  Valeur retourn‚e : n‚ant                                            *
***********************************************************************/

void restore_screen( union vel * sptr )
{
  register VP lptr;     /* Pointeur pour acc‚der … la m‚moire d'‚cran */
  unsigned i;                                             /* Compteur */
  lptr = VPOS(0, 0);                        /* Positionne le pointeur */

  for(i=0; i<2000; i++)   /* Parcourt les 2000 coordonn‚es d'un ‚cran */
    (lptr++)->x.contenu = (sptr++)->x.contenu;      /* Lit car.+attr. */
}

/***********************************************************************
*  Fonction         : E N D F C T                                      *
**--------------------------------------------------------------------**
*      Appel‚e lors de la d‚sinstallation du programme r‚sident        *
*  Entr‚e           : n‚ant                                            *
*  Valeur retourn‚e : n‚ant                                            *
*  Info             : Cette proc‚dure doit ˆtre FAR pour pouvoir ˆtre  *
*                     invoqu‚e … partir de l'exemplaire d‚j… install‚  *
*                     du programme r‚sident.                           *
***********************************************************************/

void far endfct( void )
{             /*-- LibŠre les buffers allou‚s ------------------------*/

 free( lignevide );
 free( (void *) scrbuf );

 printf("Le programme r‚sident a ‚t‚ activ‚  %u fois.\n", atimes);
}

/***********************************************************************
*  Fonction         : T S R                                            *
**--------------------------------------------------------------------**
*      Appel‚e par le module en assembleur au moment o— la touche      *
*               d'activation est actionn‚e.                            *
*  Entr‚es          : n‚ant                                            *
*  Valeur retourn‚e : n‚ant                                            *
***********************************************************************/

void tsr( void )
{
  BYTE   i;                                               /* Compteur */

 ++atimes;                      /* Incr‚mente le nombre d'activations */

 while( KeyAvail() )                     /* Vide le buffer du clavier */
   GetKey();

 disp_init();              /* Cherche l'adresse de la m‚moire d'‚cran */
 save_screen( scrbuf );     /* M‚morise le contenu courant de l'‚cran */
 for(i=0; i<25; i++)             /* Parcourt les 25 lignes de l'‚cran */
   disp_print(0, i, INV, lignevide);           /* Efface chaque ligne */
 disp_print(22, 11, INV, "TSRC  -  (c) 1988, 92 by MICHAEL TISCHER");
 disp_print(28, 13, INV, "Appuyez sur une touche SVP ...");
 GetKey();                             /* Attend une frappe de touche */

 restore_screen( scrbuf );                 /* Restaure l'ancien ‚cran */
}

/***********************************************************************
* GetHeapEnd: d‚termine la fin actuelle du tas en fonction             *
*             du compilateur                                           *
* Entr‚e : n‚ant                                                       *
* Sortie : Ptr sur le premier octet situ‚ aprŠs la partie occup‚e      *
*           du tas                                                     *
***********************************************************************/

void far *GetHeapEnd( void )
{
 #ifdef __TURBOC__                                        /* TurboC ? */
   return (void far *) sbrk(0);
 #else                                                    /* Non  MSC */
   struct _heapinfo  hi;       /* Stuct. avec informations sur le tas */
   unsigned          heapstatus;               /* Etat de _heapwalk() */
   void far          *dernier; /* Pointeur sur le dernier bloc occup‚ */

   hi._pentry = NULL;                     /* Commence au d‚but du tas */

      /*-- Parcourt le tas jusqu'au dernier bloc ---------------------*/

   while( (heapstatus = _heapwalk( &hi )) != _HEAPEND )
     if( hi._useflag == _USEDENTRY )                 /* Bloc occup‚ ? */
       dernier = (void far *) ((BYTE far *) hi._pentry + hi._size + 1);

   return dernier;
 #endif
}

/***********************************************************************
* ParamGetHotKey: Recherche dans les param. de la ligne de commande    *
*   la d‚finition de la touche d'activation (/T) et l'exploite         *
* Entr‚es : ARGC,   = ParamŠtres de la ligne de commande, comme pour   *
*                     main()                                           *
*           ARGV                                                       *
*           KEYMASK = Pointeur sur la variable destin‚e … m‚moriser    *
*                     le masque de la touche                           *
*           SCCODE  = Pointeur sur la variable qui doit m‚moriser      *
*                     le scan code                                     *
* Sortie : TRUE, si la touche d'activation est identifi‚e, sinon FALSE *
* Info   : - Les paramŠtres qui ne sont pas introduits par /T          *
*            ne sont pas exploit‚s : ils sont laiss‚s … la disposition *
*            d'autres fonctions                                        *
*          - Si aucun paramŠtre /T n'est d‚tect‚, les variables        *
*            contiennent respectivement les valeurs 0 et SC_NOKEY.     *
***********************************************************************/

BOOL ParamGetHotKey(int argc, char *argv[], WORD *KeyMask, BYTE *ScCode)
{
  struct TComman
         {
           char  Nom[7];
           WORD  Valeur;
         };

 static struct TComman ToucheC[9] =
               {
                 { "LSHIFT", LSHIFT },
                 { "RSHIFT" ,RSHIFT },
                 { "CTRL"   ,CTRL   },
                 { "ALT"    ,ALT    },
                 { "SYSREQ" ,SYSREQ },
                 { "BREAK"  ,BREAK  },
                 { "NUM"    ,NUM    },
                 { "CAPS"   ,CAPS   },
                 { "INSERT" ,INSERT }
               };

 int i , j,                                    /* Compteurs de boucle */
     code;                             /* Pour convertir le scan code */
     char arg[80];                      /* Pour m‚moriser un argument */

 *KeyMask = 0;
 *ScCode = SC_NOKEY;

 for( i = 1; i < argc; ++i )         /* Parcourt la ligne de commande */
 {
   strcpy( arg, argv[i] );                         /* Lit un argument */
   strupr( arg );
   if( arg[0] == '/'  &&  arg[1] == 'T' )
   {                                       /* Est-ce un argument /T ? */
     code = atoi( &arg[2] );         /* Transforme le code en binaire */
     if( code )                               /* Conversion r‚ussie ? */
     {                                                         /* Oui */
       if( code < 128 )                              /* Code valide ? */
         *ScCode = code;                          /* Oui, le m‚morise */
       else
         return FALSE;                            /* Code non valable */
     }
     else                       /* Pas de nombre : touche de commande */
     {
       for( j = 0; j < 9; ++ j )   /* Parcourt le tableau des touches */
         if(!strcmp( ToucheC[j].Nom, &arg[2] ))        /* comparaison */
           break;                    /* Egalit‚, on sort de la boucle */

       if( j < 9 )                       /* Nom de la touche trouv‚ ? */
         *KeyMask = *KeyMask | ToucheC[j].Valeur;  /* Oui, indicateur */
       else
         return FALSE;        /* Non, ni nombre ni touche de commande */
     }
   }
 }
 return TRUE;                     /* Si la fonction arrive jusqu'ici, */
}                               /* c'est que les paramŠtres sont bons */

/***********************************************************************
**                           PROGRAMME PRINCIPAL                      **
***********************************************************************/

void main( int argc, char *argv[] )
{
 WORD  KeyMask;               /* masque bin. pour touches de commande */
 BYTE  ScCode;     /* M‚morise le scan code de la touche d'activation */

 printf("TSRC  -  (c) 1988, 92 by MICHAEL TISCHER\n");
 if(!ParamGetHotKey( argc, argv, &KeyMask, &ScCode ))
 {             /* Erreur dans les paramŠteres de la ligne de commande */
   printf( "ParamŠtre erron‚ dans la ligne de commande \n" );
   exit(1);
 }

 /*-- Les paramŠtres de la ligne de commande sont en ordre------------*/

 if( !TsrIsInst( I2F_CODE ))             /* Programme d‚j… install‚ ? */
 {                                                             /* Non */
   atimes = 0;              /* Le programme n'a pas encore ‚t‚ activ‚ */
   printf( "Le programme r‚sident a ‚t‚ install‚.\n" );
   if( KeyMask == 0  &&  ScCode == SC_NOKEY )  /* pas de paramŠtres ? */
   {                                   /* Non, valeur implicite ALT-H */
     TsrSetHotkey( ALT, SC_H );
     printf( "Activation: <ALT> + H\n" );
   }
   else                            /* touche d'activation utilisateur */
     TsrSetHotkey( KeyMask, ScCode );

    /*-- Alloue un buffer pour la gestion de l'‚cran -----------------*/

   scrbuf = (union vel *) malloc(80 * 25 * sizeof(union vel));
   lignevide = (char *) malloc( 80 + 1 );      /* R‚servation m‚moire */
   *(lignevide + 80 ) = '\0';            /* Cl“ture le buffer par NUL */
   memset(lignevide, ' ', 80);             /* et le remplit d'espaces */

   TsrInit( TC, tsr, TAS_LIBRE );            /* Installe le programme */
 }
 else                                      /* Programme d‚j… install‚ */
 {                                                              /* OUI*/
   if( KeyMask == 0  &&  ScCode == SC_NOKEY )  /* Pas de paramŠtres ? */
   {                                 /* Non tente une d‚sinstallation */
     if( TsrCanUnInst() )
     {
       (*(SAFP) TsrSetPtr(endfct))();
       TsrUnInst();
       printf( "Le programme a pu ˆtre d‚sinstall‚ .\n" );
     }
     else
       printf( "Le programme ne peut pas ˆtre d‚sinstall‚.\n" );
   }
   else                       /* Fixe la nouvelle touche d'activation */
   {
     printf( "Nouvelle touche d'activation install‚e \n" );
     (*(SHKFP) TsrSetPtr(TsrSetHotkey))( KeyMask, ScCode );
   }
 }
}
