/***********************************************************************
*                              X M S C . C                             *
**--------------------------------------------------------------------**
*  Sujet        : D‚monstration de l'accŠs … la m‚moire ‚tendue et …   *
*                 la zone High Memory … l'aide des fonctions XMS telles*
*                 qu'elles sont appliqu‚es par exemple avec le pilote  *
*                 de p‚riph‚riques HIMEM.SYS.                          *
**--------------------------------------------------------------------**
*  Auteur         : MICHAEL TISCHER                                    *
*  D‚velopp‚ le   : 27.07.1990                                         *
*  DerniŠre MAJ   : 29.03.1992                                         *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Cr‚ation       : CL /AS /Zp xmsc.c xmsca                            *
*  Appel          : xmsc                                               *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Cr‚ation       : par un fichier de projet contenant les noms:       *
*                     xmsc.c                                           *
*                     xmsca.obj                                        *
***********************************************************************/

/*-- Int‚grer les fichiers include -----------------------------------*/


#include <dos.h>                       /* Pour appels d'interruptions */
#include <stdio.h>

#ifdef __TURBOC__
  #include <alloc.h>
#else
  #include <malloc.h>
#endif

/*-- Constantes ------------------------------------------------------*/

#define ERR_NOERR          0x00                       /* Pas d'erreur */
#define ERR_NOTIMPLEMENTED 0x80          /* Fonction appel‚e inconnue */
#define ERR_VDISKFOUND     0x81             /* Ram disk VDISK d‚tect‚ */
#define ERR_A20            0x82    /* Erreur sur canal d'adresses A20 */
#define ERR_GENERAL        0x8E  /* Erreur pilote … caractŠre g‚n‚ral */
#define ERR_UNRECOVERABLE  0x8F                /* Erreur irratrapable */
#define ERR_HMANOTEXIST    0x90                    /* HMA introuvable */
#define ERR_HMAINUSE       0x91                   /* HMA d‚j… appel‚e */
#define ERR_HMAMINSIZE     0x92            /* Taille HMA insuffisante */
#define ERR_HMANOTALLOCED  0x93                   /* HMA non affect‚e */
#define ERR_A20STILLON     0x94  /* Canal d'adresses A20 encore actif */
#define ERR_OUTOMEMORY     0xA0 /* Plus de m‚moire ‚tendue disponible */
#define ERR_OUTOHANDLES    0xA1 /* Tous identificateurs XMS sont pris */
#define ERR_INVALIDHANDLE  0xA2            /* Identificateur invalide */
#define ERR_SHINVALID      0xA3     /* Identificateur source invalide */
#define ERR_SOINVALID      0xA4           /* D‚calage source invalide */
#define ERR_DHINVALID      0xA5       /* Identif destination invalide */
#define ERR_DOINVALID      0xA6      /* D‚calage destination invalide */
#define ERR_LENINVALID     0xA7 /* Longueur invalide pr fonction Move */
#define ERR_OVERLAP        0xA8              /* Recouvrement interdit */
#define ERR_PARITY         0xA9                   /* Erreur de parit‚ */
#define ERR_EMBUNLOCKED    0xAA               /* UMB n'est pas bloqu‚ */
#define ERR_EMBLOCKED      0xAB              /* UMB est encore bloqu‚ */
#define ERR_LOCKOVERFLOW   0xAC   /* D‚bordement compteur blocage UMB */
#define ERR_LOCKFAIL       0xAD      /* L'UMB ne peut pas ˆtre bloqu‚ */
#define ERR_UMBSIZETOOBIG  0xB0          /* Plus petit UMB disponible */
#define ERR_NOUMBS         0xB1              /* Plus d'UMB disponible */
#define ERR_INVALIDUMB     0xB2    /* adresse du segment UMB invalide */

#define TRUE               ( 0 == 0 )
#define FALSE              ( 0 == 1 )

/*-- Macros ----------------------------------------------------------*/

#ifndef MK_FP
  #define MK_FP(seg,ofs) \
         ((void far *) (((unsigned long)(seg) << 16) | (unsigned)(ofs)))
#endif

