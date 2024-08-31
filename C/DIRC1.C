/***********************************************************************
*                              D I R C 1                               *
**--------------------------------------------------------------------**
*    Fonction        : Affiche tous les fichiers d'un r‚pertoire       *
*                     quelconque y compris les sous-r‚pertoires et     *
*                     noms de volumes sur l'‚cran.                     *
*                     La demande des fichiers s'effectue … travers     *
*                     un appel direct des fonctions DOS                *
*                     4Eh et 4Fh.                                      *
*                     Reportez-vous ‚galement au programme DIR2.C      *
**--------------------------------------------------------------------**
*    Auteur          : MICHAEL TISCHER                                 *
*    D‚velopp‚ le    : 15.08.1987                                      *
*    DerniŠre modif. : 15.03.1992                                      *
**--------------------------------------------------------------------**
*    ModŠle de m‚moire : SMALL                                         *
***********************************************************************/

/*== Ins‚rer les fichiers Include ====================================*/

#include <dos.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <conio.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;     /* Voil… comment se bricoler un OCTET */
typedef struct {            /* Structure DIR des fonctions 4Eh et 4Fh */
                BYTE          Reserve[21];
                BYTE          Attribut;
                unsigned int  Time;
                unsigned int  Date;
                unsigned long Size;
                char          Name[13];
 } DIRSTRUCT;

/*== Constantes ======================================================*/

/*-- Attributs pour la recherche de fichiers -------------------------*/

#define ATTR_RDONLY 0x01                             /* Lecture seule */
#define ATTR_HIDDEN 0x02                                     /* Cach‚ */
#define ATTR_SYSTEM 0x04                                   /* SystŠme */
#define ATTR_LABEL  0x08                             /* Nom de Volume */
#define ATTR_DIREC  0x10                                /* R‚pertoire */
#define ATTR_ARCH   0x20                                   /* Archive */
#define ATTR_ALL    0x3F                    /* Tous types de fichiers */

#define TRUE   ( 0 == 0 )     /* Les constantes facilitent la lecture */
#define FALSE  ( 0 == 1 )                       /* Texte du programme */

#define EINTR  14     /* Autant d'entr‚es sont visibles simultan‚ment */
#define EZ     ((20-EINTR) >> 1)     /* 1Šre ligne de fenˆtre du r‚p. */
#define NOF    0x07                 /* Ecriture blanche sur fond noir */
#define INV    0x70  /* Ecriture noire sur fond blanc (vid‚o inverse) */

/*== Macros ==========================================================*/

#ifdef MK_FP                             /* Macro MK_FP d‚j… d‚finie? */
  #undef MK_FP                            /* Si oui, effacer la macro */
#endif

#define MK_FP(s,o) ((void far *) ( ((unsigned long)(s)<<16) |(o)))

/***********************************************************************
* PRINT : Similaire … PRINTF mais inscrit directement la chaŒne de     *
*         caractŠres dans la RAM vid‚o                                 *
* Entr‚e : COLONNE = Colonne de sortie                                 *
*          LIGNE   = Ligne de sortie                                   *
*          COULEUR = Couleur d'affichage                               *
*          STRING  = Pointeur sur la chaŒne PRINTF                     *
*           ...    = Autres arguments                                  *
* Sortie : Aucune                                                      *
***********************************************************************/

