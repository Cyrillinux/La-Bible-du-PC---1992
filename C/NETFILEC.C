/**********************************************************************/
/*                         N E T F I L E C . C                        */
/*--------------------------------------------------------------------*/
/*    Fonction      : Propose diff‚rentes proc‚dures et fonctions     */
/*                    pour r‚aliser des programmes en r‚seau sous DOS */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire: SMALL                                           */
/*--------------------------------------------------------------------*/
/*    Auteur        : Michael Tischer                                 */
/*    D‚velopp‚ le  : 10.02.1992                                      */
/*    DerniŠre MAJ  : 13.02.1991                                      */
/*--------------------------------------------------------------------*/
/*    Microsoft C   : Le message "Segment lost in conversation" est   */
/*                    malheureusement in‚vitable mais il ne gˆne      */
/*                    pas la compilation                              */
/**********************************************************************/

#include <dos.h>
#include <string.h>
#include <stdlib.h>

/*== Macros ==========================================================*/

#ifdef FP_OFF
  #undef FP_OFF
  #undef FP_SEG
#endif

#define FP_OFF(fp)      ((unsigned)(fp))
#define FP_SEG(fp)      ((unsigned)((unsigned long)(fp) >> 16))

/*== Constantes ======================================================*/

/*-- Valeurs bool‚ennes-----------------------------------------------*/

#define TRUE  ( 1 == 1 )
#define FALSE ( 0 == 1 )

/*-- Types d'accŠs aux fichiers-------------------------------------*/

#define FM_R       0                                 /* Lecture seule */
#define FM_W       1                                /* Ecriture seule */
#define FM_RW      2                           /* Lecture et ‚criture */

/*-- Modes de partage ou types de protection -------------------------*/

#define SM_COMP 0x00 /* Mode de compatibilit‚, aucune protection      */
#define SM_RW   0x10     /* Lecture et ‚criture externes interdites   */
#define SM_R    0x20 /* Lecture externe autoris‚e, ‚criture interdite */
#define SM_W    0x30 /* Lecture externe interdite, ‚criture autoris‚e */
#define SM_NO   0x40  /* Tout est permis, protection par verrouillage */
                                               /* des enregistrements */



/*-- Erreus possibles … l'appel des proc‚dures -----------------------*/

#define NE_OK            0x00                         /* Pas d'erreur */
#define NE_FileNotFound  0x02          /* Erreur : Fichier non trouv‚ */
#define NE_PathNotFound  0x03    /* Erreur : Chemi d'accŠs non trouv‚ */
#define NE_TooManyFiles  0x04     /* Erreur: Trop de fichiers ouverts */
#define NE_AccessDenied  0x05      /* Erreur: AccŠs au fichier refus‚ */
#define NE_InvalidHandle 0x06/* Erreur: Handle de fichier non valable */
#define NE_AccessCode    0x07       /* Erreur: Type d'accŠs interdit  */
#define NE_Share         0x20        /* Violation des rŠgles de Share */
#define NE_Lock          0x21/* Erreur de (d‚)verrouillage d'un enreg.*/
#define NE_ShareBuffer   0x24       /* D‚bordement du buffer de Share */

/*-- Num‚ros des fonctions pour les appels … DOS ---------------------*/

#define FCT_OPEN     0x3D/* Fonction: Ouvre un fichier avec un handle */
#define FCT_CLOSE    0x3E/* Fonction: Ferme un fichier avec un handle */
#define FCT_CREATE   0x3C /* Fonction: Cr‚e un fichier avec un handle */
#define FCT_WRITE    0x40          /* Fonction: Ecrit dans un fichier */
#define FCT_READ     0x3F            /* Fonction: Lit dans un fichier */
#define FCT_LSEEK    0x42         /* Fonction: Positionne le pointeur */
#define FCT_REC_LOCK 0x5C /* Fonction: Verrouille des enregistrements */

/*-- Num‚ros des fonctions pour autres interruptions ------*/

#define MULTIPLEX    0x2F             /* Interruption du multiplexeur */
#define FCT_SHARE    0x1000           /* Test d'installation de Share */

/*-- Marquage des fichiers (valeurs semblables … Turbo-Pascal ) ------*/

#define FMCLOSED     0xD7B0                          /* Fichier ferm‚ */
#define FMINPUT      0xD7B1              /* Fichier ouvert en lecture */
#define FMOUTPUT     0xD7B2             /* Fichier ouvert en ‚criture */
#define FMINOUT      0xD7B3  /* Fichier ouvert en lecture et ‚criture */

/*== D‚clarations de types ===========================================*/

typedef struct { unsigned int Handle, RecS, Mode; } NFILE;

/*== Variables globales ==============================================*/

