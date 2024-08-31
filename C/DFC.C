/**********************************************************************/
/*                             D F C                                  */
/*--------------------------------------------------------------------*/
/*    SUJET       : Formate disquettes 3,5" et 5,25"                  */
/*--------------------------------------------------------------------*/
/*    Auteur                : Michael Tischer                         */
/*    D‚velopp‚ le          : 28.08.1991                              */
/*    DerniŠre Modification : 26.01.1992                              */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire: SMALL                                           */
/*--------------------------------------------------------------------*/
/*    Attention       : Le message d'avertissement                    */
/*                      "warning C4059: segment lost in conversion"   */
/*                      du compilateur Microsoft est voulu.           */
/**********************************************************************/

/*== IntŠgre les fichiers include ====================================*/

#include <dos.h>
#include <stdio.h>
#include <string.h>

/*== macros ==========================================================*/

#ifdef MK_FP                            /* macro MK_FP d‚j… d‚finie ? */
  #undef MK_FP                            /* Oui, alors effacer macro */
#endif

#define MK_FP(seg,ofs) ((void far *) ((unsigned long) (seg)<<16|( ofs)))
#define LO( valeur ) ( ( BYTE ) ( valeur & 0xFF ) )
#define HI( valeur ) ( ( BYTE ) ( valeur >> 8 ) )
#define SEG( p ) ( ( unsigned int ) ( ( ( long ) p ) >> 16 ) )
#define OFS( p ) ( ( unsigned int ) ( p ) )

/*== Konstanten ======================================================*/

#define NON         0x4E                                   /* N = NON */
#define NO_DRIVE     0                         /* Lecteur introuvable */
#define DD_525       1                           /* Lecteur: 5,25" DD */
#define HD_525       2                           /* Lecteur: 5,25" HD */
#define DD_35        3                            /* Lecteur: 3,5" DD */
#define HD_35        4                            /* Lecteur: 3,5" HD */

#define EssaisMax  5                       /* Nombre maximal d'essais */

#define TRUE         ( 0 == 0 )         /* les constantes facilitent  */
#define FALSE        ( 1 == 0 )         /* la lecture du listing      */

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;                      /* Type donn‚es Byte */

typedef BYTE DDPTType[ 11 ];                   /* Champ pour une DDPT */
typedef DDPTType *DDPTPTR;                   /* Pointeur sur une DDPT */

typedef struct {                 /* ParamŠtres physiques de formatage */
          BYTE    Faces,                           /* Nombre de Faces */
              Pistes,                              /* Pistes par face */
              Secteurs;                         /* Secteurs par Piste */
          DDPTPTR DDPT;                         /* Pointeur sur DDPTR */
        } PhysDataType;

typedef struct {                  /* ParamŠtres logiques de formatage */
          BYTE Media;                             /* Octet de support */
          BYTE Cluster;                /* Nombre Secteurs par Cluster */
          BYTE FAT;                    /* Nombre Secteurs pour la FAT */
          BYTE RootSize;            /* Entr‚es dans r‚pertoire racine */
        } LogDataType;

typedef BYTE PisteBufType[ 18 ][ 512 ];     /* M‚moire pour une piste */

/*== Variables globales ==============================================*/

/*-- Membre invariable du secteur de boot ----------------------------*/

