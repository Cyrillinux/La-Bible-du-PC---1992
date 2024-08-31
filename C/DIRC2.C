/***********************************************************************
*                              D I R C 2                               *
**--------------------------------------------------------------------**
*    Fonction        : Affiche tous les fichiers d'un r‚pertoire       *
*                     y compris les sous-r‚pertoires et noms           *
*                     de volumes sur l'‚cran.                          *
*                     La demande des fichiers s'effectue … travers     *
*                     les fonctions pr‚d‚finies C.                     *
*                     Reportez-vous ‚galement … DIR1.C                 *
**--------------------------------------------------------------------**
*    Auteur          : MICHAEL TISCHER                                 *
*    D‚velopp‚ le    : 15.10.1991                                      *
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

#ifdef __TURBOC__                             /* Compilateur Turbo C? */
  #include <dir.h>             /* Ins‚rer les fonctions de r‚pertoire */
#endif

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;     /* Voil… comment se bricoler un OCTET */

/*== Constantes ======================================================*/

#define TRUE   ( 0 == 0 )     /* Les constantes facilitent la lecture */
#define FALSE  ( 0 == 1 )                    /* du texte du programme */

#define EINTR  14     /* Autant d'entr‚es sont visibles simultan‚ment */
#define EZ     ((20-EINTR) >> 1)  /* 1Šre ligne de fenˆtre r‚pertoire */
#define NOF    0x07                 /* Ecriture blanche sur fond noir */
#define INV    0x70  /* Ecriture noire sur fond blanc (vid‚o inverse) */

#define FA_ALL 0x3F                         /* Tous types de fichiers */

/*== Macros ==========================================================*/

#ifdef MK_FP                             /* Macro MK_FP d‚j… d‚finie? */
  #undef MK_FP                            /* Si oui, effacer la macro */
#endif

#define MK_FP(s,o) ((void far *) (((unsigned long) (s)<<16)|(o)))

/*-- Constantes/macros pour rec. de fichiers avec compilateurs -------*/
/*-- Microsoft et Borland                                      -------*/

#ifdef __TURBOC__                             /* Compilateur Turbo C? */
  #define DIRSTRUCT                      struct ffblk
  #define FINDFIRST( path, buf, attr )   findfirst( path, buf, attr )
  #define FINDNEXT( buf )                findnext( buf )
  #define NAME                           ff_name
  #define ATTRIBUT                       ff_attrib
  #define TIME                           ff_ftime
  #define DATE                           ff_fdate
  #define SIZE                           ff_fsize
#else                                             /* Non, Microsoft C */
  #define DIRSTRUCT                      struct find_t
  #define FINDFIRST( path, buf, attr )   _dos_findfirst(path, attr, buf)
  #define FINDNEXT( buf )                _dos_findnext( buf )
  #define NAME                           name
  #define ATTRIBUT                       attrib
  #define TIME                           wr_time
  #define DATE                           wr_date
  #define SIZE                           size
#endif

/***********************************************************************
* PRINT : Comme PRINTF mais inscrit directement la chaŒne              *
*         dans la RAM vid‚o                                            *
* Entr‚e : COLONNE = Colonne de sortie                                 *
*          LIGNE   = Ligne de sortie                                   *
*          COULEUR = Couleur d'affichage                               *
*          STRING  = Pointeur sur la chaŒne PRINTF                     *
*           ...    = Autres arguments                                  *
* Sortie : Aucune                                                      *
***********************************************************************/

