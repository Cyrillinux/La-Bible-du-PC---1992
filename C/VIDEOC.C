/**********************************************************************/
/*                            V I D E O C                             */
/*--------------------------------------------------------------------*/
/*    Fonction        : fournit quelques fonctions qui exploitent     */
/*         l'interruption vid�o du BIOS et qui ne sont pas encore     */
/* int�gr�es dans les biblioth�ques du compilateur C de Microsoft ou  */
/* de Borland                                                         */
/*--------------------------------------------------------------------*/
/*    Auteur       : MICHAEL TISCHER                                  */
/*    D�velopp� le : 13.08.1987                                       */
/*    Derni�re MAJ : 13.02.1992                                       */
/*--------------------------------------------------------------------*/
/*    (MICROSOFT C)                                                   */
/*    Compilation    : CL /AS VIDEOC.C                                */
/*    Appel          : VIDEOC                                         */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    Compilation    : par la commande RUN de l'EDI                   */
/*                     (sans fichier de projet                        */
/**********************************************************************/

/*== Fichiers d'inclusion ============================================*/

#include <dos.h>                                /* Fichiers d'en-t�te */
#include <io.h>
#include <stdio.h>

/*== Constantes ======================================================*/

#define NORMAL         0x07                   /* D�finit les attributs*/
#define CLAIR          0x0F               /* pour une carte monochrome*/
#define INVERSE        0x70
#define SOULIGNE       0x01
#define CLIGNOTANT     0x80

/**********************************************************************/
/* GETVIDEOMODE : D�termine le mode vid�o et divers autres param�tres */
/* Entr�e :  Modevideo  = Pointe sur le mode vid�o courant            */
/*           NOMBRE     = Pointe sur le nombre de colonnes            */
/*           PAGE       = Pointe sur la page d'�cran courante         */
/* Sortie  : n�ant                                                    */
/**********************************************************************/

void GetVideoMode( int *ModeVideo, int *Nombre, int *Page)
{
 union REGS Register;                /* Registres pour l'interruption */

 Register.h.ah = 15;                         /* Num�ro de la fonction */
 int86(0x10, &Register, &Register);    /* D�clenche l'interruption 10h*/
 *ModeVideo = Register.h.al;                   /* Num�ro du mode vid�o*/
 *Nombre = Register.h.ah;           /* Nombre de caract�res par ligne */
 *Page = Register.h.bh;         /* Num�ro de la page d'�cran courante */
}

/**********************************************************************/
/* SETCURSORTYPE : D�finit l'aspect du cursur clignotant              */
/* Entr�e : Debut  = Extr�mit� sup�rieure du curseur                  */
/*          Fin    = Extr�mit� inf�rieure du curseur                  */
/* Sortie : n�ant                                                     */
/* Info   : Les param�tres peuvent �tre compris entre 0 et 13 pour    */
/*           une carte monochrome, 0 et 7 pour une carte couleur      */

/**********************************************************************/

void SetCursorType(int Debut, int Fin)
{
 union REGS Register;                 /* Registres pour l'interruption*/

 Register.h.ah = 1;                          /* Num�ro de la fonction */
 Register.h.ch = Debut;        /* Ligne de l'extr�mit� sup du curseur */
 Register.h.cl = Fin;          /* Ligne de l'extr�mit� inf du curseur */
 int86(0x10, &Register, &Register);             /* Interruption 10(h) */
}

/**********************************************************************/
/* SETCURSORPOS : Position du curseur dans la page d'�cran indiqu�e   */
/*                                                                    */
/* Entr�e : PAGE    = Page d'�cran                                    */
/*          COLONNE = Colonne                                         */
/*          LIGNE   = Ligne                                           */
/* Sortie : n�ant                                                     */
/* Info   : La position du curseur clignotant ne change � l'issue de  */
/*          cet appel que si la page d'�cran indiqu�e est la page     */
/*          d'�cran courante                                          */
/**********************************************************************/

void SetCursorPos( int Page, int Colonne, int Ligne)
{
 union REGS Register;                 /* Registres pour l'interruption*/

 Register.h.ah = 2;                           /* Num�ro de la fonction*/
 Register.h.bh = Page;                                /* Page d'�cran */
 Register.h.dh = Ligne;                                      /* Ligne */
 Register.h.dl = Colonne;                                  /* Colonne */
 int86(0x10, &Register, &Register); /* D�clenche l'interruption 10(h) */
}