int          NetError;     /* Code d'erreur aprŠs interruption de DOS */
union  REGS  regs;          /* Registres pour g‚rer les interruptions */
struct SREGS sregs;             /* Registres de segment mˆme fonction */

/**********************************************************************/
/* ShareInst    : Test d'installation de Share                        */
/* Entr‚e       : n‚ant                                               */
/* Sortie       : TRUE si Share install‚                              */
/* Var. globale : NetError/W (Code d'erreur)                          */
/**********************************************************************/

int ShareInst( void )
{
 regs.x.ax = FCT_SHARE;                 /* Teste si Share est pr‚sent */
 int86( MULTIPLEX, &regs, &regs );       /* Interruption multiplexeur */
 NetError = NE_OK;                                    /* Pas d'erreur */
 return ( regs.h.al == 0xFF );                 /* D‚termine le retour */
}

/**********************************************************************/
/* NetErrorMsg : Textes des messages d'erreur                         */
/* Entr‚e      : cf infra                                             */
/* Sortie      : cf infra                                             */
/**********************************************************************/

void NetErrorMsg( int  Numero,                       /* Code d'erreur */
          char *Text )                            /* Texte du message */
{
 char Sdummy[ 5 ];                                   /* Code d'erreur */

 switch ( Numero )
 {
  case NE_OK           : strcpy( Text, "Pas d'erreur                  " );
                         break;
  case NE_FileNotFound : strcpy( Text, "Fichier non trouv‚            " );
                         break;
  case NE_PathNotFound : strcpy( Text, "Chemin d'accŠs non trouv‚     " );
                         break;
  case NE_TooManyFiles : strcpy( Text, "Trop de fichiers ouverts      " );
                         break;
  case NE_AccessDenied : strcpy( Text, "AccŠs au fichier refus‚       " );
                         break;
  case NE_InvalidHandle: strcpy( Text, "Handle de fichier non valide  " );
                         break;
  case NE_AccessCode   : strcpy( Text, "Type d'accŠs interdit         " );
                         break;
  case NE_Share        : strcpy( Text, "Violation des rŠgles de Share " );
                         break;
  case NE_Lock         : strcpy( Text, "Erreur de verrouillage        " );
                         break;
  case NE_ShareBuffer  : strcpy( Text, "D‚bordement du buffer de Share" );
                         break;
  default              : {
                          itoa( Numero, Sdummy, 2 );
              strcpy( Text, "Erreur DOS:               " );
                          strcat( Text, Sdummy );
                        }
 }
}

/**********************************************************************/
/* NetReset     : Ouvre un fichier pr‚existant                        */
/* Entr‚es      : cf infra                                            */
/* Sortie       : cf infra                                            */
/* Var. globale : NetError/W (Code d'erreur)                          */
/**********************************************************************/

void NetReset( char far     *FNom,                  /* Nom du fichier */
           unsigned int Mode,                     /* Mode d'ouverture */
           unsigned int RecS,              /* Taille d'enregistrement */
           NFILE        *Fichier )            /* Pointeur sur fichier */
{
 regs.x.dx = FP_OFF( FNom );             /* Adresse du nom du fichier */
 regs.h.ah = FCT_OPEN;      /* Num‚ro de la fonction "Ouvrir fichier" */
 regs.h.al = Mode;                                        /* Attribut */
 sregs.ds  = FP_SEG( FNom );
 intdosx( &regs, &regs, &sregs );                    /* Interruption  */
 if ( !regs.x.cflag )                          /* Ouverture r‚ussie ? */
 {
  Fichier->Handle = regs.x.ax;                  /* M‚morise le handle */
  Fichier->RecS = RecS;                   /* et la taille de l'enreg. */
  switch ( Mode & 0x0F )                   /* Fixe le mode du fichier */
  {
   case FM_R  : Fichier->Mode = FMINPUT;
                break;
   case FM_W  : Fichier->Mode = FMOUTPUT;
                break;
   case FM_RW : Fichier->Mode = FMINOUT;
                break;
  }
  NetError = NE_OK;                                   /* Pas d'erreur */
 }
 else
   NetError = regs.x.ax;                 /* M‚morise le code d'erreur */
}

/**********************************************************************/
/* NetRewrite   : Cr‚e un fichier                                     */
/* Entr‚es      : cf infra                                            */
/* Sortie       : cf infra                                            */
/* Var. globale : NetError/W (Code d'erreur)                          */
/**********************************************************************/