void Print( int Colonne, int Ligne, BYTE Couleur, char * String, ...)
{
 struct vr
 {                     /* Une position d'‚cran sous forme de 2 octets */
   BYTE caractere,                                      /* Code ASCII */
        attribut;                             /* L'attribut appropri‚ */
 } far   *lptr;               /* Pointeur pour l'accŠs … la RAM vid‚o */
 va_list parameter;         /* Liste de paramŠtres pour VA_... Macros */
 char    Sortie[255],                  /* Buffer pour chaŒne format‚e */
         *aptr = Sortie;                  /* Pour consulter la chaŒne */
 static unsigned int  vioseg = 0;
 union REGS           Registre;           /* Registres d'appel d'int. */

 if( vioseg == 0 )                                  /* Premier appel? */
 {            /* Oui, d‚terminer l'adresse de segment de la RAM vid‚o */
   Registre.h.ah = 0x0F;
   int86(0x10, &Registre, &Registre);
   vioseg = ( Registre.h.al == 7 ? 0xb000 : 0xb800 );
 }

 va_start( parameter, String );           /* Convertir les paramŠtres */
 vsprintf( Sortie, String, parameter );                   /* Formater */
 lptr = (struct vr far *)
          MK_FP( vioseg, ( Ligne * 80 + Colonne ) << 1 );

 for( ; *aptr ; )                               /* Examiner la chaŒne */
 {
   lptr->caractere = *aptr++;          /* CaractŠre dans la RAM vid‚o */
   lptr++->attribut = Couleur;     /* D‚finir l'attribut du caractŠre */
 }
}

/***********************************************************************
* SCROLLUP: Fait avancer une zone ‚cran d'une ou plusieurs lignes      *
*           vers le haut ou l'efface                                   *
* Entr‚e : NOMBRE  = Nombre de lignes … faire d‚filer                  *
*          COULEUR = Couleur ou Attribut des lignes vides              *
*          COLSG   = Colonne du coin sup‚rieur gauche de la zone       *
*          LIGNSG  = Ligne du coin sup‚rieur gauche de la zone         *
*          COLID   = Colonne du coin inf‚rieur droit de la zone        *
*          LIGNID  = Ligne du coin inf‚rieur droit de la zone          *
* Sortie : Aucune                                                      *
* Infos    : Si 0 transmis (nombre), la zone est alors compl‚t‚e       *
*            par des espaces                                           *
***********************************************************************/

void ScrollUp( BYTE Nombre, BYTE Couleur, BYTE ColSG,
               BYTE LignSG, BYTE ColID, BYTE LignID)
{
 union REGS  Registre;         /* Registres pour appel d'interruption */

 Registre.h.ah = 6;                             /* Num‚ro de fonction */
 Registre.h.al = Nombre;                          /* Nombre de lignes */
 Registre.h.bh = Couleur;              /* Couleur de ligne(s) vide(s) */
 Registre.h.ch = LignSG;             /* D‚finir les coordonn‚es de la */
 Registre.h.cl = ColSG;           /* Fenˆtre ‚cran … faire d‚filer ou */
 Registre.h.dh = LignID;                                 /* … effacer */
 Registre.h.dl = ColID;
 int86(0x10, &Registre, &Registre);     /* Appeler l'interruption 10h */
}

/***********************************************************************
* SETPOS: D‚finit la position du curseur dans la page ‚cran actuelle   *
* Entr‚e : COLONNE = Nouvelle colonne du curseur                       *
*          LIGNE   = Nouvelle ligne du curseur                         *
* Sortie : Aucune                                                      *
***********************************************************************/

void SetPos( BYTE Colonne, BYTE Ligne)
{
 union REGS Registre;          /* Registres pour appel d'interruption */

 Registre.h.ah = 2;                             /* Num‚ro de fonction */
 Registre.h.bh = 0;                                     /* Page ‚cran */
 Registre.h.dh = Ligne;                              /* Ligne d'‚cran */
 Registre.h.dl = Colonne;                          /* Colonne d'‚cran */
 int86(0x10, &Registre, &Registre);     /* Appeler l'interruption 10h */
}

/***********************************************************************
* CLS : Effacer la page ‚cran actuelle et placer curseur dans le coin  *
*       sup‚rieur gauche                                               *
* Entr‚e : Aucune                                                      *
* Sortie : Aucune                                                      *
***********************************************************************/

void Cls( void )
{
  ScrollUp(0, NOF, 0, 0, 79, 24);                  /* Effacer l'‚cran */
  SetPos(0, 0);                                  /* Placer le curseur */
}

/***********************************************************************
* CONFIGECRAN: Configure l'‚cran pour la sortie du r‚pertoire          *
* Entr‚e : Aucune                                                      *
* Sortie : Aucune                                                      *
***********************************************************************/