#define Hi(x) (*((BYTE *) &x+1))                  /* Hi byte d'un int */
#define Lo(x) (*((BYTE *) &x))                    /* Lo byte d'un int */

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char  BYTE;
typedef BYTE           BOOL;
typedef unsigned       WORD;

typedef struct                         /* Informations pour appel XMS */
         {
          WORD AX,               /* Seuls les registres AX, BX, DX et */
               BX,                /* SI sont requis selon la fonction */
               DX,                 /* appel‚e, il faut donc une autre */
               SI,                              /* adresse de segment */
               Segment;
         } XMSRegs;

typedef struct                      /* Structure Move m‚moire ‚tendue */
         {
          long LenB;                       /* Nbre d'octets … d‚caler */
          int  SHandle;                      /* Identificateur source */
          long SOffset;                            /* D‚calage source */
          int  DHandle;                         /* Handle destination */
          long DOffset;                       /* D‚calage destination */
         } EMMS;

/*-- D‚clarations externes -------------------------------------------*/

extern void XMSCall( BYTE NumFonc, XMSRegs *Xr );

/*-- Variables globales ----------------------------------------------*/

void far   *XMSPtr;     /* Pointeur sur Extended Memory Manager (XMM) */
BYTE       XMSErr;          /* Code d'erreur de la derniŠre op‚ration */

/***********************************************************************
* XMSInit : Initialise les routines d'appel des fonctions XMS          *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si pilote XMS identifi‚ sinon FALSE                    *
* Info    : - L'appel de cette fonction doit pr‚c‚der celui de toutes  *
*             les autres proc‚dures et fonctions ‚manant de ce         *
*             programme.                                               *
***********************************************************************/

BOOL XMSInit( void )
{
 union REGS    Regs;  /* Registre processeur pour appel interruptions */
 struct SREGS  SRegs;                             /* Registre segment */
 XMSRegs       Xr;                         /* Registre pour appel XMS */

 Regs.x.ax = 0x4300;          /* D‚tecte disponibilit‚ du XMS Manager */
 int86( 0x2F, &Regs, &Regs );              /* Appel du DOS Dispatcher */

 if( Regs.h.al == 0x80 )                      /* D‚tect‚ XMS-Manager? */
 {                                                             /* Oui */
   Regs.x.ax = 0x4310;              /* Retourner point d'accŠs au XMM */
   int86x( 0x2F, &Regs, &Regs, &SRegs );
   XMSPtr = MK_FP( SRegs.es, Regs.x.bx ); /*Copie adresse ds var glob.*/
   XMSErr = ERR_NOERR;                        /* Pas d'erreur apparue */
   return TRUE;                  /* Trouv‚ handler, module initialis‚ */
 }
 else                               /* XMS Handler n'est pas install‚ */
   return FALSE;
}

/***********************************************************************
* XMSQueryVer: Renvoie le nø de version de l'XMS et autres informations*
*              sur l'‚tat                                              *
**--------------------------------------------------------------------**
* Entr‚e : VerNr = Stocke nø de version aprŠs appel de la fonction     *
*                  (Format: 235 == 2.35)                               *
*           RevNr = Stocke nø de r‚vision aprŠs appel de la fonction   *
* Sortie : TRUE si un HMA est disponible sinon FALSE                   *
***********************************************************************/

BOOL XMSQueryVer( int * VerNr, int * RevNr)
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 0, &Xr );                        /* Appeler fonction XMS #0 */
 *VerNr = Hi(Xr.AX)*100 + ( Lo(Xr.AX) >> 4 ) * 10 +
           ( Lo(Xr.AX) & 15 );
 *RevNr = Hi(Xr.BX)*100 + ( Lo(Xr.BX) >> 4 ) * 10 +
          ( Lo(Xr.BX) & 15 );
 return( Xr.DX == 1 );
}