void NetRewrite( char far     *FNom,                /* Nom du fichier */
         unsigned int Mode,                        /* Mode d'ouverture*/
         unsigned int RecS,             /* Taille de l'enregistrement */
                 NFILE        *Fichier )   /* Pointeur sur le fichier */
{
 regs.x.dx = FP_OFF( FNom );             /* Adresse du nom du fichier */
 regs.h.ah = FCT_CREATE;     /* Num‚ro de la fonction "ouvrir fichier"*/
 regs.x.cx = 0 ;                                          /* Attribut */
 sregs.ds  = FP_SEG( FNom );
 intdosx( &regs, &regs, &sregs );                     /* Interruption */
 if ( !regs.x.cflag )                            /* Ouverture r‚ussie */
 {
  regs.x.bx = regs.x.ax;                              /* Handle en BX */
  regs.h.ah = FCT_CLOSE;   /* Num‚ro de la fonction "Fermer fichier " */
  intdos( &regs, &regs );
  if ( !regs.x.cflag )                         /* Op‚ration r‚ussie ? */
    NetReset( FNom, Mode, RecS, Fichier );       /* Rouvre le fichier */
  else
    NetError = regs.x.ax;                /* M‚morise le code d'erreur */
 }
 else
  NetError = regs.x.ax;                  /* M‚morise le code d'erreur */
}

/**********************************************************************/
/* NetClose  : Ferme un fichier                                       */
/* Entr‚es   : cf infra                                               */
/* Sortie    : n‚ant                                                  */
/**********************************************************************/

void NetClose( NFILE *Fichier )                   /* Fichier … fermer */
{
 if ( Fichier->Mode != FMCLOSED )                   /* Fichier ouvert?*/
 {
  regs.x.bx = Fichier->Handle;                   /* Affecte le handle */
  regs.h.ah = FCT_CLOSE;      /* Num‚ro de la fonction "Ferme fichier"*/
  intdos( &regs, &regs );
  if ( !regs.x.cflag )                        /* Fermeture r‚ussie  ? */
  {
   Fichier->Handle = 0;                           /* Efface le handle */
   Fichier->Mode = FMCLOSED;                   /* Fichier ferm‚       */
   NetError = NE_OK;                                  /* Pas d'erreur */
  }
  else
    NetError = regs.x.ax;
 }
 else
  NetError = NE_InvalidHandle;                 /* Fichier non ouvert  */
}

/**********************************************************************/
/* Locking     : Verrouillage ou d‚verrouillage d'une zone de fichier */
/* Entr‚es     : cf infra                                             */
/* Sortie      : true si r‚ussi                                       */
/* Var. globale: NetError/W (Code d'erreur )                          */
/* Info        : Utilisation exclusivement interne r‚serv‚e … NetLock */
/*              et NetUnlock                                          */
/**********************************************************************/

int Locking( int           Handle,               /* Handle du fichier */
         int           Operation,                 /* Type d'op‚ration */
         unsigned long Offset,/*Offset en octets depuis d‚but fichier */
         unsigned long Longueur )    /* Longueur de la zone en octets */
{
 regs.h.ah = FCT_REC_LOCK;    /* Num‚ro de la fonction d'interruption */
 regs.h.al = Operation;       /* 0 = Verrouillage, 1 = D‚verrouillage */
 regs.x.bx = Handle;                             /* Handle du fichier */
 regs.x.cx = Offset >> 16;                    /* Mot fort de l'offset */
 regs.x.dx = Offset & 0xFFFF;               /* Mot faible de l'offset */
 regs.x.si = Longueur >> 16;               /* Mot fort de la longueur */
 regs.x.di = Longueur & 0xFFFF;          /* Mot faible de la longueur */
 intdos( &regs, &regs );                              /* Interruption */
 if ( ! regs.x.cflag )                          /* Op‚ration r‚ussie ?*/
 {
  NetError = NE_OK;
  return TRUE;                                        /* Pas d'erreur */
 }
 else
 {
  NetError = regs.x.ax;                  /* M‚morise le code d'erreur */
  return FALSE;                                             /* Erreur */
 }
}

/**********************************************************************/
/* NetUnLock    : LibŠre des enregistrements verrouill‚s              */
/* Entr‚es      : cf infra                                            */
/* Sortie       : true si r‚ussi                                      */
/* Var. globale : NetError/W (Code d'erreur )                         */
/**********************************************************************/

int NetUnLock( NFILE         *Fichier,                     /* Fichier */
           unsigned long RecNo,            /* Num‚ro d'enregistrement */
           unsigned long Nombre )         /* Nombre d'enregistrements */
{
 return Locking( Fichier->Handle, 1, Fichier->RecS * RecNo,
                 Fichier->RecS * Nombre );
}

/**********************************************************************/
/* NetLock      : Verrouille des enregistrements                      */
/* Entr‚es      : cf infra                                            */
/* Sortie       : true si r‚ussi                                      */
/* Var. globale : NetError/W (Code d'erreur )                         */
/**********************************************************************/