BYTE Masqueboot[ 102 ] =
           { 0xEB, 0x35,                    /* 0000   JMP 0037        */
             0x90,                          /* 0002   NOP             */
                     /*-- Donn‚es du BPB -----------------------------*/

             0x50, 0x43, 0x49, 0x4E, 0x54, 0x45, 0x52, 0x4E,
             0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00,

                     /*-- Programme de chargement --------------------*/

             0xFA,                          /* 0037   CLI             */
             0xB8, 0x30, 0x00,              /* 0038   MOV     AX,0030 */
             0x8E, 0xD0,                    /* 003B   MOV     SS,AX   */
             0xBC, 0xFC, 0x00,              /* 003D   MOV     SP,00FC */
             0xFB,                          /* 0040   STI             */
             0x0E,                          /* 0041   PUSH    CS      */
             0x1F,                          /* 0042   POP     DS      */
             0xBE, 0x66, 0x7C,              /* 0043   MOV     SI,7C66 */
             0xB4, 0x0E,                    /* 0046   MOV     AH,0E   */
             0xFC,                          /* 0048   CLD             */
             0xAC,                          /* 0049   LODSB           */
             0x0A, 0xC0,                    /* 004A   OR      AL,AL   */
             0x74, 0x04,                    /* 004C   JZ      0052    */
             0xCD, 0x10,                    /* 004E   INT     10      */
             0xEB, 0xF7,                    /* 0050   JMP     0049    */
             0xB4, 0x01,                    /* 0052   MOV     AH,01   */
             0xCD, 0x16,                    /* 0054   INT     16      */
             0x74, 0x06,                    /* 0056   JZ      005E    */
             0xB4, 0x00,                    /* 0058   MOV     AH,00   */
             0xCD, 0x16,                    /* 005A   INT     16      */
             0xEB, 0xF4,                    /* 005C   JMP     0052    */
             0xB4, 0x00,                    /* 005E   MOV     AH,00   */
             0xCD, 0x16,                    /* 0060   INT     16      */
             0x33, 0xD2,                    /* 0062   XOR     DX,DX   */
             0xCD, 0x19 };                  /* 0064   INT     19      */

char BootMes[] =
  "\nDFC  -  (C) 1992 by Michael Tischer\n\n" \
  "Disquette non systŠme ou d‚fectueuse!\n" \
  "Veuillez changer de disquette et taper une touche" \
  "\n\n";

/**********************************************************************/
/* upcase       : Convertit un caractŠre en majuscule                 */
/* Entr‚e       : CaractŠre                                           */
/* Sortie       : Majuscule                                           */
/**********************************************************************/

char upcase( char letter )
{                                                              /* XXX */
 if ( ( letter > 0x60 ) && ( letter < 0x7B ) )         /* convertir ? */
  return (unsigned char) letter & 0xDF;           /* Oui, masquer bit */
 else
  return letter;                           /* NON, retourner tel quel */
}

/**********************************************************************/
/* GetIntVec : lit un vecteur d'interruption                          */
/* Entr‚e    : NUMERO = Num‚ro d'interruption                         */
/* Sortie    : Vecteur d'interruption                                 */
/**********************************************************************/

void far *GetIntVec( int Numero )
{
 return( *( ( void far * far * ) MK_FP( 0, Numero * 4 ) ) );
}

/**********************************************************************/
/* SetIntVec : d‚finit un vecteur d'interruption                      */
/* Entr‚e    : NUMERO = Num‚ro d'interruption                         */
/*             Pointeur = Vecteur d'interruption                      */
/* Sortie    : aucune                                                 */
/**********************************************************************/

void SetIntVec( int Numero, void far *Pointeur )
{
 *( ( void far * far * ) MK_FP( 0, Numero * 4 ) ) = Pointeur;
}

/**********************************************************************/
/* GetDriveType : Retourne le type d'un lecteur de disquettes         */
/* Entr‚e       : DRIVE = Num‚ro de lecteur (0, 1 etc.)               */
/* Sortie       : Codes lecteurs en constantes (DD_525, HD_525 etc.)  */
/**********************************************************************/

BYTE GetDriveType( BYTE Drive )
{
 union REGS regs;      /* Registre processeur pour appel interruption */

 regs.h.ah = 0x08;                  /* Fonction: retourner le lecteur */
 regs.h.dl = Drive;                   /* Appeler le num‚ro lecteur de */
 int86( 0x13, &regs, &regs );                  /* l'interruption BIOS */
 if ( regs.x.cflag )                            /* Erreur … l'appel ? */
  return( DD_525 );           /* Fonct. 0x08 introuvable => XT 360 Ko */
 else
  return( regs.h.bl );                             /* Type de lecteur */
}