void ConfigEcran( void )
{
 BYTE  i;                                       /* Compteur de boucle */

 Cls();                                            /* Effacer l'‚cran */
 Print( 14, EZ, NOF,
        "ÉÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍ»");
 Print( 14, EZ+1, NOF,
        "º Nom        ³ Taille³   Date     ³  Heure  ³RHSVDº");
 Print( 14, EZ+2, NOF,
        "ÇÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄ¶");
 for (i = EZ+3; i < EZ+3+EINTR; i++)
  Print( 14, i, NOF,
         "º            ³       ³            ³         ³     º");
 Print( 14, EZ+EINTR+3, NOF,
        "ÈÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍ¼");
}

/***********************************************************************
* PRINTDATA : Sortir les informations … propos d'une entr‚e            *
* Entr‚e : SAISIE = Ptr sur une structure Dir avec des informations    *
*                   de fichier                                         *
*           LIGNE = Ligne d'‚cran de la saisie                         *
* Sortie : Aucune                                                      *
***********************************************************************/

void PrintData(DIRSTRUCT *Saisie, BYTE Ligne)
{
 BYTE        i, j;                             /*  Compteur de boucle */
 static char *Mois[] =         /* Vecteur avec pointeurs sur les mois */
        {
          "Jan", "F‚v", "Mar", "Avr", "Mai", "Jun",
          "Jul", "Aut", "Sep", "Oct", "Nov", "D‚c"
 };

          /*-- Afficher les informations de fichier ------------------*/

 Print( 15, Ligne, NOF, "%s", Saisie->Name);

 Print( 28, Ligne, NOF, "%7lu", Saisie->Size);
 Print( 36, Ligne, NOF, " %2d %s %4d", Saisie->Date & 31,
        Mois[((Saisie->Date >> 5) & 15) - 1],
        (Saisie->Date >> 9) + 1980);
 Print(49, Ligne, NOF, "  %2dh%2d", Saisie->Time >> 11,
                                  (Saisie->Time >> 5) & 63 );

 for( i = j = 1; i <= 16; i <<= 1, ++j )      /* Attributs de fichier */
   Print( 58+j, Ligne, NOF, "%c", (Saisie->Attribut & i) ? 'X' : ' ' );
}

/***********************************************************************
* FINDFIRST: Lire la premiŠre entr‚e de r‚pertoire                     *
* Entr‚e : CHEMIN    = Ptr sur chemin de rech. avec masque fichier     *
*           ATTRIBUT = Attributs de recherche                          *
* Sortie : TRUE, si une entr‚e a ‚t‚ trouv‚e sinon FALSE               *
* Infos    : L'entr‚e est lue dans le DTA                              *
***********************************************************************/

BYTE findfirst( char *Chemin, BYTE Attribut )
{
 union REGS   Registre;        /* Registres pour appel d'interruption */
 struct SREGS Segments;            /* Re‡oit les registres de segment */

 segread(&Segments);      /* Lire le contenu des registres de segment */
 Registre.h.ah = 0x4E;           /* Num‚ro de fonction pour FindFirst */
 Registre.x.cx = Attribut;                    /* Attributs recherch‚s */
 Registre.x.dx = (unsigned int) Chemin;  /* Offset du chemin de rech. */
 intdosx(&Registre, &Registre, &Segments);    /* Interruption DOS 21h */
 return( !Registre.x.cflag );    /* Carry-Flag = 0: Un fichier trouv‚ */
}

/***********************************************************************
* FINDNEXT : Lire l'entr‚e de r‚pertoire suivante                      *
* Entr‚e   : Aucune                                                    *
* Sortie   : TRUE, si une entr‚e a ‚t‚ trouv‚e sinon FALSE             *
* Infos    : L'entr‚e est lue dans le DTA                              *
***********************************************************************/

BYTE findnext( void )
{
 union REGS Registre;          /* Registres pour appel d'interruption */

 Registre.h.ah = 0x4F;            /* Num‚ro de fonction pour FindNext */
 intdos(&Registre, &Registre);      /* Appeler l'interruption DOS 21h */
 return( !Registre.x.cflag );    /* Carry-Flag = 0: Un fichier trouv‚ */
}

