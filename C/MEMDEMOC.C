/***********************************************************************
*                         M E M D E M O C . C                          *
**--------------------------------------------------------------------**
*    Fonction       : Montre comment DOS gŠre la m‚moire               *
**--------------------------------------------------------------------**
*    ModŠle m‚moire : SMALL                                            *
**--------------------------------------------------------------------**
*    Auteur         : Michael TISCHER                                  *
*    D‚velopp‚ le   : 08.10.1991                                       *
*    DerniŠre MAJ   : 20.03.1992                                       *
***********************************************************************/

/*== Fichiers d'inclusion  ===========================================*/

#include <dos.h>
#include <conio.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

/*== Constantes ======================================================*/

#define TRUE  ( 0 == 0 )
#define FALSE ( 0 == 1 )

/*-- Num‚ros des fonctions de l'interruption 0x21 --------------------*/

#define GET_MEM      0x48               /* R‚serve de la m‚moire vice */
#define FREE_MEM     0x49                /* LibŠre de la m‚moire vive */
#define CHANGE_MEM   0x4A   /* Change la taille d'une zone de m‚moire */
#define GET_STRATEGY 0x5800          /* Lit la strat‚gie d'allocation */
#define SET_STRATEGY 0x5801         /* Fixe la strat‚gie d'allocation */
#define GET_UMB      0x5802   /* Lit l'‚tat d'inclusion des blocs UMB */
#define SET_UMB      0x5803         /* Fixe l'inclusion des blocs UMB */

/*-- Strat‚gies de recherche pour FixeStrategie ----------------------*/

#define CHERCHE_ENBAS    0x00            /* 1er bloc de m‚moire libre */
#define CHERCHE_MEILLEUR 0x01             /* Meilleur bloc de m‚moire */
#define CHERCHE_OBEN     0x02       /* Dernier bloc de m‚moire lib‚r‚ */
#define DABORD_UMB       0x80        /* Chercher dans la zone des UMB */
                                      /* (… utiliser avec CHERCHE_ ); */

/*-- Constantes pour FixeUMB------------------------------------------*/

#define UMB_NON      0x00             /* Ignore la m‚moire sup‚rieure */
#define UMB_OUI      0x01                     /* Alloue des blocs UMB */

/*-- Constantes pour Demo --------------------------------------------*/

#define TEST_TA        (10240-1)        /* 10239 paragraphes pour test*/
#define TEST_TA_UMB    (2560-1)     /* 2559 paragraphes UMB pour test */
#define TEST_TA_KB     160                 /* Envir. de test = 160 Ko */
#define TEST_TA_UMB_KB 40               /* Envir. de test UMB = 40 Ko */
#define NBREBLOC       26    /* Nbr d'adr. pour affichage du r‚sultat */

/*-- Codes de touches pour saisie utilisateur ------------------------*/

#define ESC  27                               /* Interruption par ESC */
#define F1   59                              /* Touche de fonction F1 */
#define F2   60                              /* Touche de fonction F2 */
#define F3   61                              /* Touche de fonction F3 */
#define F8   66                              /* Touche de fonction F8 */
#define F9   67                              /* Touche de fonction F9 */
#define F10  68                             /* Touche de fonction F10 */

/*== D‚clarations de types ===========================================*/

typedef struct
        {
          unsigned int Adresse,                            /* Segment */
                       Taille;                   /* Taille en m‚moire */
           } BlocTyp;

typedef unsigned char BYTE;

/*== Macros ==========================================================*/

#ifdef MK_FP                            /* Macro MK_FP d‚j… d‚finie ? */
  #undef MK_FP                              /* Oui, alors on l'efface */
#endif

#define MK_FP(s,o) ((void far *)(((unsigned long) (s)<<16)|(o)))

/*== Constantes typ‚es ===============================================*/

char *OuiNon[]   =
            { "Non ", "Oui " };
char *SText[]    =
            {
              "Utilise le premier bloc de m‚moire libre ",
              "Utilise le meilleur bloc de m‚moire libre",
              "Utilise le dernier bloc de m‚moire libre "};
BYTE ChampCouleur[] =
            { 0x07, 0x70 };
char *TexteTouche[] =
            {
              "  [F1] Allouer de la m‚moire",
              "  [F2] Lib‚rer de la m‚moire",
              "  [F3] Modifier la taille",
              " [ESC] Fin du programme"};