/**********************************************************************/
/* ResetDisk : Reset disque sur tous les lecteurs                     */
/* Entr‚e    : aucune                                                 */
/* Sortie    : aucune                                                 */
/* Info      : Ind‚pendamment du num‚ro de lecteur charg‚ dans DL,    */
/*             le Reset est effectu‚ sur tous les lecteurs de         */
/*             disquettes                                             */
/**********************************************************************/

void DiskReset( void )
{
 union REGS regs;      /* Registre processeur pour appel interruption */

 regs.h.ah = 0x00;      /* Num‚ro de fonction pour appel interruption */
 regs.h.dl = 0;                               /* Lecteur a: (s. Info) */
 int86( 0x13, &regs, &regs );                   /* appel interruption */
}

/**********************************************************************/
/* GetFormatParamter : Retourne les paramŠtres logiques et physiques  */
/*                     requis pour le formatage                       */
/* Entr‚e            : FORMSTRING = Pointeur sur chaŒne de format     */
/*                     "360", "720", "1200", "1440"                   */
/*                     DRIVETYPE  = Code lecteur retourn‚ par         */
/*                     GetDriveType()                                 */
/*                     PDATAP     = Pointeur sur structure contenant  */
/*                     les paramŠtres physiques de formatage          */
/*                     LDATAP     = Pointeur sur structure contenant  */
/*                     les paramŠtres logiques de formatage           */
/* Sortie            : TRUE si format possible, sinon  FALSE          */
/* Info              : Vous pouvez ajouter de nouveaux formats en     */
/*                     compl‚tant cette proc‚dure                     */
/**********************************************************************/

BYTE GetFormatParameter( char         *FormString,
             BYTE         DriveType,
             PhysDataType *PDataP,
             LogDataType  *LDataP )

{
 static DDPTType DDPT_360  = { 0xDF, 0x02, 0x25, 0x02, 0x09, 0x2A,
                  0xFF, 0x50, 0xF6, 0x0F, 0x08 };
 static DDPTType DDPT_1200 = { 0xDF, 0x02, 0x25, 0x02, 0x0F, 0x1B,
                  0xFF, 0x54, 0xF6, 0x0F, 0x08 };
 static DDPTType DDPT_1440 = { 0xDF, 0x02, 0x25, 0x02, 0x12, 0x1B,
                  0xFF, 0x6C, 0xF6, 0x0F, 0x08 };
 static DDPTType DDPT_720  = { 0xDF, 0x02, 0x25, 0x02, 0x09, 0x2A,
                  0xFF, 0x50, 0xF6, 0x0F, 0x08 };

 static LogDataType LOG_360  = { 0xFD, 2, 2, 0x70 };
 static LogDataType LOG_1200 = { 0xF9, 1, 7, 0xE0 };
 static LogDataType LOG_720  = { 0xF9, 2, 3, 0x70 };
 static LogDataType LOG_1440 = { 0xF0, 1, 9, 0xE0 };

 static PhysDataType PHYS_360  = { 2, 40,  9, &DDPT_360 };
 static PhysDataType PHYS_1200 = { 2, 80, 15, &DDPT_1200 };
 static PhysDataType PHYS_720  = { 2, 80,  9, &DDPT_720 };
 static PhysDataType PHYS_1440 = { 2, 80, 18, &DDPT_1440 };

/*-- Lire le format dans la chaŒne et stocker les donn‚es dans les ---*/
/*-- structures indiqu‚es                                          ---*/

 if ( strcmp( FormString, "1200" ) == 0 )        /* 1,2 MB sur 5,25"? */
   if ( DriveType == HD_525 )     /* Format compatible avec lecteur ? */
    {
     memcpy( PDataP, &PHYS_1200, sizeof( PhysDataType ) );
     memcpy( LDataP, &LOG_1200, sizeof ( LogDataType ) );
     return TRUE;                              /* Termin‚ sans erreur */
    }
    else
     return( FALSE );              /* Lecteur et format incompatibles */
  else if ( strcmp( FormString, "360" ) == 0 )            /* 360 Ko ? */
   if ( ( DriveType == HD_525 ) || ( DriveType == DD_525 ) )
    {         /* Format et lecteur compatibles, renseigner paramŠtres */
     memcpy ( PDataP, &PHYS_360, sizeof( PhysDataType ) );
     memcpy ( LDataP, &LOG_360, sizeof ( LogDataType ) );
     return TRUE;                                  /* Fin sans erreur */
    }
    else
     return( FALSE );              /* Lecteur et format incompatibles */
  else if ( strcmp( FormString, "1440" ) == 0 )  /* 1,44 MB auf 3,5"? */
   if ( DriveType == HD_35 )        /* Lecteur et format compatibles? */
    {                     /* Lecteur et format compatibles, Parametre */
     memcpy ( PDataP, &PHYS_1440, sizeof( PhysDataType ) );
     memcpy ( LDataP, &LOG_1440, sizeof ( LogDataType ) );
     return TRUE;                                  /* Fin sans erreur */
    }
    else
     return( FALSE );              /* Lecteur et format incompatibles */
  else if ( strcmp( FormString, "720" ) == 0 )    /* 720 KB auf 3,5"? */
    if ( ( DriveType == HD_35 ) || ( DriveType == DD_35 ) )
    {         /* Lecteur et format compatibles, renseigner paramŠtres */
     memcpy ( PDataP, &PHYS_720, sizeof( PhysDataType ) );
     memcpy ( LDataP, &LOG_720, sizeof ( LogDataType ) );
     return TRUE;                                  /* Fin sans erreur */
    }
    else
     return FALSE;                 /* Lecteur et format incompatibles */
  else
    return FALSE;                   /* Le format demand‚ est invalide */
}