/**********************************************************************/
/* GETCURSORPOS : D�termine la position courante du curseur dans la   */
/*                page d'�cran ainsi que les limites de son aspect    */
/* Entr�e :  PAGE    = Page d'�cran                                   */
/*           COLONNE = Pointe sur la colonne courante                 */
/*           LIGNE   = Pointe sur la ligne courante                   */
/*           DEBUT   = Pointe sur la ligne de trame repr�sentant      */
/*                     l'extr�mit� sup�rieure du curseur.             */
/*           FIN     = Pointe sur la ligne de trame repr�sentant      */
/*                     l'extr�mit� inf�rieure du curseur              */
/* Sortie : n�ant                                                     */
/**********************************************************************/

void GetCursorPos( int Page, int *Colonne,
                   int *Ligne, int *Debut, int *Fin)
{
 union REGS Register;                /* Registres poour l'interruption*/

 Register.h.ah = 3;                          /* Num�ro de la fonction */
 Register.h.bh = Page;                                /* Page d'�cran */
 int86(0x10, &Register, &Register); /* D�clenche l'interruption 10(h) */
 *Colonne = Register.h.dl;                   /* Pr�l�ve les r�sultats */
 *Ligne  = Register.h.dh;                       /* dans les registres */
 *Debut = Register.h.ch;                            /* et les affecte */
 *Fin   = Register.h.cl;                              /* aux variables*/
}

/**********************************************************************/
/* SETDISPLAYPAGE: Affiche la page d'�cran demand�e                   */
/* Entr�e : PAGE = Page d'�cran                                       */
/* Sortie : n�ant                                                     */
/**********************************************************************/

void SetDisplayPage( int Page )
{
 union REGS Register;                /* Registres pour l'interruption */

 Register.h.ah = 5;                          /* Num�ro de la fonction */
 Register.h.al = Page;                                /* Page d'�cran */
 int86(0x10, &Register, &Register); /* D�clenche l'interruption 10(h) */
}

/**********************************************************************/
/* SCROLLUP : Fait d�filer une zone d'�cran d'une ou plusieurs        */
/*           lignes vers le haut ou provoque son effacement           */
/* Entr�e  : NOMBRE    = Nombre de lignes � faire d�filer             */
/*           COULEUR   = Couleur ou attribut des lignes vierges       */
/*           COLONNEHG = Colonne du coin sup gauche de la zone        */
/*           LIGNEHG   = Ligne du coin sup gauche de la zone          */
/*           COLONNEBD = Colonne du coin inf�rieur droit de la zone   */
/*           LIGNEBD  = Ligne du coin inf�rieur droit de la zone      */
/* Sortie  : n�ant                                                    */
/* Info    : Si on prend 0 comme param�tre, la zone d'�cran           */
/*           est remplie avec des lignes vierges                      */
/**********************************************************************/

void ScrollUp( int Nombre, int Couleur, int ColonneHG,
               int LigneHG, int ColonneBD, int LigneBD )
{
 union REGS Register;                /* Registres pour l'interruption */

 Register.h.ah = 6;                          /* Num�ro de la fonction */
 Register.h.al = Nombre;                          /* Nombre de lignes */
 Register.h.bh = Couleur;                /* Couleur des lignes vierges*/
 Register.h.ch = LigneHG;                  /* Fixe les coordonn�es de */
 Register.h.cl = ColonneHG;                             /* la fen�tre */
 Register.h.dh = LigneBD;                            /* de d�filement */
 Register.h.dl = ColonneBD;
 int86(0x10, &Register, &Register); /* D�clenche l'interruption 10(h) */
}

/**********************************************************************/
/* SCROLLDOWN : Fait d�filer une zone d'�cran d'une ou de plusieurs   */
/*              lignes vers le bas ou provoque son effacement         */
/* Entr�e :  NOMBRE    = Nombre de lignes � faire d�filer             */
/*           COULEUR   = Couleur ou attribut des lignes vierges       */
/*           COLONNEHG = Colonne du coin sup gauche de la zone        */
/*           LIGNEHG   = Ligne du coin sup gauche de la zone          */
/*           COLONNEBD = Colonne du coin inf droit de la zone         */
/*           LIGNEBD   = Ligne du coin inf droit de la zone           */
/* Sortie : n�ant                                                     */
/* Info    : Si le param�tre est 0, remplie de lignes vierges         */
/**********************************************************************/