/***********************************************************************
* XMSGetHMA : Retourner … l'appelant le droit d'accŠs … la HMA.        *
**--------------------------------------------------------------------**
* Entr‚e  : LenB = Nombre d'octets … allouer                           *
* Info    : Les programmes r‚sidents devraient r‚server exclusivement  *
*           la m‚moire strictement requise. Par contre, donner 0xFFFF  *
*           aux applications.                                          *
* Sortie  : TRUE si la HMA a pu ˆtre rendue disponible sinon FALSE;    *
***********************************************************************/

BOOL XMSGetHMA( WORD LenB )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = LenB;                    /* Stocke longueur dans registre DX */
 XMSCall( 1, &Xr );                          /* Appel fonction XMS #1 */
 return XMSErr == ERR_NOERR;
}

/***********************************************************************
* XMSReleaseHMA : LibŠre l'HMA et permet ainsi sa transmission …       *
*                 d'autres programmes.                                 *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Appeler cette proc‚dure avant de quitter un programme    *
*             si la HMA a ‚t‚ allou‚e par un appel de XMSGetHMA pour   *
*             pouvoir la transmettre aux programmes appel‚s plus tard. *
*           - L'appel de cette proc‚dure entraŒne la perte des         *
*             donn‚es stock‚es dans la HAM.                            *
***********************************************************************/

void XMSReleaseHMA( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 2, &Xr );                          /* Appel fonction XMS #2 */
}

/***********************************************************************
* XMSA20OnGlobal: LibŠre le canal d'adresses A20, permettant l'accŠs   *
*                 direct … la HMA.                                     *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - La lib‚ration du canal d'adresses A20 est relativement   *
*             lente sur de nombreux ordinateurs. Veillez … ne pas      *
*             abuser de l'usage de cette proc‚dure.                    *
***********************************************************************/

void XMSA20OnGlobal( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 3, &Xr );                          /* Appel fonction XMS #3 */
}

/***********************************************************************
* XMSA20OffGlobal: Pendant de la proc‚dure XMSA20OnGlobal, celle-ci    *
*                  bloque … nouveau le canal d'adresses A20, interdi-  *
*                  sant l'accŠs direct … la HMA                        *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Appelez toujours cette proc‚dure avant de quitter un     *
*             programme si le canal d'adresses A20 a ‚t‚ lib‚r‚ par    *
*             un appel de XMSA20OnGlobal                               *
***********************************************************************/

void XMSA20OffGlobal( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 4, &Xr );                          /* Appel fonction XMS #4 */
}

/***********************************************************************
* XMSA20OnLocal: Voir XMSA20OnGlobal                                   *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Cette proc‚dure locale se distingue de sa variante       *
*             globale par la lib‚ration du canal: elle n'est possible  *
*             que si elle n'a pas ‚t‚ effectu‚e par un appel pr‚c‚dent *
***********************************************************************/

void XMSA20OnLocal( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 5, &Xr );                          /* Appel fonction XMS #5 */
}

/***********************************************************************
* XMSA20OffLocal : Voir XMSA29OffGlobal                                *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Cette proc‚dure locale se distingue de sa variante       *
*             globale par la lib‚ration du canal: elle n'est possible  *
*             que si elle n'a pas ‚t‚ effectu‚e par un appel pr‚c‚dent *
***********************************************************************/

void XMSA20OffLocal( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 6, &Xr );                          /* Appel fonction XMS #6 */
}

/***********************************************************************
* XMSIsA20On : Retourne l'‚tat du canal d'adresse A20                  *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si le canal d'adresses A20 est lib‚r‚ sinon FALSE.     *
***********************************************************************/

BOOL XMSIsA20On( void )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 7, &Xr );                          /* Appel fonction XMS #7 */
 return( Xr.AX == 1 );                    /* AX == 1 ---> Canal libre */
}

/***********************************************************************
* XMSQueryFree : Renvoie la m‚moire ‚tendue disponible et la taille du *
*                plus gros bloc libre                                  *
**--------------------------------------------------------------------**
* Entr‚e : TotalLibre: Stocke la taille totale de l'EM libre.          *
*          MaxBl   : Stocke la taille du plus grand bloc libre.        *
* Info    : - Les deux valeurs sont en Ko                              *
*           - La taille de la HMA n'est pas comptabilis‚e mˆme si elle *
*             n'a ‚t‚ affect‚e … aucun programme.                      *
***********************************************************************/