/**********************************************************************/
/* DiskPrepare: Pr‚pare le lecteur, paramŠtre la vitesse de transfert */
/* Entr‚e     : DRIVE = Num‚ro de lecteur                             */
/*              PDATA = Table des paramŠtres physiques                */
/* Sortie     : aucune                                                */
/**********************************************************************/

void DiskPrepare( BYTE Drive, PhysDataType PData )
{
 union REGS regs;      /* Registre processeur pour appel interruption */

 /*-- Type de support pour appel formatage ---------------------------*/

 regs.h.ah = 0x18;     /*  Num‚ro de fonction pour appel interruption */
 regs.h.ch = PData.Pistes - 1;              /* Nombre Pistes par Face */
 regs.h.cl = PData.Secteurs;             /* Nombre Secteurs par Piste */
 regs.h.dl = Drive;                              /* Num‚ro de lecteur */
 int86( 0x13, &regs, &regs );                   /* appel interruption */
}

/**********************************************************************/
/* FormatTrack: Formate une piste                                     */
/* Entr‚e    : voir plus loin                                         */
/* Sortie    : Les statistiques d'erreurs                             */
/**********************************************************************/

BYTE FormatTrack( BYTE Lecteur,                  /* Num‚ro de lecteur */
          BYTE Face,                                /* Num‚ro de face */
          BYTE Piste,                                     /* la piste */
          BYTE Nombre )           /* Nombre Secteurs pour cette piste */

