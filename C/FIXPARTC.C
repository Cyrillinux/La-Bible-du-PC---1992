/**********************************************************************/
/*                          F I X P A R T C . C                       */
/*--------------------------------------------------------------------*/
/*    Sujet          : Affiche les partitions d'un disque dur         */
/*--------------------------------------------------------------------*/
/*    Auteur          : MICHAEL TISCHER                               */
/*    d‚velopp‚ le    : 26.04.1989                                    */
/*    derniŠre m. … j.: 12.01.1992                                    */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire : SMALL                                          */
/*--------------------------------------------------------------------*/
/*    Appel          : FIXPARTC [ num‚ro de lecteur]                  */
/*                     Le lecteur par d‚faut est le 0 ("C")           */
/**********************************************************************/

#include <dos.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/*== Constantes ======================================================*/

#define TRUE  ( 1 == 1 )
#define FALSE ( 1 == 0 )

/*== Macros ==========================================================*/

#define HI(x) ( *((BYTE *) (&x)+1) )    /* Retourne HI BYTE d'un WORD */
#define LO(x) ( *((BYTE *) &x) )        /* Retourne LO BYTE d'un WORD */

/*== D‚clarations des types ==========================================*/

typedef unsigned char BYTE;
typedef unsigned int WORD;

typedef struct {                 /* fournit la position d'un secteur  */
                BYTE Tete;                   /* Tˆte lecture/‚criture */
                WORD SecCyl;          /* Nø de secteur et de cylindre */
               } SECPOS;

typedef struct {               /* Entr‚e dans la table des partitions */
                BYTE          Status;            /* ‚tat de partition */
                SECPOS        StartSec;            /* premier secteur */
                BYTE          PartTyp;           /* type de partition */
                SECPOS        EndSec;              /* dernier secteur */
                unsigned long SecOfs;    /* Offset du secteur de boot */
                unsigned long NbreSec;          /* Nombre de secteurs */
               } PARTENTRY;

typedef struct {                   /* Fournit le secteur de partition */
                BYTE      BootCode[ 0x1BE ];
                PARTENTRY PartTable[ 4 ];
                WORD      IdCode;                           /* 0xAA55 */
               } PARTSEC;

typedef PARTSEC far *PARSPTR; /* Pointeur sur secteur partit. en m‚m. */

/**********************************************************************/
/*  ReadPartSec : Copie un secteur de partition du disque dur dans un */
/*                tampon                                              */
/*  Entr‚e : - Lecteur  : Code BIOS du lecteur (0x80, 0x81 etc.)      */
/*           - Tete     : Num‚ro de tˆte de lecture/‚criture          */
/*           - SecCyl   : nø de secteur et de cylindre au format BIOS */
/*           - Tamp      : tampon dans lequel le secteur est charg‚   */
/*  Sortie : TRUE si lecture correcte du secteur sinon FALSE          */
/**********************************************************************/

BYTE ReadPartSec( BYTE Lecteur, BYTE Tete, WORD SecCyl, PARSPTR Tamp )

{
 union REGS   Regs;   /* Registres processeur pour appel interruption */
 struct SREGS SRegs;

 Regs.x.ax = 0x0201;            /* Nøde fonction de "Read", 1 secteur */
 Regs.h.dl = Lecteur;                 /* Charge les autres paramŠtres */
 Regs.h.dh = Tete;                              /* dans les registres */
 Regs.x.cx = SecCyl;
 Regs.x.bx = FP_OFF( Tamp );
 SRegs.es  = FP_SEG( Tamp );

 int86x( 0x13, &Regs, &Regs, &SRegs );   /* appel interruption d. dur */
 return !Regs.x.cflag;
}

/**********************************************************************/
/*  GetSecCyl: retourne les num‚ros de secteur et de cylindre aprŠs   */
/*             conversion des informations au format du BIOS          */
/*  Entr‚e : SecCyl   : valeur … d‚coder                              */
/*           Secteur  : r‚f‚rence … la variable secteur               */
/*           Cylindre : r‚f‚rence … la variable cylindre              */
/*  Sortie : aucune                                                   */
/**********************************************************************/

void GetSecCyl( WORD SecCyl, int *Secteur, int *Cylindre )

{
 *Secteur   = SecCyl & 63;                 /* Masquer les bits 6 et 7 */
 *Cylindre = HI(SecCyl) + ( ( (WORD) LO(SecCyl) & 192 ) << 2 );
}

