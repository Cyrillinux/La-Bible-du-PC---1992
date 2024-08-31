/***********************************************************************
*                                E X T C . C                           *
**--------------------------------------------------------------------**
*  D‚monstration de l'accŠs … la m‚moire ‚tendue par les fonctions     *
*  BIOS de l'interruption 15h, en g‚rant les disques virtuels          *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  d‚velopp‚ le     : 18.05.1989                                       *
*  DerniŠre m. … j. : 19.02.1992                                       *
**--------------------------------------------------------------------**
*  ModŠle de m‚moire: SMALL                                            *
**--------------------------------------------------------------------**
*  Microsoft C      : Le message d'avertissement "Segment lost in      *
*                     conversation" est malheureusement in‚vitable     *
***********************************************************************/

/*-- Int‚grer les fichiers Include -----------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <dos.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;             /* nous fabriquons notre Byte */
typedef unsigned int WORD;
typedef BYTE BOOL;                         /* comme BOOLEAN en Pascal */

#define TRUE  ( 0 == 0 )
#define FALSE ( 0 == 1 )

/*-- Macros ----------------------------------------------------------*/

#ifndef __TURBOC__
  #define random(x) rand()
  #define randomize() srand(1)
#endif

/*-- Variables globales ----------------------------------------------*/

int  RdLen;                          /* Taille disques virtuels en Ko */
BOOL ExtAvail;                         /* M‚moire ‚tendue disponible? */
long ExtStart;        /* Adresse m‚moire ‚tendue -> adresse lin‚aire. */
int  ExtLen;                          /* Taille m‚moire ‚tendue en Ko */

/***********************************************************************
*  ExtAdrConv : Convertit un pointeur FAR en adresse lin‚aire de 32    *
*               bits qui est retourn‚e sous forme d'un long            *
**--------------------------------------------------------------------**
*  Entr‚e : Adr = Le pointeur … convertir                              *
*  Sortie : l'adresse convertie                                        *
***********************************************************************/

long ExtAdrConv( void far *Adr )
{
  return( (((long) Adr >> 16) << 4 ) + (unsigned int) Adr );
}

/***********************************************************************
*  ExtCopy : Copie des donn‚s entre deux tampons quelconques dans la   *
*            limite adressable de 16 Mo des 80286/i386/i486.           *
**--------------------------------------------------------------------**
*  Entr‚e :  Start = Adresse du tampon Start en adresse lin. 32 bits   *
*            But   = Adresse du tampon But en adresse lin‚aire 32 bits *
*            Len   = nombre des octets … copier                        *
*  Sortie : aucune                                                     *
*  Info   : Le nombre d'octets … copier doit ˆtre pair                 *
***********************************************************************/

void ExtCopy( long Start, long But, WORD Len )
{
 /*-- Structures de donn‚es servant … l'accŠs … la m‚moire ‚tendue ---*/

 typedef struct {                              /* Descripteur segment */
                 WORD Longueur,      /* Longueur du segment en octets */
                      AdrLo;         /* Bits 0 … 15 de l'adr. du segm.*/
                 BYTE AdrHi,        /* Bits 16 … 23 de l'adr. du segm */
                      Attribut;                /* Attribut du segment */
                 WORD Res;                    /* R‚serv‚ pour le i386 */
               } SDES;

 typedef struct {                          /* Global Descriptor Table */
                 SDES Dummy,
                      GDTS ,
                      Start,                         /* Copier de ... */
                      But ,                               /* ... vers */
                      Code ,
                      Stack;
                } GDT;

 #define LOWORD(x) ((unsigned int) (x))
 #define HIBYTE(x) (*((BYTE *)&x+2))

 GDT          GTab;                        /* Global Descriptor Table */
 union REGS   Regs;       /* Registres process. pr appel interruption */
 struct SREGS SRegs;                             /* Registres segment */
 long         Adr;                    /* pour conversion de l'adresse */

 memset( &GTab, 0, sizeof GTab );              /* Tous les champs … 0 */

  /*-- Construction du descripteur du segment Start ------------------*/

 GTab.Start.AdrLo      = LOWORD(Start);
 GTab.Start.AdrHi      = HIBYTE(Start);
 GTab.Start.Attribut   = 0x92;
 GTab.Start.Longueur   = Len;

    /*-- Construction du descripteur du segment But ------------------*/

 GTab.But.AdrLo    = LOWORD(But);
 GTab.But.AdrHi    = HIBYTE(But);
 GTab.But.Attribut = 0x92;
 GTab.But.Longueur = Len;

 /*-- Copie de blocs de m‚moire … l'aide de la fonction 0x87 de  -----*/
 /*-- Interruption 0x15 pour cassettes                           -----*/

 Regs.h.ah = 0x87;              /* Nø de la fonction 'copier m‚moire' */
 SRegs.es  = (long) (void far *) &GTab >> 16;       /* Adresse du GDT */
 Regs.x.si = (int) &GTab;                              /* aprŠs ES:SI */
 Regs.x.cx = Len >> 1;            /* Nombre des mots … copier dans CX */
 int86x( 0x15, &Regs, &Regs, &SRegs );            /* Appeler fonction */
 if( Regs.h.ah )                                           /* Erreur? */
 {                               /* Oui, AH contient un code d'erreur */
   printf( "\nErreur pendant l'accŠs … la m‚moire ‚tendue (%d)\n",
              Regs.h.ah);
   exit( 1 );           /* Quitter le programme avec le code d'erreur */
 }
}