{
 struct FormatTyp {       /* Informations sur le secteur pour le BIOS */
          BYTE DPiste, DFace, DCompteur, DLongueur;
         };

 BYTE             essais;/* Nombre tentatives pour appel interruption */
 BYTE             Compteur;                  /* compteur d'it‚rations */
 struct FormatTyp Champdonn[ 18 ];                /* 18 Secteurs maxi */
 void far *       dfp = Champdonn;   /* Pointeur sur champ de donn‚es */
 union REGS       regs;  /* Registre processeur pr appel interruption */
 struct SREGS     sregs;                           /* Segmentregister */

 for ( Compteur = 0; Compteur < Nombre; Compteur++ )
  {
   Champdonn[ Compteur ].DPiste = Piste;
   Champdonn[ Compteur ].DFace = Face;
   Champdonn[ Compteur ].DCompteur = Compteur + 1;
   Champdonn[ Compteur ].DLongueur = 2;     /* 512 octets par Secteur */
  }

 essais = EssaisMax;            /* D‚finir le nombre maximal d'essais */
 do
  {
   regs.h.ah = 5;       /* Num‚ro de fonction pour appel interruption */
   regs.h.al = Nombre;                /* Nombre de secteurs par piste */
   regs.x.bx = OFS( dfp );                 /* Offsetadresse du tampon */
   sregs.es = SEG( dfp );                          /* Adresse segment */
   regs.h.dh = Face;                             /* Num‚ro de la face */
   regs.h.dl = Lecteur;                          /* Num‚ro de lecteur */
   regs.h.ch = Piste;                           /* Num‚ro de la piste */
   int86x( 0x13, &regs, &regs, &sregs );   /* Appel interruption BIOS */
   if ( regs.x.cflag )                                     /* Erreur? */
     DiskReset();
  }
 while ( ( --essais != 0 ) && ( regs.x.cflag ) );
 return( regs.h.ah );                              /* Lit ‚tat erreur */
}

/**********************************************************************/
/* VerifyTrack : V‚rifie la piste                                     */
/* Entr‚e      : voir plus loin                                       */
/* Sortie      : ‚tat erreur                                          */
/**********************************************************************/

BYTE VerifyTrack( BYTE Lecteur,                  /* Num‚ro de lecteur */
          BYTE Face,                                /* Num‚ro de face */
          BYTE Piste,                                 /* Num‚ro piste */
          BYTE Secteurs )                /* Nombre Secteurs par Piste */

{
 BYTE         essais;        /* Nombre essais pour appel interruption */
 union REGS   regs;    /* Registre processeur pour appel interruption */
 struct SREGS sregs;  /* Registre pocess. appel ‚tendu d'interruption */
 PisteBufType sbuf;                                   /* Tampon piste */
 void far     *sbptr = sbuf;         /* Pointeur FAR sur tampon piste */

 essais = EssaisMax;           /* D‚finir le nombre limite des essais */
 do
  {
   regs.h.ah = 0x04;    /* Num‚ro de fonction pour appel interruption */
   regs.h.al = Secteurs;                 /* Nombre Secteurs par Piste */
   regs.h.ch = Piste;                           /* Num‚ro de la piste */
   regs.h.cl = 1;                            /* Commence au Secteur 1 */
   regs.h.dl = Lecteur;                          /* Num‚ro de lecteur */
   regs.h.dh = Face;                             /* Num‚ro de la face */
   regs.x.bx = OFS( sbptr );              /* Adresse Offset du tampon */
   sregs.es = SEG( sbptr );                        /* Adresse Segment */
   int86x( 0x13, &regs, &regs, &sregs );   /* Appel interruption BIOS */
   if ( regs.x.cflag )                                     /* Erreur? */
     DiskReset();
  }
 while ( ( --essais != 0 ) && ( regs.x.cflag ) );
 return( regs.h.ah );                             /* Lire ‚tat erreur */
}

/**********************************************************************/
/* WriteTrack: Ecrire piste                                           */
/* Entr‚e   : voir ci-dessous                                         */
/* Sortie   : Code erreur (0=OK)                                      */
/**********************************************************************/

BYTE WriteTrack( BYTE Lecteur,                   /* Num‚ro de lecteur */
         BYTE Face,                              /* Num‚ro de la face */
         BYTE Piste,                            /* Num‚ro de la piste */
         BYTE Start,                       /* Commence par le secteur */
         BYTE Secteurs,                  /* Nombre Secteurs par Piste */
         void far *Donnees )         /* Pointeur sur champ de donn‚es */