/*== Variables globales ==============================================*/

union REGS   regs;          /* Registres pour g‚rer les interruptions */
struct SREGS sregs;        /* Registres de segment pour int. ‚tendues */
unsigned int ChampAdresse[ 1000 ];               /* Champs de m‚moire */
unsigned int NbAdresse;                          /* Nombre d'adresses */
unsigned int SegConv;              /* Adr. bloc test en m‚moire conv. */
unsigned int UMBSeg;                /* Adr. bloc test en m‚moire sup. */
BlocTyp      BlocChamp[ NBREBLOC ];                        /* M‚moire */

/*== Routines d'‚cran pour  Microsoft C ==============================*/

#ifndef __TURBOC__                                    /* Microsoft C? */

  #define textcolor( Couleur )
  #define textbackground( Couleur )

  /*********************************************************************
  * Gotoxy        : Positionne le curseur                              *
  * Entr‚es       : Coordonn‚es du curseur                             *
  * Sortie        : n‚ant                                              *
  *********************************************************************/

  void gotoxy( int x, int y )
  {
   regs.h.ah = 0x02;           /* Num‚ro de la fonction d'interruption*/
   regs.h.bh = 0;                                          /* Couleur */
   regs.h.dh = y - 1;
   regs.h.dl = x - 1;
   int86( 0x10, &regs, &regs );           /* D‚clenche l'interruption */
  }

  /*********************************************************************
  * clrscr        : Efface l'‚cran                                     *
  * Entr‚es       : cf infra                                           *
  * Sortie        : n‚ant                                              *
  *********************************************************************/

  void clrscr( void )
  {
   regs.h.ah = 0x07;           /* Num‚ro de la fonction d'interruption*/
   regs.h.al = 0x00;
   regs.h.ch = 0;
   regs.h.cl = 0;
   regs.h.dh = 24;
   regs.h.dl = 79;
   int86( 0x10, &regs, &regs );           /* D‚clenche l'interruption */
   gotoxy( 1, 1 );                           /* Positionne le curseur */
  }

#endif

/***********************************************************************
* PRINT : Comme RINTF, mais ‚crit directement la chaŒne dans la        *
*         m‚moire d'‚cran                                              *
* Entr‚es : COLONNE = Colonne d'affichage                              *
*           LIGNE   = Ligne d'affichage                                *
*           COULEUR = Couleur d'affichage                              *
*           STRING  = Pointeur sur la chaŒne PRINTF                    *
*           ...     = autres arguments                                 *
* Sortie : n‚ant                                                       *
***********************************************************************/

void Print( int Colonne, int Ligne, BYTE Couleur, char * String, ...)
{
 struct vr {                     /* Une position … l'‚cran = 2 octets */
        BYTE caractere,                                 /* Code ASCII */
             attribut;                             /* Attribu associ‚ */
       } far *lptr;        /* Pointeur courant sur la m‚moire d'‚cran */
 va_list     parameter;     /* Liste de paramŠtres pour macros VA_... */
 char        affichage[255],       /* Buffer pour chaŒne de formatage */
             *aptr = affichage;       /* Pour parcourir ladite chaŒne */
 static unsigned int vioseg = 0;
 union REGS   Register;     /* Registres pour g‚rer les interruptions */

 if( vioseg == 0 )                                 /* Premier appel  ?*/
 {                   /* Oui, cherche le segment de la m‚moire d'‚cran */
   Register.h.ah = 0x0F;
   int86(0x10, &Register, &Register);
   vioseg = ( Register.h.al == 7 ? 0xb000 : 0xb800 );
 }

 va_start( parameter, String );           /* Convertit les paramŠtres */
 vsprintf( affichage, String, parameter );                 /* Formate */
 lptr = (struct vr far *)
          MK_FP( vioseg, ( (Ligne-1) * 80 + (Colonne-1) ) << 1 );

 for( ; *aptr ; )                               /* Parcourt la chaŒne */
 {
   lptr->caractere = *aptr++;         /* CaractŠre en m‚moire d'‚cran */
   lptr++->attribut = Couleur;        /* Fixe l'attribut du caractŠre */
   ++Colonne;
 }
 gotoxy( Colonne, Ligne );                      /* D‚place le curseur */
}