/***********************************************************************
*  ExtRead : Copie un certain nombre d'octets de la m‚moire ‚tendue    *
*            dans la m‚moire principale.                               *
**--------------------------------------------------------------------**
*  Entr‚e : ExtAdr = Adresse source (lin‚aire) dans m‚moire ‚tendue    *
*           BuPtr  = Pointeur sur le tampon Butdans m‚moire principale *
*           Len    = Nombre des octets … copier                        *
*  Sortie : aucune                                                     *
***********************************************************************/

void ExtRead( long  ExtAdr,  void far *BuPtr, WORD Len )
{
  ExtCopy( ExtAdr, ExtAdrConv( BuPtr ), Len );
}

/***********************************************************************
*  ExtWrite : Copie un certain nombre d'octets de la m‚moire principale*
*             dans la m‚moire ‚tendue.                                 *
**--------------------------------------------------------------------**
*  Entr‚e : BuPtr  = Pointeur sur tampon source dans m‚moire principale*
*           ExtAdr = Adresse But (lin‚aire) en m‚moire ‚tendue         *
*           Len    = Nombre d'octets … copier                          *
*  Sortie : aucune                                                     *
***********************************************************************/

void ExtWrite( void far *BuPtr, long ExtAdr, WORD Len)
{
  ExtCopy( ExtAdrConv( BuPtr ), ExtAdr, Len );
}

/***********************************************************************
*  ExtGetInfo : Retourne l'adresse de la m‚moire ‚tendue et sa taille  *
*               en tenant compte des ‚ventuels disques virtuels de     *
*               type VDISK s'y trouvant                                *
**--------------------------------------------------------------------**
*  Entr‚e : aucune                                                     *
*  Sortie : aucune                                                     *
*  Globals : ExtAvail/W, ExtStart/W, ExtLen/W                          *
***********************************************************************/

void ExtGetInfo( void )
{
 typedef struct {                 /* Secteur boot d'un disque virtuel */
                 BYTE dummy1[3];
                 char Name[5];
                 BYTE dummy2[3];
                 WORD BpS;
                 BYTE dummy3[6];
                 WORD Secteurs;
                 BYTE dummy4;
                } BOOT_SECTEUR;

 static char VDiskName[5] = { 'V', 'D', 'I', 'S', 'K' };

 BOOT_SECTEUR BootSek;            /* copie le secteur de boot suppos‚ */
 union REGS   Regs;       /* Registres process. pr appel interruption */

 /*-- Demander la taille de la m‚moire ‚tendue et en d‚duire la  -----*/
 /*-- la pr‚sence ‚ventuelle de m‚moire ‚tendue                      -*/

 Regs.h.ah = 0x88;                /* nø fonc. : "renvoyer taille XMS" */
 int86( 0x15, &Regs, &Regs );        /* Appeler interruption Cassette */
 if( Regs.x.ax == 0 )
 {                                              /* Pas de RAM ‚tendue */
   ExtAvail = FALSE;
   ExtLen   = ExtStart = 0;
   return;                                     /* Retour … l'appelant */
 }

 ExtAvail = TRUE;                       /* M‚moire ‚tendue disponible */
 ExtLen   = Regs.x.ax;          /* copier sa taille dans une variable */

 /*-- Rechercher disques virtuels type VDISK -------------------------*/

 ExtStart = 0x100000l;                             /* Si 1 Mo, lancer */
 while( TRUE )                                /* boucle interrogation */
 {
   ExtRead( ExtStart, &BootSek, sizeof BootSek );
   if( memcmp( BootSek.Name, VDiskName,
       sizeof VDiskName ) == 0 )   /* Secteur boot de disque virtuel? */
     ExtStart += (long) BootSek.Secteurs * BootSek.BpS;        /* Oui */
   else
     break;                                         /* Quitter boucle */
 }

  /*-- Soustraire tailles des disques virtuels de la m‚moire ---------*/
  /*-- ‚tendue disponible --------------------------------------------*/

  ExtLen -= (int) ((ExtStart - 0x100000l) >> 10);
}