{
 BYTE essais;                /* Nombre essais pour appel interruption */
 union REGS regs;      /* Registre processeur pour appel interruption */
 struct SREGS sregs;    /* Registre processeur pour appel ‚tendu int. */

 essais = EssaisMax;                  /* D‚finir nombre maxi d'essais */
 do
  {
   regs.h.ah = 0x03;    /* Num‚ro de fonction pour appel interruption */
   regs.h.al = Secteurs;                 /* Nombre Secteurs par Piste */
   regs.h.ch = Piste;                           /* Num‚ro de la piste */
   regs.h.cl = Start;                     /* Commencer par le secteur */
   regs.h.dl = Lecteur;                          /* Num‚ro de lecteur */
   regs.h.dh = Face;                             /* Num‚ro de la face */
   regs.x.bx = OFS( Donnees );            /* Adresse Offset du buffer */
   sregs.es = SEG( Donnees );                      /* Adresse Segment */
   int86x( 0x13, &regs, &regs, &sregs );/* Appel interruption du BIOS */
   if ( regs.x.cflag )                                     /* Erreur? */
     DiskReset();
  }
 while ( ( --essais != 0 ) && ( regs.x.cflag ) );
 return( regs.h.ah );                             /* Lire ‚tat erreur */
}

/**********************************************************************/
/* PhysicalFormat : Formatage physique de la disquette (‚criture des  */
/*                  pistes et des secteurs)                           */
/* Entr‚e         : voir ci-dessus                                    */
/* Sortie         : Formatage termin‚ sans errreur                    */
/**********************************************************************/

BYTE PhysicalFormat( BYTE         Drive,         /* Num‚ro de lecteur */
             PhysDataType PData,              /* ParamŠtres physiques */
             BYTE         Verify )                  /* Flag de Verify */

{
 union REGS regs;      /* Registre processeur pour appel interruption */
 BYTE       essais,        /* Nombre d'essais pour appel interruption */
        Piste,                /* Compteur it‚rations : Piste courante */
        Face,                  /* Compteur it‚rations : face courante */
        Status;           /* VAleur retourn‚e par la fonction appel‚e */

 /*-- Formatage de la disquette piste par piste ----------------------*/

 for ( Piste = 0; Piste < PData.Pistes; Piste++ )
  for ( Face = 0; Face < PData.Faces; Face++ )
   {
    printf( "\rPiste: %d  Face: %d", Piste, Face );
     /*-- Maximal 5 essais de formatage d'une piste ------------------*/

    essais = EssaisMax;            /* D‚finir nombre maximal d'essais */
    do
     {
      Status = FormatTrack( Drive, Face, Piste, PData.Secteurs );
      if ( Status == 3 )    /* Disquette prot‚g‚e contre l'‚criture ? */
       {
     printf( "\rDisquette prot‚g‚e contre l'‚criture" );
     return FALSE;                   /* Proc‚dure termin‚e sur erreur */
       }
      if ( Status == 0  &&  Verify )
       Status = VerifyTrack( Drive, Face, Piste, PData.Secteurs );
      if ( Status > 0 )                      /* Le formatage a ‚chou‚ */
       DiskReset();
     }
    while ( ( --essais != 0 ) && ( Status != 0 ) );
    if ( Status > 0 )                 /*  Erreur pendant le formatage */
     {
      printf( "\rPiste Erreur?       \n" );
      return FALSE;                  /* Proc‚dure termin‚e sur erreur */
     }
   }
 return TRUE;                       /* Proc‚dure termin‚e sans erreur */
}

/**********************************************************************/
/* LogicalFormat : Formatage logique de la disquette : ‚criture des   */
/*                 secteurs de boot, des FAT et du r‚pertoire racine  */
/* Entr‚e        : voir ci-dessous                                    */
/* Sortie        : TRUE si aucune erreur apparue                      */
/**********************************************************************/