/***********************************************************************
* DOS_GetMem : R‚serve de la m‚moire                                   *
* Entr‚e     : Taille m‚moire souhait‚e en paragraphes                 *
* Sortie     : Segment du bloc de m‚moire allou‚,                      *
*              Nombre de paragraphes allou‚s ou nombre maximum         *
*              de paragraphes disponibles                              *
***********************************************************************/

void DOS_GetMem( unsigned int Ta,
                 unsigned int *Adr,
                 unsigned int *Res )
{
 regs.h.ah = GET_MEM;                        /* Num‚ro de la fonction */
 regs.x.bx = Ta;                  /* Nombre de paragraphes … r‚server */
 intdos( &regs, &regs );                       /* Interruption de DOS */

 if( !regs.x.cflag )                                /* Appel r‚ussi ? */
 {
   *Adr = regs.x.ax;          /* Oui, restitue l'adresse et la taille */
   *Res = Ta;
 }
 else                                                   /* Non, erreur*/
 {
   *Adr = 0;                               /* Pas de m‚moire r‚serv‚e */
   *Res = regs.x.bx;                    /* Taille disponible maximale */
 }
}

/***********************************************************************
* DOS_FreeMem: LibŠre de la m‚moire pr‚alablement r‚serv‚e             *
* Entr‚e    : Segment de la m‚moire                                    *
* Sortie    : n‚ant                                                    *
***********************************************************************/

void DOS_FreeMem( unsigned int Adr )
{
 regs.h.ah = FREE_MEM;                       /* Num‚ro de la fonction */
 sregs.es = Adr;                                   /* Segment du bloc */
 intdosx( &regs, &regs, &sregs );              /* Interruption de DOS */
}

/***********************************************************************
* DOS_ChangeMem : Modifie la taille d'un bloc r‚serv‚                  *
* Entr‚es       : Ancien segment et nouvelle taille                    *
* Sortie       : Segment du nouveau bloc allou‚,                       *
*                nombre de paragraphes allou‚s ou disponibles          *
***********************************************************************/

void DOS_ChangeMem( unsigned int Ta,
                    unsigned int *Adr,
                    unsigned int *Res )
{
 regs.h.ah = CHANGE_MEM;                     /* Num‚ro de la fonction */
 regs.x.bx = Ta;                  /* Nombre de paragraphes … r‚server */
 sregs.es = *Adr;                       /* Segment du bloc … modifier */
 intdosx( &regs, &regs, &sregs );              /* Interruption de DOS */
 if( !regs.x.cflag )                                 /* Appel r‚ussi? */
   *Res = Ta;                      /* Oui, indique la nouvelle taille */
 else                                                  /* Non, erreur */
   *Res = regs.x.bx;                   /* M‚moire maximale disponible */
}

/***********************************************************************
* LitStrategie : Lit la strat‚gie d'allocation en vigueur              *
* Entr‚e       : n‚ant                                                 *
* Sortie       : Type de strat‚gie                                     *
***********************************************************************/

int LitStrategie( void )
{
 regs.x.ax = GET_STRATEGY;           /* Fixe le num‚ro de la fonction */
 intdos( &regs, &regs );
 return regs.x.ax;                   /* Retourne le type de strat‚gie */
}

/***********************************************************************
* LitUMB       : Lit l'‚tat d'inclusion des blocs UMB                  *
* Entr‚e       : n‚ant                                                 *
* Sortie       : Indique sir les blocs UMB sont pris en compte         *
* Info         : … partir de la version 5.0 de DOS uniquement          *
***********************************************************************/

int LitUMB( void )
{
 regs.x.ax = GET_UMB;                /* Fixe le num‚ro de la fonction */
 intdos( &regs, &regs );
 return regs.h.al;                                  /* Indique l'‚tat */
}

/***********************************************************************
* FixeStrategie: Fixe la strat‚gie d'allocation de la m‚moire          *
* Entr‚e       : Nouveau type de strat‚gie souhait‚e                   *
* Sortie       : n‚ant                                                 *
***********************************************************************/

void FixeStrategie( unsigned int Strategie )
{
 regs.x.ax = SET_STRATEGY;            /* Fixe le num‚ro de la fonction*/
 regs.x.bx = Strategie;
 intdos( &regs, &regs );
}

/***********************************************************************
* FixeUMB      : Fixe l'‚tat d'inclusion des blocs de m‚moire UMB      *
* Entr‚e       : Nouvel ‚tat d'inclusion souhait‚                      *
* Sortie       : n‚ant                                                 *
* Info         : Disponible … partir de la version 5.0 de DOS          *
***********************************************************************/