void XMSQueryFree( int * TotalLibre, int * MaxBl )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 XMSCall( 8, &Xr );                          /* Appel fonction XMS #8 */
 *TotalLibre = Xr.AX;                 /* La taille totale est dans AX */
 *MaxBl      = Xr.DX;                 /* La m‚moire libre est dans DX */
}

/***********************************************************************
* XMSGetMem : Alloue un bloc de m‚moire ‚tendue (EMB)                  *
**--------------------------------------------------------------------**
* Entr‚e : LenKB : Taille en Ko du bloc interrog‚                      *
* Sortie : Identificateur pour accŠs au bloc ou 0, si aucun bloc n'a   *
*          pu ˆtre allou‚. Un code d'erreur se trouve alors dans la    *
*          variable globale XMSErr.                                    *
***********************************************************************/

int XMSGetMem( int LenKb )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = LenKb;           /* Stockons la longueur dans le registre DX */
 XMSCall( 9, &Xr );                          /* Appel fonction XMS #9 */
 return Xr.DX;                           /* Retourne l'identificateur */
}

/***********************************************************************
* XMSFreeMem : LibŠre un bloc de m‚moire ‚tendue (EMB) pr‚c‚demment    *
*              allou‚                                                  *
**--------------------------------------------------------------------**
* Entr‚e : Handle : L'identificateur pour acc‚der au bloc. Il a ‚t‚    *
*                   obtenu en appelant XMSGetMem.                      *
* Info    : - Le contenu de l'EMB est d‚finitivement d‚truit par cet   *
*             appel, l'identificateur devient invalide.                *
*           - Avant de quitter un programme, lib‚rez … l'aide de cette *
*             proc‚dure toutes les zones pr‚c‚demment allou‚es pour    *
*             pouvoir les allouer aux programmes suivants.             *
***********************************************************************/

void XMSFreeMem( int Handle )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = Handle;      /* Copions l'identificateur dans le registre DX */
 XMSCall( 10, &Xr );                        /* Appel fonction XMS #10 */
}

/***********************************************************************
* XMSCopy : Copie des zones de m‚moire entre la m‚moire ‚tendue et la  *
*           m‚moire conventionnelle ou … l'int‚rieur de ces deux       *
*           groupes de m‚moire.                                        *
**--------------------------------------------------------------------**
* Entr‚e : HandleOrig  : Identificateur du bloc de m‚moire … d‚placer  *
*          OffsetOrig  : Offset dans ce bloc, … partir duquel le       *
*                        d‚placement sera effectu‚.                    *
*          HandleDest :  Identificateur du bloc de m‚moire cible       *
*          OffsetDest :  Offset dans le bloc cible.                    *
*          LenW       :  Nombre de mots d‚plac‚s                       *
* Info    : - Pour utiliser la m‚moire normale dans cette op‚ration,   *
*           donnez la valeur 0 … l'identificateur ("Handle") et pour   *
*           l'offset, le segment et l'adresse de l'offset dans sa      *
*           forme habituelle (offset avant le segment).                *
***********************************************************************/

void XMSCopy( int HandleOrig, long OffsetOrig, int HandleDest,
              long OffsetDest, int LenW )

{
 XMSRegs Xr;                               /* Registre pour appel XMS */
 EMMS Mi;                                            /* Stocke l'EMMS */
 void far * MiPtr;

 Mi.LenB    = 2 * LenW;              /* Commencer par pr‚parer l'EMMS */
 Mi.SHandle = HandleOrig;
 Mi.SOffset = OffsetOrig;
 Mi.DHandle = HandleDest;
 Mi.DOffset = OffsetDest;

 MiPtr      = &Mi;                   /* Pointeur FAR sur la structure */
 Xr.SI      = FP_OFF( MiPtr );       /* Adresse de l'offset de l'EMMS */
 Xr.Segment = FP_SEG( MiPtr );        /* Adresse du segment de l'EMMS */
 XMSCall( 11, &Xr );                        /* Appel fonction XMS #11 */
}