/***********************************************************************
*  CheckExt : V‚rifie que la m‚moire ‚tendue disponible d'un seul bloc *
**--------------------------------------------------------------------**
*  Entr‚e : aucune                                                     *
*  Sortie : aucune                                                     *
***********************************************************************/

void CheckExt( void )
{
 long  AdrTest;                               /* Adresse du bloc test */
 int   i, j;                                 /* Compteur d'it‚rations */
 BYTE  WriteBuf[1024],                                 /* Blocs tests */
       ReadBuf[1024];
 BOOL  Erreur = FALSE;                     /* Pointeur erreur m‚moire */

 randomize();                  /* Initialiser g‚n‚rateur nbres al‚at. */
 AdrTest = ExtStart;
 for( i = 1; i <= ExtLen; ++i, AdrTest += 1024 )
 {                                  /* Lire m‚moire par blocs de 1 Ko */
   for ( j = 0; j < 1024; )       /* Remplir bloc de nbres al‚atoires */
     WriteBuf[ j++ ] = random( 255 );

   printf("\r%ld", AdrTest );                /* Adresse du bloc test‚ */

            /*-- Copier dans tampon WriteBuf et ensuite lire ReadBuf -*/

   ExtWrite( WriteBuf, AdrTest, 1024 );
   ExtRead( AdrTest, ReadBuf, 1024 );

     /*-- D‚terminer l'identit‚ de WriteBuf et de ReadBuf ------------*/

   for( j = 0; j < 1024; ++j )  /* Remplir bloc avec nbres al‚atoires */
     if( WriteBuf[j] != ReadBuf[j] )     /* Contenu tampon identique? */
     {                                                /* Non, erreur! */
       printf( "\n  Erreur! Adresse %ld\n", AdrTest + j - 1);
       Erreur = TRUE;
     }
 }                                                         /* d‚finir */
 printf( "\n\n" );
 if( !Erreur )                                    /* Erreur apparue ? */
   printf( "C'est bon !\n" );                                  /* Non */
}

/***********************************************************************
*  P R O G R A M M E   P R I N C I P A L                               *
***********************************************************************/

void main( void )
{
 printf ("EXTC - (c) 1989, 92 by Michael Tischer\n\n");
 ExtGetInfo();     /*Donne disponibilit‚ et taille de m‚moire ‚tendue */
 if( ExtAvail )                         /* M‚moire ‚tendue es-tu l… ? */
 {                                                            /* Oui! */
   RdLen = (int) ( (ExtStart - 0x100000l ) >> 10 );
   if( RdLen == 0 )                           /* RAM disks install‚s? */
     printf( "Aucun disque virtuel install‚.\nLa m‚moire ‚tendue"\
             " disponible commence … la limite du 1er Mo.\n" );
   else                           /* Mais oui, il y a des RAM disks ! */
     printf("Un ou plusieurs RAM disks occupent %d Ko de la m‚moire "\
            "‚tendue.\nLa m‚moire ‚tendue libre commence %d Ko aprŠs"\
            "la limite du 1er Mo.\n", RdLen, RdLen);
    printf( "Taille de la m‚moire ‚tendue libre : %d Ko\n", ExtLen);
    printf( "\nTest de la continuit‚ de la m‚moire ‚tendue en"\
            " cours...\n\n" );
    CheckExt();
 }
 else
   printf( "Pas de m‚moire ‚tendue dans votre ordinateur !\n" );
}