void FixeUMB( unsigned int UMB )
{
 regs.x.ax = SET_UMB;                /* Fixe le num‚ro de la fonction */
 regs.x.bx = UMB;
 intdos( &regs, &regs );
}

/***********************************************************************
* AlloueMemoire   : Cr‚e l'environnement du test                       *
* Entr‚e          : n‚ant                                              *
* Sortie          : n‚ant                                              *
***********************************************************************/

void AlloueMemoire( void )
{
 unsigned int SegAdr;                /* Segment de la m‚moire allou‚e */
 unsigned int Essai;                   /* Taille de m‚moire souhait‚e */
 unsigned int Taille;                 /* Taille de la m‚moire allou‚e */

 /*-- 1ø Alloue les blocs de test ------------------------------------*/

 FixeUMB( UMB_NON );
 DOS_GetMem( TEST_TA, &SegConv, &Taille );          /* Cherche le bloc*/
 if( SegConv == 0 )                                        /* Erreur? */
   return;                               /* Oui, retourne … l'appelant*/

 FixeUMB( UMB_OUI );
 FixeStrategie( CHERCHE_OBEN | DABORD_UMB );
 DOS_GetMem( TEST_TA_UMB, &UMBSeg, &Taille );
 if( UMBSeg != 0  &&  UMBSeg < 0xA000 )         /* Pas de blocs UMB ? */
 {
   DOS_FreeMem( UMBSeg );                        /* LibŠre la m‚moire */
   UMBSeg = 0;                                /* Absence de blocs UMB */
 }

 /*-- 2ø Alloue la m‚moire restante par blocs de 1 Ko ----------------*/

 Essai = 63;               /* Essaie d'abord d'allouer 14 paragraphes */
 NbAdresse = 0;
 do
 {
   DOS_GetMem( Essai, &SegAdr, &Taille );    /* R‚clame de la m‚moire */
   if( SegAdr != 0 )                            /* M‚moire accord‚e ? */
     ChampAdresse[ NbAdresse++ ] = SegAdr; /* Oui, m‚morise l'adresse */
 }
 while( SegAdr != 0 );                             /* Tout est allou‚ */

 /*-- 3ø LibŠre … nouveau les blocs de test --------------------------*/

 if( SegConv > 0 )
   DOS_FreeMem( SegConv-- );                  /* MCB ‚galement lib‚r‚ */
 if( UMBSeg > 0 )
   DOS_FreeMem( UMBSeg-- );                   /* MCB ‚galement lib‚r‚ */
}

/***********************************************************************
* LibereMemoire   : LibŠre la m‚moire allou‚e par ALloueMemoire        *
* Entr‚e          : n‚ant                                              *
* Sortie          : n‚ant                                              *
* Variable globale: ChampAdresse/R                                     *
***********************************************************************/

void LibereMemoire( void )

{
 unsigned int i;                                          /* Compteur */

 if( NbAdresse > 0 )              /* LibŠre un … un les blocs de 1 Ko */
   for( i = 0; i < NbAdresse; i++ )
     DOS_FreeMem( ChampAdresse[ i ] );
}

/***********************************************************************
* AfficheResultat : Affiche l'occupation de la m‚moire                 *
* Entr‚es          : AVECCADRE = TRUE, si le cadre doit aussi ˆtre -   *
*                                affich‚                               *
* Sortie           : n‚ant                                             *
***********************************************************************/