void ScrollDown( int Nombre, int Couleur, int ColonneHG,
                 int LigneHG, int ColonneBD, int LigneBD )
{
 union REGS Register;                /* Registres pour l'interruption */

 Register.h.ah = 7;                          /* Num�ro de la fonction */
 Register.h.al = Nombre;                          /* Nombre de lignes */
 Register.h.bh = Couleur;               /* Couleur des lignes vierges */
 Register.h.ch = LigneHG;               /* Fixe les coordonn�es de la */
 Register.h.cl = ColonneHG;                  /* fen�tre de d�filement */
 Register.h.dh = LigneBD;
 Register.h.dl = ColonneBD;
 int86(0x10, &Register, &Register); /* D�clenche l'interruption 10(h) */
}

/**********************************************************************/
/* GETCHAR : lit un caract�re et son attribut � une position donn�e   */
/*           de la page d'�cran                                       */
/* Entr�e :  PAGE      = Page d'�cran concern�e                       */
/*           COLONNE   = Colonne du caract�re                         */
/*           LIGNE     = Ligne du caract�re                           */
/*           Caractere = Pointe sur le caract�re trait�               */
/*           COULEUR   = Pointe sur l'attribut (ou la couleur)        */
/* Sortie : n�ant                                                     */
/**********************************************************************/

void GetChar( int Page, int Colonne, int Ligne,
              char *Caractere, int *Couleur)
{
 union REGS Register;                 /* Registres pour l'interruption*/
 int Dummy;                  /* Pour variables accessoires ou inutiles*/
 int PageCour;                               /* page d'�cran courante */
 int LigneCour;                                     /* Ligne courante */
 int ColonneCour;                                 /* Colonne courante */

 GetVideoMode(&Dummy, &Dummy, &PageCour);    /* Page d'�cran courante */
 GetCursorPos( PageCour, &ColonneCour, &LigneCour,   /* Pos courante  */
              &Dummy, &Dummy);                          /* du curseur */
 SetCursorPos(Page, Colonne, Ligne);         /* Positionne le curseur */
 Register.h.ah = 8;                           /* Num�ro de la fonction*/
 Register.h.bh = Page;                                /* Page d'�cran */
 int86(0x10, &Register, &Register); /* d�clenche l'interruption 10(h) */
 *Caractere = Register.h.al;  /* Lit les r�sultats dans les registres */
 *Couleur = Register.h.ah;            /* et les affecte aux variables */
 SetCursorPos(PageCour, ColonneCour, LigneCour); /* Curseur anc. pos. */
}

/**********************************************************************/
/* WRITECHAR : Affiche un caract�re avec son attribut                 */
/*             � une position donn�e de la page d'�cran indiqu�e      */
/* Entr�e :   PAGE      = Page d'�cran concern�e                      */
/*            CARACTERE = Caract�re � afficher                        */
/*            COULEUR   = Attribut ou couleur du caract�re            */
/* Sortie : n�ant                                                     */
/**********************************************************************/

void WriteChar( int Page, char Caractere, int Couleur)
{
 union REGS Register;                /* Registres pour l'interruption */

 Register.h.ah = 9;                          /* Num�ro de la fonction */
 Register.h.al = Caractere;                   /* Caract�re � afficher */
 Register.h.bh = Page;                                /* Page d'�cran */
 Register.h.bl = Couleur;          /* Couleur du caract�re � afficher */
 Register.x.cx = 1;                             /* Un seul exemplaire */
 int86(0x10, &Register, &Register); /* d�clenche l'interruption 10(h) */
}

/**********************************************************************/
/* WRITETEXT : Affiche une cha�ne de caract�re d' une certaine couleur*/
/*             � une position donn�e de la page d'�cran indiqu�e      */
/* Entr�e  :  PAGE     = page d'�cran concern�e                       */
/*            COLONNE  = Colonne o� d�bute la cha�ne                  */
/*            LIGNE    = Ligne o� d�bute la cha�ne                    */
/*            COULEUR  = Attribut ou couleur des caract�res           */
/*            TEXT     = Pointeur sur la cha�ne                       */
/* Sortie  : n�ant                                                    */
/* Info    : Text pointe sur un tableau de caract�res qui contient le */
/*           texte � afficher et se termine par le caract�re nul '\0' */
/**********************************************************************/

