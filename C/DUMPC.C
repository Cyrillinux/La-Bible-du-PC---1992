/***********************************************************************
*                            D U M P C                                 *
**--------------------------------------------------------------------**
*    Fonction       : un filtre qui lit des caractŠres sur l'entr‚e    *
*                     standard pour les ressortir sur la sortie        *
*                     standard sous forme de dump hexa et ASCII        *
**--------------------------------------------------------------------**
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 14/08/1987                                       *
*    DerniŠre modif.: 29/02/1992                                       *
**--------------------------------------------------------------------**
*    (MICROSOFT C)                                                     *
*    Cr‚ation       : CL /AS DUMPC.C                                   *
*    Appel          : DUMPC [<Entr‚e] [>Sortie]                        *
**--------------------------------------------------------------------**
*    (BORLAND TURBO C)                                                 *
*    Cr‚ation       : Cr‚er avec l'instruction COMPILE - MAKE          *
*                     (sans fichier Project) et faire ex‚cuter         *
*                     sous l'environnement DOS                         *
**********************************************************************/

/*== fichiers Include ================================================*/
#include <stdio.h>                        /* Int‚grer fichiers header */
#include <dos.h>

/*== Typedefs ========================================================*/
typedef unsigned char byte;     /* Voil… comment se bricoler un OCTET */

/*== Constantes ======================================================*/
#define NUL     0                            /* Code du caractŠre NUL */
#define BEL     7                              /* Code de la sonnerie */
#define BS      8                      /* Code de la touche Backspace */
#define TAB     9                     /* Code de la touche tabulateur */
#define LF      10                               /* Code de Line Feed */
#define CR      13                        /* Code de la touche Return */
#define ESC     27                        /* Code de la touche Escape */

/*== Macros ==========================================================*/
#define tohex(c) ( ((c)<10) ? ((c) | 48) : ((c) + 'A' - 10) )

/***********************************************************************
* GETSTDIN: lit un nombre d‚termin‚ de caractŠres sur le p‚riph‚rique  *
*           d'entr‚e standard et les place dans un buffer              *
* Entr‚e  : voir plus bas                                              *
* Sortie  : Nombre de caractŠres lus                                   *
***********************************************************************/

unsigned int GetStdIn( char *Buffer, unsigned NombreMax )
{
  union REGS    Register;          /* Registre d'appel d'interruption */
  struct SREGS  Segments;          /* Re‡oit les registres de segment */

 segread( &Segments );    /* Charger contenu des registres de segment */
 Register.h.ah = 0x3F;                     /* Num‚ro de fonction pour */
 Register.x.bx = 0;                /* P‚riph. d'entr‚e std : handle 0 */
 Register.x.cx = NombreMax;                 /* Nombre d'octets … lire */
 Register.x.dx = (unsigned int) Buffer; /* Adresse d'offset du buffer */
 intdosx(&Register, &Register, &Segments);          /* int. DOS 21(h) */
 return(Register.x.ax);           /* Nombre d'octets lus … l'appelant */
}

/***********************************************************************
* STRAP: Ajouter caractŠre … une chaŒne                                *
* Entr‚e  : voir plus bas                                              *
* Sortie  : Pointeur … la suite du dernier caractŠre ajout‚            *
***********************************************************************/

char *Strap(char *String, char *Ajouter)
{
 while( *Ajouter )           /* R‚p‚ter jusqu'… ce que '\0' rencontr‚ */
   *String++ = *Ajouter++;                    /* Transf‚rer caractŠre */
 return(String);           /* Transmettre pointeur … fonction appel‚e */
}

/***********************************************************************
* DODUMP: charge les caractŠres et les sort comme Dump                 *
* Entr‚e  : Aucune                                                     *
* Sortie  : Aucune                                                     *
***********************************************************************/

void DoDump( void )

{
 char NeufOctets[9],                  /* Re‡oit les caractŠres entr‚s */
      DumpBuf[80],                        /* Re‡oit une ligne du DUMP */
      *NextAscii;  /* D‚signe prochain caractŠre ASCII dans le buffer */
 byte i,                                        /* Compteur de boucle */
      Nombre;                               /* Nombre d'octets entr‚s */

 DumpBuf[30]   = 219;           /* CaractŠre de s‚paration hexa/ASCII */
 while( (Nombre = GetStdIn(NeufOctets, 9)) != 0 )      /* CaractŠre ? */
 {                                                             /* Oui */
   for( i = 0; i < 30; DumpBuf[i++] = ' ')       /* Remplir d'espaces */
      ;
   NextAscii = &DumpBuf[31];                      /* CaractŠres ASCII */
   for( i = 0; i < Nombre; i++ )      /* Traiter ts caractŠres entr‚s */
   {
     DumpBuf[i*3]   = tohex((byte) NeufOctets[i] >> 4); /* Conv. code */
     DumpBuf[i*3+1] = tohex((byte) NeufOctets[i] & 15);    /* en hexa */
     switch (NeufOctets[i])                     /* Evaluer code ASCII */
     {
       case NUL : NextAscii = Strap(NextAscii, "<NUL>");
                  break;
       case BEL : NextAscii = Strap(NextAscii, "<BEL>");
                  break;
       case BS  : NextAscii = Strap(NextAscii, "<BS>");
                  break;
       case TAB : NextAscii = Strap(NextAscii, "<TAB>");
                  break;
       case LF  : NextAscii = Strap(NextAscii, "<LF>");
                  break;
       case CR  : NextAscii = Strap(NextAscii, "<CR>");
                  break;
       case ESC : NextAscii = Strap(NextAscii, "<ESC>");
                  break;
       case EOF : NextAscii = Strap(NextAscii, "<EOF>");
                  break;
       default  : *NextAscii++ = NeufOctets[i];
     }
   }
   *NextAscii     = 219;     /* CaractŠre de fin pour affichage ASCII */
   *(NextAscii+1) = '\r';       /* Carriage Return … la fin du buffer */
   *(NextAscii+2) = '\0';        /* NUL converti en LF pendant sortie */
   puts(DumpBuf);          /* Ecrire chaŒne sur p‚riph. de sortie std */
  }
}

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()

{
  DoDump();                             /* Entrer et sortir caractŠre */
}