/***********************************************************************
* XMSLock : Interdit tout d‚calage d'un bloc de m‚moire ‚tendue par    *
*           l'XMM et retourne son adresse absolue.                     *
**--------------------------------------------------------------------**
* Entr‚e : Handle : Identificateur du bloc de m‚moire retourn‚ lors de *
*          l'appel pr‚c‚dent de XMSGetMem.                             *
* Sortie : Adresse lin‚aire du bloc de m‚moire.                        *
***********************************************************************/

long XMSLock( int Handle )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = Handle;                                   /* Handle de l'EMB */
 XMSCall( 12, &Xr );                        /* Appel fonction XMS #12 */
 return( ((long) Xr.DX << 16) + Xr.BX);    /* Calcule adresse 32 bits */
}

/***********************************************************************
* XMSUnlock : LibŠre … nouveau un bloc de m‚moire ‚tendu pour une      *
*             op‚ration de d‚calage.                                   *
**--------------------------------------------------------------------**
* Entr‚e : Handle : Identificateur de la zone de m‚moire retourn‚ lors *
           d'un appel pr‚c‚dent de XMSGetMem.                          *
***********************************************************************/

void XMSUnlock( int Handle )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = Handle;                                   /* Handle de l'EMB */
 XMSCall( 13, &Xr );                        /* Appel fonction XMS #13 */
}

/***********************************************************************
* XMSQueryInfo : Retourne diverses informations sur un bloc de         *
*                m‚moire ‚tendue pr‚alablement allou‚.                 *
**--------------------------------------------------------------------**
* Entr‚e :  Handle : Identificateur de la zone de m‚moire              *
*           Lock   : Variable de stockage du compteur de Lock          *
*           LenKB  : Variable de stockage de la longueur du bloc en Ko *
*           FreeH  : Variable de stockage du nombre d'identificateurs  *
*                    restant libres.                                   *
* Info    : Cette proc‚dure ne permet pas de connaŒtre l'adresse d'un  *
*           bloc. Utilisez la fonction XMSLock pour cette information. *
***********************************************************************/

void XMSQueryInfo( int Handle, int * Lock, int * LenKB, int * FreeH )

{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX  = Handle;                                  /* Handle de l'EMB */
 XMSCall( 14, &Xr );                        /* Appel fonction XMS #14 */
 *Lock  = Hi( Xr.BX );                           /* Lit les registres */
 *FreeH = Lo( Xr.BX );
 *LenKB = Xr.DX;
}

/***********************************************************************
* XMSRealloc : Agrandit ou r‚duit la taille d'un bloc de m‚moire       *
*              ‚tendue allou‚ par XMSGetMem                            *
**--------------------------------------------------------------------**
* Entr‚e :  Handle   : Identificateur de la zone de m‚moire            *
*           NewLenkB : Nouvelle taille du bloc, en Ko                  *
* Sortie :  TRUE si la taille du bloc a ‚t‚ modifi‚e sinon FALSE       *
* Info   :  Ce bloc ne doit pas ˆtre verrouill‚!                       *
***********************************************************************/

BOOL XMSRealloc( int Handle, int NewLenkB)
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = Handle;                                   /* Handle de l'EMB */
 Xr.BX = NewLenkB;        /* La nouvelle longueur dans le registre BX */
 XMSCall( 15, &Xr );                        /* Appel fonction XMS #15 */
 return( XMSErr == ERR_NOERR );
}

/***********************************************************************
* XMSGetUMB : Alloue un bloc de Upper Memory (UMB)                     *
**--------------------------------------------------------------------**
* Entr‚e :  LenPara : Taille de la zone allou‚e en paragraphes de 16   *
*                     octets chacun.                                   *
*           Seg     : Variable de stockage de l'adresse du segment de  *
*                     l'UMB allou‚ (si tout va bien)                   *
*           MaxPara : Variable contenant la taille du plus gros bloc   *
*                     UMB en cas d'‚chec.                              *
* Sortie : TRUE si un UMB a ‚t‚ allou‚ sinon FALSE                     *
* Info    : Attention! Cette fonction n'est pas compatible avec tous   *
*           les pilotes XMS. Elle est extrˆmement d‚pendante du        *
*           mat‚riel.                                                  *
***********************************************************************/