/**********************************************************************/
/*  ShowPartition: affiche les partitions du disque dur               */
/*  Entr‚e : LC : num‚ro du lecteur disque dur demand‚ (0, 1, 2 etc.) */
/*  Sorite : aucune                                                   */
/**********************************************************************/

void ShowPartition( BYTE LC )
{
 #define AP ( ParSec.PartTable[ Entry ] )

 BYTE       Tete,                    /* tˆte de la partition courante */
       Entry;                                /* compteur d'it‚rations */
 int        Secteur,                 /* stocker les nø de secteur et  */
        Cylindre;                                      /* de cylindre */
 PARTSEC    ParSec;             /* le secteur courant de la partition */
 union REGS Regs;       /* registres processeur pr appel interruption */

 printf("\n");
 LC |= 0x80;                 /* Pr‚pare le nø de lecteur pour le BIOS */
 if ( ReadPartSec( LC, 0, 1, &ParSec ) ) /* lire secteur de partition */
  {                                    /* Lecture correcte du secteur */
   Regs.h.ah = 8;              /* interroge identification du lecteur */
   Regs.h.dl = LC;
   int86( 0x13, &Regs, &Regs ); /* appel de l'interruption disque dur */
   GetSecCyl( Regs.x.cx, &Secteur, &Cylindre );
   printf( "ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ"
       "ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»\n");
   printf( "º Lecteur %2d: %2d tˆtes avec chacune %4d"
       " cylindres de %3d secteurs         º\n",
       LC-0x80, Regs.h.dh+1, Cylindre, Secteur );
   printf( "º Table de partitions dans le secteur de partition     "
       "                    º\n");
   printf( "ÌÍÍÑÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ"
       "ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍ¹\n");
   printf( "º  ³    ³                   ³    D‚but     ³"
       "     Fin      ³Distance³       º\n");
   printf( "ºNø³Boot³Type               ³Tˆte Cyl. Sec.³"
       "Tˆte Cyl. Sec.³BootSect³Nombre º\n");
   printf( "ÌÍÍØÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍØ"
       "ÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍ¹\n");

          /*-- lire les tables partitions ----------------------------*/
   for ( Entry=0; Entry < 4; ++Entry )
    {
     printf( "º %d³", Entry );
     if ( AP.Status == 0x80 )                    /* Partition active? */
      printf("Oui ");
     else
      printf ("Non ");
     printf("³");
     switch( AP.PartTyp )          /* Evaluation du type de partition */
      {
       case 0x00 : printf( "vide               " );
           break;
       case 0x01 : printf( "DOS, FAT 12 bits   " );
           break;
       case 0x02 :
       case 0x03 : printf( "XENIX              " );
           break;
       case 0x04 : printf( "DOS, FAT 16 bits   " );
           break;
       case 0x05 : printf( "DOS, extended Part." );
           break;
       case 0x06 : printf( "DOS 4.0 > 32 MB    " );
     break;
       case 0xDB : printf( "Concurrent DOS     " );
           break;
       default   : printf( "inconnu   (%3d)    ",
               ParSec.PartTable[ Entry ].PartTyp );
      }

     /*-- Evaluation des donn‚es physiques et logiques ---------------*/
     GetSecCyl( AP.StartSec.SecCyl, &Secteur, &Cylindre );
     printf( "³%2d %5d  %3d ", AP.StartSec.Tete, Cylindre, Secteur );
     GetSecCyl( AP.EndSec.SecCyl, &Secteur, &Cylindre );
     printf( "³%2d %5d  %3d ", AP.EndSec.Tete, Cylindre, Secteur );
     printf( "³%7lu ³%6lu º\n", AP.SecOfs, AP.NbreSec);
    }
   printf( "ÈÍÍÏÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ"
       "ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍ¼\n" );
  }
 else
  printf("Erreur d'accŠs au secteur de boot !\n");
}

/***********************************************************************
*               P R O G R A M M E   P R I N C I P A L                  *
***********************************************************************/

int main( int argc, char *argv[] )
{
 int Lecteur;

 printf( "\nÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛ FIXPARTC - (c)"
    " 1989, 92 by MICHAEL TISCHER ÛÛÛ\n" );
 Lecteur = 0;                            /* 1er disque dur par d‚faut */
 if ( argc == 2 )                      /* demander un autre lecteur ? */
  {                                                            /* oui */
   Lecteur = atoi ( argv[1] );
   if ( Lecteur == 0 && *argv[1] != '0' )
    {
     printf("\nNum‚ro de lecteur invalide!");
     return( 1 );                             /* Quitter le programme */
    }
  }
 ShowPartition( (BYTE) Lecteur ); /* Afficher le secteur de partition */
 return( 0 );
}