void AfficheResultat( BYTE AvecCadre )
{

 char          SChamp[ TEST_TA_KB ];
 char          SChamp_UMB[ TEST_TA_UMB_KB ];
 unsigned int  i, j;                                     /* Compteurs */
 unsigned int  Position;                       /* Variable auxiliaire */
 char          DerCara;      /* M‚morise le dernier caractŠre affich‚ */
 int           CoulCour;              /* Couleur d'affichage courante */

 memset( SChamp, 32, TEST_TA_KB );        /* Initialise champs d'aff. */
 memset( SChamp_UMB, 32, TEST_TA_UMB_KB );

 /*-- Remplit le tableau de la m‚moire -------------------------------*/

 for( i = 0; i < NBREBLOC; i++ )
 {
   if( BlocChamp[ i ].Adresse > 0xA000 )                      /* UMB? */
   {
     Position = ( BlocChamp[ i ].Adresse - UMBSeg ) / 64;
     for( j = 0; j <= BlocChamp[ i ].Taille / 64; j++ )
       SChamp_UMB[ Position + j ] = i + 65;
   }
   else if ( BlocChamp[ i ].Adresse > 0 )
   {
     Position = ( BlocChamp[ i ].Adresse - SegConv ) / 64;
     for( j = 0; j <= BlocChamp[ i ].Taille / 64; j++ )
       SChamp[ Position + j ] = i + 65;
   }
 }

 /*-- Trace le cadre du tableau --------------------------------------*/

 if ( AvecCadre )
 {
   Print( 1, 7, 0x07, "M‚moire conventionnelle :" );
   Print( 1, 8, 0x07,
              "                   1         2         3         4" );
   Print( 1, 9, 0x07,
              "          1        0         0         0         0" );
   Print( 1, 10, 0x07,
              "ÉÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»" );
   for ( i = 0; i < 4; i++ )
    Print( 1, 11 + i, 0x07, "º %3i %s%s", i * 40,
               "Ko º                                        º",
               TexteTouche[ i ] );
   Print( 1, 15, 0x07,
              "ÈÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼" );
   if ( UMBSeg > 0 )
   {
    Print( 1, 17, 0x07, "UMB :" );
    Print( 1, 18, 0x07,
               "                   1         2         3         4" );
    Print( 1, 19, 0x07,
               "          1        0         0         0         0" );
    Print( 1, 20, 0x07,
               "ÉÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»" );
    Print( 1, 21, 0x07,
               "º   0 KB º                                        º" );
    Print( 1, 22, 0x07,
               "ÈÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼" );
   }
   else
    Print( 1, 17, 0x07, "Pas d'UMB disponible");
  }

   /*-- AFfiche le tableau de la m‚moire conventionnelle -------------*/

 DerCara = 0;                            /* Dernier caractŠre affich‚ */
 CoulCour = 1;                           /* DerniŠre couleur affich‚e */
 for( i = 0; i < 4; i++ )
   for( j = 0; j < 40; j++ )
   {
     if( DerCara != SChamp[ i * 40 + j ] ) /* Changement de couleur ? */
     {
       CoulCour = ( CoulCour + 1 ) % 2;    /* Nouveau code de couleur */
       DerCara = SChamp[ i * 40 + j ];    /* CaractŠre de comparaison */
     }
     Print( j + 11, i + 11, ChampCouleur[ CoulCour ],
            "%c", SChamp[ i * 40 + j ] );
  }

 /*-- Affiche le tableau des UMB -------------------------------------*/

 if( UMBSeg > 0 )
 {
   for( j = 0; j < 40; j++ )
   {
     if( DerCara != SChamp_UMB[ j ] )        /* Changement de couleur */
     {
       CoulCour = ( CoulCour + 1 ) % 2;    /* Nouveau code de couleur */
       DerCara = SChamp_UMB[ j ];         /* CaractŠre de comparaison */
     }
     Print( j + 11, 21, ChampCouleur[ CoulCour ],
            "%c", SChamp_UMB[ j ] );
   }
 }
}

/***********************************************************************
* Demo     : D‚monstration de la gestion de la m‚moire                 *
* Entr‚es  : Inclusion des UMB, recherche prioritaire dans les UMB     *
*            Strat‚gie d'allocation de la m‚moire                      *
* Sortie   : n‚ant                                                     *
***********************************************************************/