BOOL XMSGetUMB( int LenPara, WORD * Seg, WORD * MaxPara )
{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX    = LenPara;                    /* Longueur demand‚e selon DX */
 XMSCall( 16, &Xr );                        /* Appel fonction XMS #16 */
 *Seg     = Xr.BX;                   /* Retourne l'adresse du segment */
 *MaxPara = Xr.DX;                       /* Longueur du plus gros UMB */
 return ( XMSErr == ERR_NOERR );
}

/***********************************************************************
* XMSFreeUMB : LibŠre un UMB allou‚ par XMSGetUMB.                     *
**--------------------------------------------------------------------**
* Entr‚e  : Seg : Adresse du segment de l'UMB … lib‚rer                *
* Info    : Attention! Cette fonction n'est pas compatible avec tous   *
*           les pilotes XMS. Elle est extrˆmement d‚pendante du        *
*           mat‚riel.                                                  *
***********************************************************************/

void XMSFreeUMB( WORD Seg )

{
 XMSRegs Xr;                               /* Registre pour appel XMS */

 Xr.DX = Seg;                 /* Adresse du segment de l'UMB selon DX */
 XMSCall( 17, &Xr );                        /* Appel fonction XMS #17 */
}

/*--------------------------------------------------------------------*/
/*-- Proc‚dures de test et de d‚monstration                         --*/
/*--------------------------------------------------------------------*/

/***********************************************************************
* HMATest : Teste la disponibilit‚ de l'HMA et d‚montre son maniement. *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************/

void HMATest( void)

{
 BOOL A20;                     /* Etat courant du canal d'adresse A20 */
 BYTE far * hmap;                               /* Pointeur sur l'HMA */
 WORD i,                                     /* Compteur d'it‚rations */
      err;                       /* Nombre d'erreurs d'accŠs … la HMA */

 printf( "Test HMA : Tapez une touche pour lancer le test..." );
 getch();
 printf("\n\n" );

 /*-- Allouer HMA et tester chaque adresse de la m‚moire -------------*/

 if( XMSGetHMA(0xFFFF) )                    /* Contr“lons-nous l'HMA? */
 {                                                             /* Oui */
   if( ( A20 = XMSIsA20On() ) == FALSE )    /* Donner l'‚tat du canal */
     XMSA20OnGlobal();                                  /* le lib‚rer */

   hmap = MK_FP( 0xFFFF, 0x0010 );                /* Pointeur sur HMA */
   err  = 0;                        /* Jusque l… encore aucune erreur */
   for( i = 1; i < 65520; ++i, ++hmap )
   {                              /* Tester chaque cellule s‚par‚ment */
     printf( "\rCellule m‚moire: %u", i );
     *hmap = i % 256;                       /* Ecrire … cette adresse */
     if( *hmap != i % 256 )                           /* et la relire */
     {                                                     /* Erreur! */
       printf( " ERREUR!\n" );
       ++err;
     }
   }

   XMSReleaseHMA();                                 /* Lib‚rons l'HMA */
   if( A20 == FALSE )         /* Est-ce que le canal A20 ‚tait libre? */
     XMSA20OffGlobal();                           /* Non, lib‚rons-le */

   printf( "\n" );
   if( err == 0 )                      /* Analyse du r‚sultat du test */
     printf( "HMA ok, aucune cellule de la m‚moire d‚fectueuse.\n" );
   else
     printf( "ATTENTION! %d cellules d‚fectueuses dans l'HMA\n", err );
 }
 else
   printf( "ATTENTION! AccŠs impossible … l'HMA.\n" );
}

/***********************************************************************
* EMBTest : Teste la m‚moire ‚tendue et montre l'appel de plusieurs    *
*           fonctions XMS                                              *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************/

void EMBTest( void )