int NetLock( NFILE         *Fichier,                       /* Fichier */
         unsigned long RecNo,              /* Num‚ro d'enregistrement */
         unsigned long Nombre )           /* Nombre d'enregistrements */
{
 return Locking( Fichier->Handle, 0, Fichier->RecS * RecNo,
                 Fichier->RecS * Nombre );
}

/**********************************************************************/
/* Is_NetReadOk : Teste si lecture autoris‚e                          */
/* Entr‚e       : cf infra                                            */
/* Sortie       : true si lecture autoris‚e                           */
/**********************************************************************/

int Is_NetReadOk( NFILE *Fichier )
{
 return ( ( Fichier->Mode == FMINPUT ) ||
          ( Fichier->Mode == FMINOUT ) );
}

/**********************************************************************/
/* Is_NetOpen  : Teste si fichier ouvert                              */
/* Entr‚e      : cf infra                                             */
/* Sortie      : true si fichier ouvert                               */
/**********************************************************************/

int Is_NetOpen( NFILE *Fichier )
{
 return ( ( Fichier->Mode == FMOUTPUT ) ||
          ( Fichier->Mode == FMINPUT ) ||
          ( Fichier->Mode == FMINOUT ) );
}

/**********************************************************************/
/* Is_NetWriteOk : Teste si ‚criture autoris‚e                        */
/* Entr‚e        : cf infra                                           */
/* Sortie        : true si ‚criture autoris‚e                         */
/**********************************************************************/

int Is_NetWriteOk( NFILE *Fichier )
{
 return ( ( Fichier->Mode == FMOUTPUT ) ||
          ( Fichier->Mode == FMINOUT ) );
}

/**********************************************************************/
/* NetWrite : Ecrit des donn‚es dans un fichier                       */
/* Entr‚es  : cf infra                                                */
/* Sortie   : n‚ant                                                   */
/**********************************************************************/

void NetWrite( NFILE     *Fichier,                         /* Fichier */
           void  far *Donnees )              /* Pointeur sur donn‚es  */
{
 regs.x.dx = FP_OFF( Donnees );      /* Adresse de la zone de donn‚es */
 regs.h.ah = FCT_WRITE; /* Num‚ro de la fonction "Ecrire dans fichier"*/
 regs.x.bx = Fichier->Handle;                    /* Handle du fichier */
 regs.x.cx = Fichier->RecS;                        /* Nombre d'octets */
 sregs.ds  = FP_SEG( Donnees );
 intdosx( &regs, &regs, &sregs );
 if ( !regs.x.cflag )
  NetError = NE_OK;                                   /* Pas d'erreur */
 else
  NetError = regs.x.ax;                  /* M‚morise le code d'erreur */
}

/**********************************************************************/
/* NetRead : Lit des donn‚es dans un fichier                          */
/* Entr‚es : cf infra                                                 */
/* Sortie  : n‚ant                                                    */
/**********************************************************************/

void NetRead( NFILE     *Fichier,                          /* Fichier */
          void  far *Donnees )              /* Pointeur sur donn‚es   */
{
 regs.x.dx = FP_OFF( Donnees );     /* Adresse de la zone des donn‚es */
 regs.h.ah = FCT_READ;        /* Num‚ro de la fonction "Lire fichier "*/
 regs.x.bx = Fichier->Handle;                    /* Handle de fichier */
 regs.x.cx = Fichier->RecS;                        /* Nombre d'octets */
 sregs.ds  = FP_SEG( Donnees );
 intdosx( &regs, &regs, &sregs );
 if ( !regs.x.cflag )
  NetError = NE_OK;                                   /* Pas d'erreur */
 else
  NetError = regs.x.ax;                  /* M‚morise le code d'erreur */
}

/**********************************************************************/
/* NetSeek : Positionne le pointeur du fichier x                      */
/* Entr‚es : cf infra                                                 */
/* Sortie  : n‚ant                                                    */
/**********************************************************************/

void NetSeek( NFILE         *Fichier,                      /* Fichier */
              unsigned long RecNo )        /* Num‚ro d'enregistrement */
{
 regs.h.ah = FCT_LSEEK;/* Num‚ro de la fonction "Positionner pointeur"*/
 regs.h.al = 0;                 /* Position absolue … partir du d‚but */
 regs.x.bx = Fichier->Handle;                    /* Handle du fichier */
 RecNo = RecNo * Fichier->RecS;                   /* Offset en octets */
 regs.x.cx = RecNo >> 16;                     /* Mot fort de l'offset */
 regs.x.dx = RecNo & 0xFFFF;                /* Mot faible de l'offset */
 intdos( &regs, &regs );
 if ( !regs.x.cflag )
  NetError = NE_OK;                                   /* Pas d'erreur */
 else
  NetError = regs.x.ax;                  /* M‚morise le code d'erreur */
}