void Demo( int Avec_UMB,
           int UMB_dabord,
           int Strategie )
{
 int          i;                                          /* Compteur */
 int          Touche;                               /* Touche frapp‚e */
 char         Marqueur[ 5 ];         /* Marqueur (A-Z) de r‚servation */
 unsigned int Essai;                               /* Taille r‚serv‚e */
 unsigned int Taille;

  /*-- Initialise les champs adresse et taille -----------------------*/

 for ( i = 0; i < NBREBLOC; i++ )              /* Toutes les adresses */
 {
   BlocChamp[ i ].Adresse = 0;                     /* Segment du bloc */
   BlocChamp[ i ].Taille = 0;                       /* Taille du bloc */
 }

 AfficheResultat( TRUE );                       /* Affiche le tableau */

  /*-- Boucle de d‚monstration ---------------------------------------*/

 do
 {
  /*-- Fixe la strat‚gie souhait‚e -----------------------------------*/
  if( Avec_UMB )                                 /* Utilise les UMB ? */
    FixeUMB( UMB_OUI );
  else
    FixeUMB( UMB_NON );

  if( UMB_dabord )
    FixeStrategie( Strategie | DABORD_UMB );
  else
    FixeStrategie( Strategie );

   /*-- Affiche la strat‚gie actuelle --------------------------------*/

  Print( 1, 3, 0x07,
    "  [F8] Strat‚gie de gestion m‚moire : %s", SText[ Strategie ]  );
  Print( 1, 4, 0x07,
    "  [F9] Recherche dans les blocs UMB : %s", OuiNon[ UMB_dabord ]);
  Print( 1, 5, 0x07,
    " [F10] Exploitation des blocs UMB   : %s", OuiNon[ Avec_UMB ]  );
  Print( 1, 6, 0x07, "---------------------------------------" );
  Print( 40, 6, 0x07,"---------------------------------------" );

   /*-- Saisie et traitement -----------------------------------------*/

  while( ! kbhit() );                  /* Attend une frappe de touche */
  Touche = getch();                                  /* Lit la touche */
  if( ( Touche == 0 ) && ( kbhit() ) )          /* Touche de fonction */
    Touche = getch();                          /* Cherche le 2me code */

  switch(  Touche )
  {
    case F1 :                            /* Alloue le bloc de m‚moire */
      i = -1;                            /* Pas encore de bloc valide */
      do                                /* Saisie jusqu'… bloc valide */
      {
       Print( 1, 23, 0x07, "Quel bloc faut-il r‚server [ A-Z ]: " );
       scanf( "%s", Marqueur );
       Marqueur[0] = toupper( Marqueur[ 0 ] );
       if(( Marqueur[0] >= 'A' ) && ( Marqueur[0] <= 'Z' ))
         if( BlocChamp[ (int) Marqueur[0] - 65 ].Adresse == 0 )
           i = (int) Marqueur[0] - 65;
      }
      while ( i == -1 );
      Print( 1, 24, 0x07,
        "Combien de Ko faut-il r‚server : " );
      scanf( "%i", &Essai );
      Essai = Essai * 64 - 1;            /* Conversion en paragraphes */
      DOS_GetMem( Essai, &BlocChamp[ i ].Adresse,
                         &BlocChamp[ i ].Taille );
      if( BlocChamp[ i ].Taille != Essai )                /* Erreur ? */
      {
       Print( 1, 25, 0x07, "Il ne reste plus que %4d Ko !",
                           ( BlocChamp[ i ].Taille + 1 ) /  64  );
       while( !kbhit() );

       while( kbhit() )
         Touche = getch();
       Touche = 0;
      }
      Print(1,23, 0x07, "                                            ");
      Print(1,24, 0x07, "                                            ");
      Print(1,25, 0x07, "                                            ");
      AfficheResultat( FALSE );                 /* Affiche le tableau */
      break;

    case F2 :                                /* LibŠre le bloc allou‚ */
     i = -1;                             /* Pas encore de bloc valide */
     do                                 /* Saisie jusqu'… bloc valide */
     {
       Print( 1, 23, 0x07, "Quel bloc faut-il lib‚rer [ A-Z ] : " );
       scanf( "%s", Marqueur );
       Marqueur[0] = toupper( Marqueur[ 0 ] );
       if(( Marqueur[0] >= 'A' ) && ( Marqueur[0] <= 'Z' ))
         if( BlocChamp[ (int) Marqueur[0] - 65 ].Adresse != 0 )
           i = (int) Marqueur[0] - 65;
     }
     while( i == -1 );
     DOS_FreeMem( BlocChamp[ i ].Adresse );
     BlocChamp[ i ].Adresse = 0;
     BlocChamp[ i ].Taille = 0;
     Print(1, 23, 0x07, "                                            ");
     AfficheResultat( FALSE );                  /* Affiche le tableau */
     break;

    case F3 :                          /* Modifie la taille d'un bloc */
     i = -1;                             /* Pas encore de bloc valide */
     do                                 /* Saisie jusqu'… bloc valide */
     {
       Print( 1, 23, 0x07, "Quel bloc faut-il lib‚rer [ A-Z ] : " );
       scanf( "%s", Marqueur );
       Marqueur[0] = toupper( Marqueur[ 0 ] );
       if(( Marqueur[0] >= 'A' ) && ( Marqueur[0] <= 'Z' ))
         if( BlocChamp[ (int) Marqueur[0] - 65 ].Adresse != 0 )
           i = (int) Marqueur[0] - 65;
     }
     while ( i == -1 );
     Print( 1, 24, 0x07, "Combien de Ko faut-il r‚server : " );
     scanf( "%i", &Essai );
     Essai = Essai * 64 - 1;             /* Conversion en paragraphes */
     DOS_ChangeMem( Essai, &BlocChamp[ i ].Adresse, &Taille );
     if( Taille != Essai )                                 /* Erreur ?*/
     {
       Print( 1, 23, 0x07, "Il ne reste plus que %4i Ko !",
                         ( Taille + 1 ) /  64  );
       while( !kbhit() );
       while( kbhit() )
         Touche = getch();
       Touche = 0;
     }
     else
       BlocChamp[ i ].Taille = Taille;             /* Nouvelle taille */
     Print(1, 23, 0x07,"                                            ");
     Print(1, 24, 0x07,"                                            ");
     Print(1, 25, 0x07,"                                            " );
     AfficheResultat( FALSE );                  /* Affiche le tableau */
     break;

    case F8 :                                  /* Change de strat‚gie */
     Strategie = ( Strategie + 1 ) % 3;
     break;

    case F9 :                  /* Commutation : Recherche prioritaire */
                                               /*  dans les blocs UMB */
     UMB_dabord = ! UMB_dabord;
     break;

    case F10:                /* Commutation : Inclusion des blocs UMB */
     Avec_UMB = ! Avec_UMB;
     break;
   }
 }
 while( Touche != ESC );
}