{
 long Adr;
 BYTE * barp;                          /* Pointeur sur tampon d'un Ko */
 int  i, j,                                  /* Compteur d'it‚rations */
      err,                /* Nombre d'erreurs pendant l'accŠs … l'HMA */
      Handle,                  /* Identificateur pour acc‚der … l'EMB */
      TotalLibre,               /* Taille de toute la m‚moire ‚tendue */
      MaxBl;                                  /* Plus gros bloc libre */

 printf( "Test EMB : Tapez une touche pour lancer le test..." );
 getch();
 printf( "\n" );

 XMSQueryFree( &TotalLibre, &MaxBl ); /* Retourner taille m‚m. ‚tend. */
 printf( "Taille totale de la m‚moire ‚tendue (avec HMA) : %d KB\n",
         TotalLibre );
 printf( "                  Dont le plus gros bloc libre : %d KB\n",
         MaxBl );

 TotalLibre -= 64;               /* Calcul taille effective sans HMA. */
 if( MaxBl >= TotalLibre )                   /* Valeur vraisemblable? */
   MaxBl -= 64;                                                /* Non */

 if( MaxBl > 0 )                          /* Encore assez de m‚moire? */
 {                                                             /* Oui */
   Handle = XMSGetMem( MaxBl );
   printf( "%d Ko allou‚s.\n", MaxBl );
   printf( "Identificateur = %d\n", Handle );
   Adr    = XMSLock( Handle );                 /* Retourner l'adresse */
   XMSUnlock( Handle );                          /* Supprimer blocage */
   printf( "Adresse = %ld (%d KB)\n", Adr, Adr >> 10 );

   barp   = malloc( 1024 );                /* Le tampon sur le tas... */
   err    = 0;                      /* Jusque l… encore aucune erreur */

       /*-- V‚rifier l'EMB Ko aprŠs Ko -------------------------------*/

   for( i = 0; i < MaxBl; ++i )
   {
     printf( "\rTest du Ko: %d", i+1 );
     memset( barp, i % 255, 1024 );
     XMSCopy( 0, (long) ((void far *) barp),
              Handle, (long) i*1024, 512 );
     memset( barp, 255, 1024 );
     XMSCopy( Handle, (long) i*1024, 0,
              (long) ((void far *) barp), 512 );

     /*-- Compare le tampon recopi‚ avec le r‚sultat attendu ---------*/

     for( j = 0; j < 1024; ++j )
       if( *(barp+j) != i % 255 )
       {                                                   /* Erreur! */
         printf( " ERREUR!\n" );
         ++err;
         break;
       }
   }

   printf( "\n" );
   if( err == 0 )                      /* Analyse du r‚sultat du test */
     printf( "EMB ok, aucun des blocs test‚s d'un Ko ‚tait " \
            "d‚fectueux.\n");
   else
     printf( "ATTENTION! %d blocs d'1 Ko d‚fectueux dans l'EMB\n",err );

   free( barp );                                 /* Lib‚rer le tampon */
   XMSFreeMem( Handle );                             /* Lib‚rer l'EMB */
  }
}

/***********************************************************************
*                        P R O G R A M M E   P R I N C I P A L         *
***********************************************************************/

void main( void )
{
 int VerNr,                                          /* Nø de version */
     RevNr,                                         /* Nø de r‚vision */
     i;                                      /* Compteur d'it‚rations */

 for( i = 1; i < 25; ++i )                         /* Effacer l'‚cran */
   printf ( "\n" );

 printf("XMSC - (c) 1990, 92 by MICHAEL TISCHER\n\n" );
 if( XMSInit() )
 {
   if( XMSQueryVer( &VerNr, &RevNr ) )
     printf( "AccŠs possible … l'HMA.\n" );
   else
     printf( "Aucun accŠs … l'HMA.\n" );
   printf( "Nø de version XMS: %d.%d\n", VerNr / 100, VerNr % 100 );
   printf( "Nø de r‚vision   : %d.%d\n\n", RevNr / 100, RevNr % 100 );
   HMATest();                                             /* Test HMA */
   printf( "\n" );
   EMBTest();                                 /* Test m‚moire ‚tendue */
 }
 else
   printf( "Aucun pilote XMS install‚!\n" );
}