void Print( int Colonne, int Ligne, BYTE Couleur, char * String, ...)
{
 struct vr {             /* Une position ‚cran sous forme de 2 octets */
            BYTE caractere,                          /* Le code ASCII */
                 attribut;                    /* L'attribut appropri‚ */
           } far * lptr;      /* Pointeur pour l'accŠs … la RAM vid‚o */
 va_list parameter;         /* Liste de paramŠtres pour macros VA_... */
 char    sortie[255],                  /* Buffer pour chaŒne format‚e */
         *aptr = sortie;                  /* Pour consulter la chaŒne */
 static unsigned int vioseg = 0;
 union REGS          Registre;             /* Registres d'appel d'int */

 if( vioseg == 0 )                                  /* Premier appel? */
 {            /* Oui, d‚terminer l'adresse de segment de la RAM vid‚o */
   Registre.h.ah = 0x0F;
   int86(0x10, &Registre, &Registre);
   vioseg = ( Registre.h.al == 7 ? 0xb000 : 0xb800 );
 }

 va_start( parameter, String );           /* Convertir les paramŠtres */
 vsprintf( sortie, String, parameter );                   /* Formater */
 lptr = (struct vr far *)
          MK_FP( vioseg, ( Ligne * 80 + Colonne ) << 1 );

 for( ; *aptr ; )                               /* Examiner la chaŒne */
 {
   lptr->caractere = *aptr++;          /* CaractŠre dans la RAM vid‚o */
   lptr++->attribut = Couleur;     /* D‚finir l'attribut du caractŠre */
 }
}

/***********************************************************************
* SCROLLUP: Fait avancer une zone d'‚cran d'une ou plusieurs lignes    *
*           vers le haut ou l'efface                                   *
* Entr‚e : NOMBRE  = Nombre de lignes … faire d‚filer                  *
*          COULEUR = Couleur ou Attribut des lignes vides              *
*          COLSG   = Colonne du coin sup‚rieur gauche de la zone       *
*          LIGNSG  = Ligne du coin sup‚rieur gauche de la zone         *
*          COLID   = Colonne du coin inf‚rieur droit de la zone        *
*          LIGNID  = Ligne du coin inf‚rieur droit de la zone          *
* Sortie : Aucune                                                      *
* Infos    : Si 0 transmis comme nombre : zone ‚cran compl‚t‚e         *
*            par des espaces                                           *
***********************************************************************/

void ScrollUp( BYTE Nombre, BYTE Couleur, BYTE ColSG,
               BYTE LignSG, BYTE ColID, BYTE LignID)
{
 union REGS Registre;            /* Registres pour appel interruption */

 Registre.h.ah = 6;                             /* Num‚ro de fonction */
 Registre.h.al = Nombre;                          /* Nombre de lignes */
 Registre.h.bh = Couleur;              /* Couleur de ligne(s) vide(s) */
 Registre.h.ch = LignSG;             /* D‚finir les coordonn‚es de la */
 Registre.h.cl = ColSG;           /* fenˆtre ‚cran … faire d‚filer ou */
 Registre.h.dh = LignID;                              /* ou … effacer */
 Registre.h.dl = ColID;
 int86(0x10, &Registre, &Registre);     /* Appeler l'interruption 10h */
}

/***********************************************************************
* SETPOS : D‚finit la position du curseur dans la page ‚cran           *
*          actuelle                                                    *
* Entr‚e : COLONNE = Nouvelle colonne du curseur                       *
*          LIGNE   = Nouvelle ligne du curseur                         *
* Sortie : Aucune                                                      *
***********************************************************************/

void SetPos( BYTE Colonne, BYTE Ligne)
{
 union REGS Registre;            /* Registres pour appel interruption */

 Registre.h.ah = 2;                             /* Num‚ro de fonction */
 Registre.h.bh = 0;                                     /* Page ‚cran */
 Registre.h.dh = Ligne;                                /* Ligne ‚cran */
 Registre.h.dl = Colonne;                            /* Colonne ‚cran */
 int86(0x10, &Registre, &Registre);     /* Appeler l'interruption 10h */
}

/***********************************************************************
* CLS : Effacer page ‚cran actuelle et placer curseur dans le coin     *
*       sup‚rieur gauche                                               *
* Entr‚e : Aucune                                                      *
* Sortie : Aucune                                                      *
***********************************************************************/

void Cls( void )

{
 ScrollUp(0, NOF, 0, 0, 79, 24);                   /* Effacer l'‚cran */
 SetPos(0, 0);                                   /* Placer le curseur */
}

/***********************************************************************
* CONFIGECRAN : Configure l'‚cran pour la sortie du                    *
*               r‚pertoire                                             *
* Entr‚e : Aucune                                                      *
* Sortie : Aucune                                                      *
***********************************************************************/