void WriteText( int Page, int Colonne, int Ligne, int Couleur,
                char *Text)
{
 union REGS InRegister,              /* Registres pour l'interruption */
            OutRegister;

 SetCursorPos(Page, Colonne, Ligne);         /* Positionne le curseur */

 InRegister.h.ah = 14;                       /* Num�ro de la fonction */
 InRegister.h.bh = Page;                              /* Page d'�cran */
 while (*Text)                       /* Affiche le texte jusqu'� '\0' */
  {
   WriteChar(Page, ' ', Couleur);             /* Couleur du caract�re */
   InRegister.h.al = *Text++;                            /* Caract�re */
   int86(0x10, &InRegister, &OutRegister);            /* Interruption */
  }
}

/**********************************************************************/
/* CLEARSCREEN : Efface les 80*25 caract�res de l'�cran et            */
/*               positionne le curseur en haut � gauche               */
/* Entr�e : n�ant                                                     */
/* Sortie : n�ant                                                     */
/**********************************************************************/

void ClearScreen( void )
{
 int PageCour;                               /* Page d'�cran courante */
 int Dummy;                                       /* Variable fant�me */

 ScrollUp(0, NORMAL, 0, 0, 79, 24);           /* Effacer tout l'�cran */
 GetVideoMode(&Dummy, &Dummy, &PageCour);    /* Page d'�cran courante */
 SetCursorPos(PageCour, 0, 0);               /* Positionne le curseur */
}

/**********************************************************************/
/**                    PROGRAMME PRINCIPAL                           **/
/**********************************************************************/

void main()

{
 int i, j, k, l;                             /* Variables d'it�ration */
 char Fleche[3];                  /* Nombre de fl�ches en format ASCII*/

 ClearScreen();                                     /* Efface l'�cran */
 for (i = 1; i < 25; i++)               /* Parcourt toutes les lignes */
  for (j = 0; j < 80; j++)                  /* et toutes les colonnes */
   {
    SetCursorPos(0, j, i);                   /* Positionne le curseur */
    WriteChar(0, i*80+j&255, NORMAL);         /* Affiche un caract�re */
   }
 ScrollDown(0, NORMAL, 5, 8, 19, 22);          /* Efface la fen�tre 1 */
 WriteText(0, 5, 8, INVERSE, "   Fen�tre 1   ");
 ScrollDown(0, NORMAL, 60, 2, 74, 16);         /* Efface la fen�tre 2 */
 WriteText(0, 60, 2, INVERSE, "   Fen�tre 2   ");
 WriteText(0, 30, 12, INVERSE | CLIGNOTANT, " >>>LA BIBLE PC<<< ");
 WriteText(0, 0, 0, INVERSE, "                      il reste ");
 WriteText(0, 40, 0, INVERSE,"fl�ches � tracer");
 for (i = 49; i >= 0 ; i--)                       /* Trace 50 fl�ches */
  {
   sprintf(Fleche, "%2d", i); /* Conversion du nombre en cha�ne ASCII */
   WriteText(0, 37, 0, INVERSE, Fleche);         /* affiche le nombre */
   for (j = 1; j < 16; j+= 2)         /* Fl�che compos�e de 16 lignes */
    {
     for (k = 0; k < j; k++)       /* Fabrique une ligne de la fl�che */
      {
       SetCursorPos(0, 12-(j>>1)+k, 9);           /* Fl�che fen�tre 1 */
       WriteChar(0, '*', CLAIR);
       SetCursorPos(0, 67-(j>>1)+k, 16);          /* Fl�che fen�tre 2 */
       WriteChar(0, '*', CLAIR);
      }
     ScrollDown(1, NORMAL, 5, 9, 19, 22); /* Fait d�filer la fen�tre 1*/
     ScrollUp(1, NORMAL, 60, 3, 74, 16);  /* Fait d�filer la fen�tre 2*/
     for (l = 0; l < 4000 ; l++)                  /* Boucle d'attente */
      ;
    }
   }
 ClearScreen();                                     /* Efface l'�cran */
}