/***********************************************************************
**                     Programme principal                            **
***********************************************************************/

void main( void )
{
 int StartStrategie;              /* Strat‚gie d'allocation au d‚part */
 int StartUMB;        /* D‚cision d'inclusion des blics UMB au d‚part */
 int Act_UMB_oui;             /* Exploitation des blocs UMB (Oui/Non) */
 int Act_UMB_dabord;                 /* Recherche prioritaire des UMB */
 int Act_Strategie;                /* Strat‚gie d'allocation actuelle */

  /*-- Dessine l'‚cran    --------------------------------------------*/

 clrscr();
 Print( 1, 1, 0x07,
        "D‚monstration de gestion m‚moire sous DOS " );
 Print( 51, 1, 0x07,
             " (C) 1991, 92 by Michael TISCHER" );
 Print( 1, 2, 0x07, "=======================================" );
 Print( 40, 2, 0x07, "=======================================" );
 Print( 25, 5, 0x07, "Initialisation");

     /*-- Sauvegarde les valeurs courantes ---------------------------*/

 StartStrategie = LitStrategie();           /* Strategie d'allocation */
 StartUMB = LitUMB();                      /* Prise en compte des UMB */
 AlloueMemoire();                       /* Cr‚e lenvironnement de test*/
 FixeStrategie( StartStrategie );    /* Restaure l'ancienne strat‚gie */
 FixeUMB( StartUMB );

 if ( SegConv == 0 )             /* M‚moire conventionnelle allou‚e ? */
  {                                       /* Non, termine avec erreur */
   clrscr();
   printf( "MEMDEMOC : M‚moire insuffisante \n" );
   exit(1);
  }

                     /*-- Valeurs de d‚part --------------------------*/

 Act_UMB_oui = ( StartUMB == UMB_OUI );
 Act_UMB_dabord = ( ( StartStrategie & DABORD_UMB ) == DABORD_UMB );
 Act_Strategie = ( StartStrategie & ( 0xFF ^ DABORD_UMB ) );

 /*-- D‚monstration de la gestion de la m‚moire ----------------------*/

 clrscr();
 Print( 1, 1, 0x07,
        "D‚monstration de gestion m‚moire sous DOS");
 Print( 51, 1, 0x07,
             "(C) 1991, 92 Michael Tischer" );
 Print( 1, 2, 0x07, "=======================================" );
 Print( 40, 2, 0x07, "=======================================" );
 Demo( Act_UMB_oui, Act_UMB_dabord, Act_Strategie );

 /*-- Restaure les anciennes valeurs ---------------------------------*/

 LibereMemoire();                          /* LibŠre l'espace r‚serv‚ */
 FixeStrategie( StartStrategie );
 FixeUMB( StartUMB );
 clrscr();
}