void ConfigEcran( void )
{
 BYTE i;                                        /* Compteur de boucle */

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
* PRINTDATA: Afficher les informations … propos d'une entr‚e           *
* Entr‚e : SAISIE = Ptr sur une structure Dir avec des informations    *
*                   de fichier                                         *
*           LIGNE = Ligne ‚cran de l'entr‚e                            *
* Sortie : Aucune                                                      *
***********************************************************************/

void PrintData(DIRSTRUCT *Saisie, BYTE Ligne)
{
 BYTE i, j;                                     /* Compteur de boucle */
 static char *Mois[] =         /* Vecteur avec pointeurs sur les mois */
        {
          "Jan", "F‚v", "Mar", "Avr", "Mai", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "D‚c"
        };

          /*-- Afficher les informations de fichier ------------------*/

 Print(15, Ligne, NOF, "%s", Saisie->NAME);

 Print( 28, Ligne, NOF, "%7lu", Saisie->SIZE);
 Print( 36, Ligne, NOF, " %2d %s %4d", Saisie->DATE & 31,
        Mois[((Saisie->DATE >> 5) & 15) - 1],
        (Saisie->DATE >> 9) + 1980);
 Print(49, Ligne, NOF, "  %2dh%2d", Saisie->TIME >> 11,
                                  (Saisie->TIME >> 5) & 63 );

 for (i = j = 1; i <= 16; i <<= 1, ++j)       /* Attributs de fichier */
  Print( 58+j, Ligne, NOF, "%c", (Saisie->ATTRIBUT & i) ? 'X' : ' ' );
}

/***********************************************************************
* DIR : Contr“le la lecture et la sortie du r‚pertoire                 *
* Entr‚e : CHEMIN   = Ptr sur chemin de rech. avec masque fichier      *
*          ATTRIBUT = Attributs de recherche                           *
* Sortie : Aucune                                                      *
***********************************************************************/

void Dir( char *Chemin, BYTE Attribut )
{
 int       NbEntrees,              /* Nombre total d'entr‚es trouv‚es */
           NbImage;                  /* Nombre d'entr‚es dans l'image */
 DIRSTRUCT Saisie;                        /* Une entr‚e de r‚pertoire */

 ConfigEcran();    /* Construire l'‚cran pour la sortie de r‚pertoire */

 NbImage = NbEntrees = 0; /* Aucune entr‚e encore affich‚e ds fenˆtre */
                              /* Aucune entr‚e n'a ‚t‚ encore trouv‚e */
 if( !FINDFIRST(Chemin, &Saisie, Attribut) )     /* Rech. 1Šre entr‚e */
 {                                               /* Un fichier trouv‚ */
   do    /* Sortir le fichier et rechercher le suivant avec GetNext() */
   {
     PrintData(&Saisie, EZ+EINTR+2);             /* Afficher l'entr‚e */
     if( ++NbImage == EINTR )          /* La fenˆtre est-elle pleine? */
     {
       NbImage = 0;                  /* Remplir … nouveau une fenˆtre */
       Print(14, EZ+4+EINTR, INV,
          "         Veuillez appuyer sur une touche           ");
       getch();                    /* Attendre l'appui sur une touche */
       Print(14, EZ+4+EINTR, NOF,
          "                                                   ");
     }
     ScrollUp(1, NOF, 15, EZ+3, 63, EZ+2+EINTR);
     Print(15, EZ+2+EINTR, NOF,
        "            ³       ³            ³         ³     ");
     ++NbEntrees;
   }
   while( !FINDNEXT( &Saisie ) );  /* Fin s'il n'y a plus de fichiers */
 }

 SetPos(14, EZ+4+EINTR);
 switch (NbEntrees)
 {
   case 0  : printf("Aucun fichier trouv‚");
             break;
   case 1  : printf("Un fichier trouv‚");
             break;
   default : printf("%d Fichiers trouv‚es", NbEntrees);
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
   case 1  : Dir("*.*", FA_ALL );   /* Afficher tous fichiers du r‚p. */
             break;                                       /* en cours */
   case 2  : Dir( Arguments[1], FA_ALL ); /* Affiche fichiers du r‚p. */
             break;                                       /* sp‚cifi‚ */
   default : printf("Nombre de paramŠtres incorrect\n");
 }
}