/***********************************************************************
* SETDTA : Place le DTA sur une variable du segment de donn‚es         *
* Entr‚e : OFFSET = Offset du DTA dans le segment de donn‚es           *
* Sortie : Aucune                                                      *
***********************************************************************/

void SetDTA( unsigned int Offset )
{
 union REGS   Registre;        /* Registres pour appel d'interruption */
 struct SREGS Segments;              /* Re‡oit le registre de segment */

 segread(&Segments);      /* Lire le contenu des registres de segment */
 Registre.h.ah = 0x1A;   /* D‚finir le num‚ro de fonction pour le DTA */
 Registre.x.dx = Offset;      /* Adresse d'offset dans le registre DX */
 intdosx(&Registre, &Registre, &Segments);    /* Interruption DOS 21h */
}

/***********************************************************************
* DIR    : Contr“le la lecture et la sortie du r‚pertoire              *
* Entr‚e : CHEMIN   = Ptr sur chemin de rech. avec masque fichier      *
*          ATTRIBUT = Attributs de recherche                           *
* Sortie : Aucune                                                      *
***********************************************************************/

void Dir(char *Chemin, BYTE Attribut )
{
 int       NbEntrees,            /* Nombre total des entr‚es trouv‚es */
           NbImage;                  /* Nombre d'entr‚es dans l'image */
 DIRSTRUCT Saisie;                        /* Une entr‚e de r‚pertoire */

 SetDTA( (unsigned int) &Saisie );            /* SAISIE = nouveau DTA */
 ConfigEcran();    /* Construire l'‚cran pour la sortie de r‚pertoire */

 NbImage = NbEntrees = 0;   /* Aucune entr‚e encore aff. dans fenˆtre */
                              /* Aucune entr‚e n'a ‚t‚ encore trouv‚e */
 if (findfirst(Chemin, Attribut))    /* Rechercher la premiŠre entr‚e */
 {                                               /* Un fichier trouv‚ */
   do    /* Sortir le fichier et rechercher le suivant avec GetNext() */
   {
     PrintData(&Saisie, EZ+EINTR+2);               /* Sortir l'entr‚e */
     if (++NbImage == EINTR )          /* La fenˆtre est-elle pleine? */
     {
       NbImage = 0;                /* Compl‚ter … nouveau une fenˆtre */
       Print(14, EZ+4+EINTR, INV,
          "          Veuillez appuyer sur une touche          ");
       getch();                    /* Attendre l'appui sur une touche */
       Print(14, EZ+4+EINTR, NOF,
          "                                                   ");
 }
     ScrollUp(1, NOF, 15, EZ+3, 63, EZ+2+EINTR);
     Print(15, EZ+2+EINTR, NOF,
        "            ³       ³            ³         ³     ");
     ++NbEntrees;
 }
   while ( findnext() ); /* Fin de boucle s'il n'y a plus de fichiers */
 }

 SetPos(14, EZ+4+EINTR);
 switch (NbEntrees)
 {
   case 0  : printf("Pas de fichier trouv‚\n");
             break;
   case 1  : printf("Un fichier trouv‚\n");
             break;
   default : printf("%d Fichiers trouv‚s\n", NbEntrees);
             break;
 }
}

/**********************************************************************/
/**                           PROGRAMME PRINCIPAL                    **/
/**********************************************************************/

void main( int Nombre, char *Arguments[] )
{
 switch ( Nombre )        /* R‚agir en fonction du nombre d'arguments */
 {                                                        /* transmis */
   case 1  : Dir( "*.*", ATTR_ALL ); /* Afficher tous les fichiers du */
             break;                            /* r‚pertoire en cours */
   case 2  : Dir( Arguments[1], ATTR_ALL );  /* Aff. ts fich. du r‚p. */
             break;                                       /* sp‚cifi‚ */
   default : printf("Nombre de paramŠtres incorrect\n");
 }
}