BYTE LogicalFormat( BYTE Drive,                  /* Num‚ro de lecteur */
            PhysDataType PData,               /* ParamŠtres physiques */
            LogDataType LData )                /* ParamŠtres logiques */

{
 BYTE        i,                              /* Compteur d'it‚rations */
         AktSector,
         AktSide,
         AktTrack,
         Status;
 int         TousSecteurs,                /* Nombre total de secteurs */
         Nombre;               /* Nombre de secteurs restant … ‚crire */
 PisteBufType TamponPiste;                /* stocke une piste entiŠre */

 memset(TamponPiste,0,(int) PData.Secteurs * 512 ); /* Vider la piste */

 /*-- Secteur de boot : partie fixe  ---------------------------------*/

 memcpy( TamponPiste, Masqueboot, 102 );/* Copie masque du sect. boot */
 memcpy( &TamponPiste[ 0 ][ 102 ], BootMes, sizeof( BootMes) );
 TamponPiste[ 0 ][ 510 ] = 0x55;   /* Signe de fin du secteur de boot */
 TamponPiste[ 0 ][ 511 ] = 0xAA;

 /*-- Secteur de boot : partie variable ------------------------------*/

 TousSecteurs = (int) PData.Pistes * (int) PData.Secteurs *
          (int) PData.Faces;              /* Nombre total de secteurs */
 TamponPiste[ 0 ][ 13 ] = LData.Cluster;            /* taille cluster */
 TamponPiste[ 0 ][ 17 ] = LData.RootSize; /* Nbre entr‚es ds r‚p. rac.*/
 TamponPiste[ 0 ][ 19 ] = LO( TousSecteurs );
 TamponPiste[ 0 ][ 20 ] = HI( TousSecteurs );
 TamponPiste[ 0 ][ 21 ] = LData.Media;         /* Descripteur support */
 TamponPiste[ 0 ][ 22 ] = LData.FAT;            /* Longueur de la FAT */
 TamponPiste[ 0 ][ 24 ] = PData.Secteurs;       /* Secteurs par Piste */
 TamponPiste[ 0 ][ 26 ] = PData.Faces;             /* Nombre de faces */

 /*-- Cr‚er FAT et la copier -----------------------------------------*/

 TamponPiste[ 1 ][ 0 ] = LData.Media;            /* Cr‚ation 1Šre FAT */
 TamponPiste[ 1 ][ 1 ] = 0xFF;
 TamponPiste[ 1 ][ 2 ] = 0xFF;
 TamponPiste[ LData.FAT + 1 ][ 0 ] = LData.Media;/* Cr‚ation 2Šme FAT */
 TamponPiste[ LData.FAT + 1 ][ 1 ] = 0xFF;
 TamponPiste[ LData.FAT + 1 ][ 2 ] = 0xFF;

 /*-- Ecrire secteur de boot et FAT ----------------------------------*/

 Status = WriteTrack( Drive, 0, 0, 1, PData.Secteurs, TamponPiste );
 if ( Status )                                /* Erreur en ‚criture ? */
  return FALSE;                              /* OUI! Retourner Erreur */

 /*-- Ecriture r‚pertoire racine -------------------------------------*/

 memset( TamponPiste, 0, 512 );                       /* Secteur vide */
 AktSector = PData.Secteurs;     /* PremiŠre piste entiŠrement ‚crite */
 AktTrack = 0;                                      /* Piste courante */
 AktSide = 0;                                        /* Face courante */

   /*-- Retourner le nombre des secteurs retants et les ‚crire  ------*/

 Nombre = LData.FAT * 2 + (LData.RootSize*32/512) + 1-PData.Secteurs;

 for ( i = 1; i <= Nombre; i++ )
  {
   if ( ++AktSector > PData.Secteurs )           /* Fin de la piste ? */
    {
     AktSector = 1;                         /* Commencer au secteur 1 */
     if ( ++AktSide == PData.Faces )               /* d‚j… 2Šme face? */
      {
       AktSide = 0;                             /* Retour … la face 0 */
       AktTrack++;
      }
    }
   Status = WriteTrack( Drive, AktSide, AktTrack,
            AktSector, 1, TamponPiste );
   if ( Status )                                           /* Erreur? */
    break;                /* Oui, quitter pr‚matur‚ment la boucle FOR */
  }
 return ( Status == 0 );
}

/**********************************************************************/
/*                   PROGRAMM PRINCIPAL                               */
/**********************************************************************/

int main( argc, argv )

int argc;                /* Nombre d'argumenta dans ligne de commande */
char *argv[];                                  /* Champ de paramŠtres */

{
 BYTE         AktDrive;               /* Num‚ro du lecteur … formater */
 BYTE         AktDriveType;  /* Type du lecteur de disquettes courant */
 PhysDataType PData;             /* ParamŠtres physiques de formatage */
 LogDataType  LData;              /* ParamŠtres logiques de formatage */
 void far     *AncDDPT;                   /* Pointeur sur ancien DDPT */
 char         *Param;      /* pour ‚valuation de la ligne de commande */
 BYTE         ok;              /* Drapeau pour ex‚cution du programme */
 int          ExitCode;

 printf( "DFC  -  (c) 1992 by Michael Tischer\n\n" );

 /*-- Evaluation lignme de commande ----------------------------------*/

 if ( argc > 1 )                                /* Donn‚ paramŠtres ? */
  {                                                            /* Oui */
    Param = argv[ 1 ];         /* Retourne lecteur ( 0 = a:, 1 = b: ) */
    AktDrive = upcase( Param[ 0 ] ) - 65;
    AktDriveType = GetDriveType( AktDrive );  /* Type lecteur courant */
    if ( AktDriveType > 0 )                      /* Lecteur existant? */
     if (GetFormatParameter( argv[ 2 ], AktDriveType, &PData, &LData ))
      {
       DiskPrepare( AktDrive, PData );
       AncDDPT = GetIntVec( 0x1E );            /* Stocker ancien DDPT */
       SetIntVec( 0x1E, PData.DDPT );         /* D‚finir nouveau DDPT */

       Param = argv[ 3 ];
       if ( ok = PhysicalFormat( AktDrive, PData,
         (BYTE) ( upcase( Param[ 0 ] ) != 'N' ) ) )
    {
     printf( "\rEcriture du secteur de boot et de la FAT      \n" );
     ok = LogicalFormat( AktDrive, PData, LData );
    }

       /*-- Evaluation du formatage ----------------------------------*/

       if ( ok )
    {
     printf( "\rFormatage o.k.              \n" );
     ExitCode = 0;                  /* Programme quitt‚ sans problŠme */
    }
       else
    {
     printf( "\rUne erreur a interrompu le formatage\n ");
     ExitCode = 1;            /* Une erreur a interrompu le formatage */
    }
       SetIntVec( 0x1E, AncDDPT );            /* Restaure ancien DDPT */
      }
     else
      {
       printf( "Le format demand‚ ne peut pas " \
           "ˆtre utilis‚ sur ce lecteur!\n" );
       ExitCode = 2;               /* Lecteur et format incompatibles */
      }
    else
     {
      printf( "Le lecteur indiqu‚ n'existe pas!\n" );
      ExitCode = 3;                            /* Lecteur introuvable */
     }
  }
 else
   {
    printf( "\rAppel: DFC Lecteur    Format   [ NV ]\n" );
    printf( "\r            ³          ³          ³\n" );
    printf( "\r            ³          ³          ³\n" );
    printf( "\r   A: ou B: ³          ³          ³\n" );
    printf( "\r                       ³          ³\n" );
    printf( "\r  360, 720, 1200, 1440 ³          ³\n" );
    printf( "\r                                  ³\n" );
    printf( "\r               NV = pas de Verify ³\n" );
    ExitCode = 4;                                     /* Appel erron‚ */
   }
 return( ExitCode );        /* Termine programme par valeur de retour */
}
