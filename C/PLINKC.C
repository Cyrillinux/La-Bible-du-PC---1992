/**********************************************************************/
/*                          P L I N K C . C                           */
/*--------------------------------------------------------------------*/
/*    Fonction       : transmet des fichiers par le port parallŠle    */
/*--------------------------------------------------------------------*/
/*    Auteur         : Michael Tischer                                */
/*    D‚velopp‚ le   : 27.09.1991                                     */
/*    DerniŠre MAJ   : 28.11.1991                                     */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire : SMALL                                          */
/**********************************************************************/

/*== Fichiers d'inclusion      =======================================*/

#include <stdlib.h>
#include <stdio.h>
#include <conio.h>
#include <dos.h>
#include <setjmp.h>
#include <string.h>
#ifdef __TURBOC__                            /* Compilateur Turbo C ? */
  #include <dir.h>            /* En-tˆtes des fonctions de traitement */
  #include <ctype.h>                               /* des r‚pertoires */
#endif

/*== D‚finitions de types ============================================*/

typedef unsigned char BYTE;                       /* D‚finit un octet */
typedef unsigned int WORD;                  /* Bricolage du type WORD */
typedef struct {                 /* En-tˆte de transmission des blocs */
                BYTE         Token;
                unsigned int Len;
               } BHEADER;

/*== Fonctions du module en assembleur ==============================*/

extern void IntrInstall( int far  * escape_flag,
                         WORD far * timeout_count );
extern void IntrRemove( void );
extern void EscapeDirect( int ausloesen );

/*== Constantes ======================================================*/

#define UNESEC        18                               /* Une seconde */
#define DIXSEC        182                             /* Dix secondes */
#define TO_DEFAULT    DIXSEC         /* Valeur de Time-Out par d‚faut */

#define TRUE          ( 0 == 0 )
#define FALSE         ( 0 == 1 )
#define MAXBLOC      4096        /* Taille des blocs 4 Ko ( Cluster ) */

/*-- Constantes pour le protocole de transmission-------------------*/

#define ACK           0x00                     /* Accus‚ de r‚ception */
#define NAK           0xFF                 /* Non-Accus‚ de r‚ception */
#define MAX_TRY       5          /* Nombre de tentatives avant erreur */

/*-- Tokens pour la communication entre ‚metteur et r‚cepteur ------*/

#define TOK_DATSTART  0                           /* D‚but de fichier */
#define TOK_DATNEXT   1                  /* Bloc suivant d'un fichier */
#define TOK_DATEND    2           /* Transmission du fichier termin‚e */
#define TOK_FIN       3                      /* Terminer le programme */
#define TOK_ESCAPE    4/* Interruption par ESC sur ordinateur distant */

/*-- Codes pour les appels LongJump ----------------------------------*/

#define LJ_OKEMET     1        /* Tous les fichiers correctement ‚mis */
#define LJ_OKRECEPT   2       /* Tous les fichiers correctement re‡us */
#define LJ_TIMEOUT    3   /* Time-out: le correspondant ne r‚pond pas */
#define LJ_ESCAPE     4/*Interruption par Escape sur ordinateur local */
#define LJ_REMESCAPE  5 /* Interruption Escape sur ordinateur distant */
#define LJ_DATA       6                    /* Erreur de communication */
#define LJ_NOLINK     7                             /* Pas de liaison */
#define LJ_NOPAR      8                            /* Pas d'interface */
#define LJ_PARA       9               /* ParamŠtres d'appel invalides */

/*== Macros ==========================================================*/
/*-- Les trois bits inf‚rieurs du registre d'entr‚e ne sont pas     --*/
/*-- utills‚s selon les systŠmes ils peuvent ˆtre … 1 ou 0 , ici    --*/
/*-- ils sont ‚limin‚s par GetB() .                                 --*/

#ifdef __TURBOC__                            /* Compilateur Turbo C ? */
  #define GetB()                         ( inportb( PortdEntree ) & 0xF8 )
  #define PutB( QuelqueChose )           outportb( PortdeSortie, QuelqueChose )
  #define DIRSTRUCT                      struct ffblk
  #define FINDFIRST( path, buf, attr )   findfirst( path, buf, attr )
  #define FINDNEXT( buf )                findnext( buf )
  #define NomFichier                      ff_name
#else                                            /* Non , Microsoft C */
  #define GetB()                         ( inp( PortdEntree ) & 0xF8 )
  #define PutB( QuelqueChose )                    outp( PortdeSortie, QuelqueChose )
  #define DIRSTRUCT                      struct         find_t
  #define FINDFIRST( path, buf, attr )   _dos_findfirst(path, attr, buf)
  #define FINDNEXT( buf )                _dos_findnext( buf )
  #define NomFichier                      name
#endif

#ifdef MK_FP                            /* Macro MK_FP d‚j… d‚finie ? */
  #undef MK_FP                                     /* Oui on l'efface */
#endif

#define MK_FP(seg,ofs) ((void far *) ((unsigned long) (seg)<<16|(ofs)))

/*== Variables globales ==============================================*/

int     PortdEntree;                      /* Adresse du port d'entr‚e */
int     PortdeSortie;                    /* Adresse du port de sortie */
int     Escape = 0;                  /* Pas de touche ESCAPE enfonc‚e */
WORD    Timeout = TO_DEFAULT;                   /* Valeur de Time Out */
WORD    TO_Count;                              /* Compteur de Timeout */
jmp_buf Branchement;               /* Adresse de retour pour terminer */
BYTE    *BlocBuf;                 /* Buffer de m‚morisation d'un bloc */
FILE    *Fichier = NULL;  /* Variable fichier pour traiter un fichier */

/**********************************************************************/
/* GetPortAdr    : Initialise les adresses des ports d'une interface  */
/*                 parallŠle … l'aide des variables PortdEntr‚e et    */
/*                 Portde Sortie                                      */
/* Entr‚e        : NUMMER = Num‚o de l'interface parallŠle (1-4)      */
/* Sortie        : TRUE, si l'interface est valable                   */
/* Var. globales : PortdEntree/W, PortdeSortie/W                      */
/* Info          : Les adresses de base des interfaces parallŠles     */
/*                 (en nombre de 1 … 4) se trouvent dans les mots     */
/*                 m‚moires commen‡ant en 0040:0008                   */
/**********************************************************************/

int GetPortAdr( int Numero )
{  /* Lit les adresses des ports dans le segment de variables du BIOS */
 PortdeSortie = *( WORD far * ) MK_FP( 0x0040, 6 + Numero * 2 );
 if ( PortdeSortie != 0 )                   /* Interface disponible ? */
  {                                                            /* Oui */
   PortdEntree = PortdeSortie + 1;/* Adresse pour le registre d'entr‚e*/
   return TRUE;                                       /* Pas d'erreur */
  }
 else
  return FALSE;                          /* Erreur: interface absente */
}

/**********************************************************************/
/* Port_Init     : Initialise les registres n‚cessaires … la          */
/*                 transmission                                       */
/* Entr‚e        : EMETTEUR=TRUE, si ‚metteur, FALSE, si r‚cepteur    */
/* Sortie        : TRUE, si les reg. ont ‚t‚ correctement initialis‚s */
/* Var. globales : PortdEntree/R, PortdeSortie/R                      */
/* Info          : La dissym‚trie: envoie 00010000, attend 00000000   */
/*                 est rendue n‚cessaire par l'inversion du signal.   */
/*                 Normalement les registres d'entr‚e et de sortie    */
/*                 contiennent les valeurs souhait‚es mais            */
/*                 l'initialisation est n‚cessaire lorsqu'on reprend  */
/*                 une transmission interrompue                       */
/**********************************************************************/

int Port_Init( int Emetteur )
{
 EscapeDirect( TRUE );             /* D‚clenche un Time Out si Escape */
 if ( Emetteur )                      /* L'appareil est-il ‚metteur ? */
 {
  TO_Count = Timeout * 5;       /* Initialise le compteur de Time Out */
  PutB( 0x10 );                                 /* Envoie : 00010000b */
  while ( ( GetB() != 0x00 ) && TO_Count )      /* Attend : 00000000b */
   ;
  }
 else                                     /* L'appareil est r‚cepteur */
  {
   TO_Count = Timeout * 5;      /* Initialise le compteur de Time Out */
   while ( ( GetB() != 0x00 ) && TO_Count )     /* Attend : 00000000b */
    ;
   PutB( 0x10 );                                /* Envoie : 00010000b */
  }
 EscapeDirect( FALSE );                   /* Si Escape pas de Timeout */
 return ( TO_Count != 0 );                 /* Initialisation termin‚e */
}

/**********************************************************************/
/* EmetOctet     : Envoie un octet en deux parties … l'ordinateur     */
/*                 distant et teste le r‚sultat                       */
/* Entr‚e        : VALEUR: octet … ‚mettre                            */
/* Sortie        : Transmission correcte ? ( 0 = Erreur , -1 = ok )   */
/* Var. globales : Timeout/R, PortdEntrer/R, PortdeSortie/R (macros)  */
/**********************************************************************/

int EmetOctet( BYTE Valeur )
{
 BYTE Retour;                                    /* Octet r‚ceptionn‚ */

/*-- Emet le quartet inf‚rieur ---------------------------------------*/

 TO_Count = Timeout;             /* Initialise le compteur de Timeout */
 PutB( Valeur & 0x0F );                /* Envoi avec mise … 0 de BUSY */
 while ( ( ( GetB() & 128 ) == 0 ) && TO_Count )  /* Attend le retour */
  ;
 if ( TO_Count == 0 )                           /* Erreur de Timeout ?*/
  longjmp( Branchement, LJ_TIMEOUT );   /* Interrompt la transmission */

 Retour = ( GetB() >> 3 ) & 0x0F;                 /* Bits 3-6 en  0-3 */

/*-- Emet le quartet sup‚rieur ---------------------------------------*/

 TO_Count = Timeout;             /* Initialise le compteur de Timeout */
 PutB( ( Valeur >> 4 ) | 0x10 );       /* Envoi avec mise … 1 de BUSY */
 while ( ( ( GetB() & 128 ) != 0 ) && TO_Count )   /* Atend le retour */
  ;

 if ( TO_Count == 0 )                          /* Erreur de Timeout ? */
  longjmp( Branchement, LJ_TIMEOUT );   /* Interrompt la transmission */

 Retour = Retour | ( ( GetB() << 1 ) & 0xF0 );     /* Bits 3-6 en 4-7 */
 return ( Valeur == Retour );        /* Octet correctement transmis ? */
}

/**********************************************************************/
/* RecOctet      : R‚ceptionne un octet en deux parties de la part    */
/*                 d'un ordinateur distant et renvoie les parties     */
/*                 pour v‚rification                                  */
/* Entr‚e        : n‚ant                                              */
/* Sortie        : Octet re‡u                                         */
/* Var. globales : Timeout/R, PortdEntree/R, PortdeSortie/R (Macros)  */
/**********************************************************************/

BYTE RecOctet( void )
{
 BYTE LoNib, HiNib;                                 /* Quartets re‡us */

      /*-- R‚ceptionne le quartet inf‚rieur et le renvoie ------------*/

 TO_Count = Timeout;             /* Initialise le compteur de Timeout */
 while ( ( ( GetB() & 128 ) == 0 ) && TO_Count )/* Attend que BUSY =1 */
  ;

 if ( TO_Count == 0 )                           /* Erreur de Timeout ?*/
  longjmp( Branchement, LJ_TIMEOUT );   /* Interrompt la transmission */

 LoNib = ( GetB() >> 3 ) & 0x0F;                 /* Bits 3-6 dans 0-3 */
 PutB( LoNib );                                            /* Renvoie */

/*-- R‚ceptionne le quartet sup‚rieur et le renvoie ------------------*/

 TO_Count = Timeout;            /* Initialise le compteur de Time Out */
 while ( ( ( GetB() & 128 ) != 0 ) && TO_Count ) /* Attend que BUSY 0 */
  ;

 if ( TO_Count == 0 )                          /* Erreur de Timeout ? */
  longjmp( Branchement, LJ_TIMEOUT );   /* Interrompt la transmission */

 HiNib = ( GetB() << 1 ) & 0xF0;                   /* Bits 3-6 en 4-7 */
 PutB( ( HiNib >> 4 ) | 0x10 );            /* Renvoie et met Busy … 1 */

 return( LoNib | HiNib );                            /* Octet renvoy‚ */
}

/**********************************************************************/
/* EmetBloc  : Envoi un bloc de donn‚es                               */
/* Entr‚es   : TOKEN  = Commande pour le r‚cepteur                    */
/*             NOMBRE = Nombre d'octets  … transmettre                */
/*             DONNEES= Pointeur sur le buffer des donn‚es            */
/* Sortie    : n‚ant, en cas d'erreur branchement par                 */
/*             LongJmp … la routine de traitement d'erreur            */
/**********************************************************************/

void EmetBloc( BYTE Token, int Nombre, void *Donnees )
{
 BHEADER header;            /* En-tˆte pour m‚moriser Token et Nombre */
 BYTE    *bptr,               /* Pointe sur l'octet courant … ‚mettre */
     RecEscape;      /* A-t-on tap‚ ESCAPE sur l'ordinateur distant ? */
 int     ok,                                   /* Indicateur d'erreur */
     i,                                      /* Compteur d'it‚rations */
     try;                                 /* Nombre d'essais restants */

 if ( Escape )             /* A-t-on tap‚ Escape sur cet ordinateur ? */
  {
   Token = TOK_ESCAPE;                  /* Oui envoie le token Escape */
   Nombre = 0;
  }

      /*-- Emission de l'en-tˆte -------------------------------------*/

 header.Token = Token;                         /* Construit l'en-tˆte */
 header.Len = Nombre;

 for ( try = MAX_TRY; try; --try )   /* Au maximum MAX_TRY tentatives */
  {
   ok = TRUE;                   /* A priori la transmission est bonne */
   for ( bptr = (BYTE *) &header, i = sizeof( header); i; --i )
     ok = ok & EmetOctet( *bptr++ );                 /* Emet un octet */

   ok = ok & EmetOctet( (BYTE) (ok ? ACK : NAK) );     /*Confirmation */
   if ( ok )                               /* Transmission correcte ? */
     break;                             /* Oui, pas d'autre tentative */
  }

 if ( try == 0 )               /* L'en-tˆte a-t-il pu ˆtre transmis ? */
  longjmp( Branchement, LJ_DATA );    /* Non, arrˆter la transmission */

 if ( Token == TOK_ESCAPE )        /* A-t-on envoy‚ l'avis d'ESCAPE ? */
  longjmp( Branchement, LJ_ESCAPE );  /* Oui, arrˆter la transmission */

   /*-- Emission du bloc de donn‚es proprement dit -------------------*/

 if ( Nombre )                                   /* Taille diff de 0? */
  {
   for ( try = MAX_TRY; try; -- try )/* MAX_TRY tentatives au maximum */
    {
     ok = TRUE;                 /* A priori la transmission est bonne */
     for ( bptr = (BYTE *) Donnees, i = Nombre; i; --i )
       ok = ok & EmetOctet( *bptr++ );/*Envoie octet et interroge ‚tat*/

     ok = ok & EmetOctet( (BYTE) (ok ? ACK : NAK) );  /* Confirmation */
     if ( ok )                             /* Transmission correcte ? */
       break;                            /* Oui pas d'autre tentative */
    }
   if ( try == 0 )           /* Les donn‚es ont-elle ‚t‚ transmises ? */
    longjmp( Branchement, LJ_DATA );  /* Non, interrompt transmission */
  }

  /*-- Teste l'octet ESCAPE du r‚cepteur -----------------------------*/

 for ( try = MAX_TRY; try; -- try )           /* Nombre de tentatives */
  {
   RecEscape = RecOctet();               /* D‚tecte un escape distant */
   if ( RecEscape == (BYTE) TRUE  ||  RecEscape == (BYTE) FALSE )
    break;                           /* Etat de la touche Escape re‡u */
  }
 if ( try == 0 )      /* L'‚tat de la touche Escape a-t-il ‚t‚ re‡u ? */
  longjmp( Branchement, LJ_DATA ); /* Non, interrompt la transmission */

 if ( RecEscape )                  /* Escape sur ordinateur distant ? */
  longjmp( Branchement, LJ_REMESCAPE );/* Oui interrompt transmission */
}

/**********************************************************************/
/* RecBloc : R‚ceptionne un bloc de donn‚es                           */
/* Entr‚e  : TOKEN   = Pointeur sur la variable qui m‚morise le token */
/*           LEN     = Pointeur sur la variable qui m‚morise la long. */
/*           DONNEES = Pointeur sur le buffer des donn‚es             */
/* Sortie  : n‚ant, en cas d'erreur branchement sur routine d'erreur  */
/*           par LongJmp                                              */
/* Info    : Le buffer transmis doit pr‚voir de la place pour MAXBLOC */
/*           pour MAXBLOC octets, la taille du bloc ne pouvant pas    */
/*           ˆtre anticip‚e                                           */
/**********************************************************************/

void RecBloc( BYTE *Token, int *Len, void *Donnees )
{
 BHEADER header;                                /* M‚morise l'en-tˆte */
 BYTE    *bptr;       /* Pointeur courant dans le buffer de r‚ception */
 int     ok,                                   /* Indicateur d'erreur */
     i,                                      /* Compteur d'it‚rations */
     try,                           /* Nombre de tentatives restantes */
     EscapeStatus;     /* M‚morise l'‚tat courant de la touche Escape */

 /*-- R‚ceptionne d'abord l'en-tˆte ----------------------------------*/

 for ( try = MAX_TRY; try; -- try )  /* MAX_TRY tentatives au maximum */
  {
   for ( bptr = (BYTE *) &header, i = sizeof(header); i; --i )
     *bptr++ = RecOctet( );

   if ( RecOctet() == ACK );          /* Tous les octets bien re‡us ? */
     break;                                 /* Oui pluss de tentative */
  }

 if ( try == 0 )                       /* En-tˆte correctement re‡u ? */
  longjmp( Branchement, LJ_DATA ); /* Non, interrompre la transmission*/

 if ( ( *Token = header.Token ) == TOK_ESCAPE )   /* Emetteur ESCAPE? */
  longjmp( Branchement, LJ_REMESCAPE );/* Oui interrompt transmission */

      /*-- L'en-tˆte est bon, il faut passer au bloc des donn‚es . ---*/

 if ( ( *Len = header.Len ) != 0 )       /* Pas de bloc des donn‚es ? */
  {                                                             /* si */
   for ( try = MAX_TRY; try; -- try )/* MAX_TRY tentatives au maximum */
    {
     for ( bptr = (BYTE *) Donnees, i = header.Len; i; --i )
       *bptr++ = RecOctet( );

     if ( RecOctet() == ACK );        /* Tous les octets bien re‡us ? */
      break;                                /* Oui, plus de tentative */
    }

  if ( try == 0 )           /* Le bloc a-t-il ‚t‚ correctement re‡u ? */
   longjmp( Branchement, LJ_DATA );/* Non, interrompt la transmission */
  }

 /*-- Envoie l'‚tat actuel de la touche Escape … l'ordinateur distant */

 EscapeStatus = Escape;                            /* M‚morise l'‚tat */
 for ( try = MAX_TRY; try; -- try )         /* Nombre de tentatives   */
  {
   if ( EmetOctet( (BYTE) (EscapeStatus != 0) ) )         /* arriv‚ ? */
    break;                     /* Oui, plus de tentative n‚cessaire   */
  }

 if ( try == 0 )                /* L'‚tat ESC a-t-il pu ˆtre envoy‚ ? */
   longjmp( Branchement, LJ_DATA );/* Non, interrompt la transmission */

 if ( EscapeStatus )      /* A-t-on actionn‚ Esc sur cet ordinateur ? */
  longjmp( Branchement, LJ_ESCAPE );/*Oui, interrompt la transmission */
}

/**********************************************************************/
/* EmetFichier : Envoie un fichier                                    */
/* Entr‚e      : NOM = Ptr sur un buffer contenant le nom du fichier  */
/* Sortie      : n‚ant                                                */
/**********************************************************************/

void EmetFichier( char *Nom  )
{
 int           Status;                             /* Etat d'‚mission */
 WORD          Lus;                            /* Nombre d'octets lus */
 unsigned long Taille;                     /* Nombre d'octets envoy‚s */

 printf( "%-13s", Nom);
 Fichier = fopen( Nom,"rb" );                     /* Ouvre le fichier */
 EmetBloc( TOK_DATSTART, strlen(Nom)+1, Nom );       /* envoie son nom*/

          /*-- TransfŠre le contenu du fichier -----------------------*/

 Taille = 0;
 do
  {
   Lus = fread( BlocBuf, 1, MAXBLOC, Fichier );       /* Lit un bloc  */
   if ( Lus > 0 )                                /* Est-on … la fin ? */
    {                                                          /* Non */
     EmetBloc( TOK_DATNEXT, Lus, BlocBuf );           /* Emet le bloc */
     Taille += Lus;
     printf( "\r%-13s (%ld)", Nom, Taille );
    }
  }
 while (  Lus > 0 );
 printf( "\n" );

 EmetBloc( TOK_DATEND, 0, NULL );          /* Cl“ture la transmission */

 fclose( Fichier );                             /* Referme le fichier */
 Fichier = NULL;                                     /* Fichier ferm‚ */
}

/**********************************************************************/
/* RecFichier  : R‚ceptionne un fichier                               */
/* Entr‚e      : n‚ant                                                */
/* Sortie      : Dernier token re‡u                                   */
/**********************************************************************/

int RecFichier( void )
{
 int           Status;                           /* Etat de r‚ception */
 WORD          AEnregistrer;                /* Taille du dernier bloc */
 unsigned long Taille;
 BYTE          Token;                            /* Token r‚ceptionn‚ */
 int           Len;                          /* Longueur du bloc re‡u */
 char          Name[13];                            /* Nom du fichier */

 RecBloc( &Token, &Len, BlocBuf );
 if ( Token == TOK_DATSTART )
  {
   strcpy( Name, BlocBuf );
   Fichier = fopen( Name, "wb" );          /* Ouvre (cr‚e) le fichier */
   printf( "%-13s", Name );

   /*-- R‚ceptionne le contenu du fichier ----------------------------*/

   Taille = 0;
   do
    {
     RecBloc( &Token, &Len, BlocBuf );         /* R‚ceptionne un bloc */
     if ( Token == TOK_DATNEXT )      /* Bloc de donn‚es cons‚cutif ? */
      {                                                         /* Ja */
       fwrite( BlocBuf, 1, Len, Fichier );              /* Enregistre */
       Taille += Len;
       printf( "\r%-13s (%ld)", Name, Taille );
      }
    }
   while ( Token == TOK_DATNEXT );
   fclose( Fichier );                           /* Referme le fichier */
   Fichier = NULL;                            /* Le fichier est ferm‚ */
   printf( "\n" );
  }
 return Token;                            /* Retourne l'‚tat d'erreur */
}

/**********************************************************************/
/*                           PROGRAMME PRINCIPAL                      */
/**********************************************************************/

void main( int argc, char *argv[] )
{
 DIRSTRUCT SRec;    /* Structure pour la recherche dans un r‚pertoire */
 BYTE      Emetteur;   /* Mode de transmission (Emission, R‚ception ) */
 int       sjStatus,                              /* Code de longjmup */
       Numero,                               /* Num‚ro de l'interface */
       i,                                    /* Compteur d'it‚rations */
       Trouve;                      /* Pour la recherche des fichiers */

 static char *Avis[ 9 ] =
  { "FIN: Tous les fichiers ont ‚t‚ correctement ‚mis",
    "FIN: Tous les fichiers ont ‚t‚ correctement re‡us",
    "ERREUR: Time-Out, le systŠme distant ne r‚pond pas",
    "FIN: Interruption par Escape.",
    "FIN: Interruption par Escape sur l'ordinateur distant.",
    "ERREUR: Interface ou cƒble d‚fectueux",
    "ERREUR: pas de contact avec l'ordinateur distant",
    "ERREUR: L'interface indiqu‚e n'existe pas !",
    "ERREUR: ParamŠtre inconnu ou invalide !" };

 printf( "\n\nTransmission de donn‚es par l'interface parallŠle    " );
 printf( "(c) 1991 by Michael Tischer\n" );
 printf( "=====================================================" );
 printf( "===========================\n\n" );

 if ( strcmp( argv[ 1 ], "?" ) == 0 )         /* Affiche la syntaxe ? */
  {                                                             /* oui*/
   printf( "Appel: plinkc [/Pn] [/Tnn] [Nom de Fichier]\n" );
   exit ( 0 );
  }

 sjStatus = setjmp( Branchement );               /* Adresse de retour */
 if ( sjStatus )                       /* Longjmp a-t-il ‚t‚ appel‚ ? */
  {                                                            /* Oui */
   IntrRemove( );         /* D‚sactive le gestionnaire d'interruption */
   if ( Fichier )                   /* Reste-t-il un fichier ouvert ? */
     fclose( Fichier );
   free( BlocBuf );                /* LibŠre la place m‚moire allou‚e */
   printf( "\n\n%s\n", Avis[ sjStatus - 1 ] );
   exit( 0 );
  }

 BlocBuf = malloc( MAXBLOC );      /* Cr‚e un buffer pour les donn‚es */
 IntrInstall( &Escape, &TO_Count );/* Initilialise driver interruption*/
 /*-- Fixe les paramŠtres par d‚faut et exploite la ligne de commande */

 Emetteur = FALSE;           /* Par d‚faut l'ordinateur est r‚cepteur */
 Numero = 1;                                  /* L'interface est LPT1 */

 for ( i = 1; i < argc; i++ )
  {
   if ( argv[i][0] == '/' )                             /* ParamŠtres */
    {
     switch ( toupper( argv[i][1] ) )
      {
       case 'T' : Timeout = (atol( &argv[i][2] ) * DIXSEC) / 10;
                  if ( Timeout == 0 )
           longjmp( Branchement, LJ_PARA );              /* incorrect */
                  break;
       case 'P' : Numero = argv[i][2] - 48;              /* Interface */
                  if ( Numero == 0   ||   Numero > 4 )
           longjmp( Branchement, LJ_PARA );              /* incorrect */
                  break;
       default  : longjmp( Branchement, LJ_PARA );/* paramŠtre inconnu*/
                  break;
      }
     argv[i][0] = '\0';                          /* Efface l'argument */
    }
   else         /* Pas de paramŠtre, il doit s'agir du nom du fichier */
    Emetteur = TRUE;                                      /* Emetteur */
  }

/*-- Lance la transmission -------------------------------------------*/

 if ( GetPortAdr(Numero) == FALSE )    /* L'interface existe-t-elle ? */
  longjmp( Branchement, LJ_NOPAR );                    /* Non, erreur */

 if ( Port_Init( Emetteur ) == FALSE )         /* Etablit  la liaison */
  longjmp( Branchement, LJ_NOLINK );        /* Erreur,  impossibilit‚ */

 if ( Emetteur )                                         /* Emetteur? */
  {
   printf( "Emission vers LPT%d:\n\n", Numero );

        /*-- Transmet tous les fichiers ------------------------------*/

   for ( i = 1; i < argc; i++ )      /* Parcourt la ligne de commande */
    {
     if ( argv[i][0] != '\0' )                    /* Nom du fichier ? */
      {                                                         /* Oui*/
       Trouve = FINDFIRST( argv[i], &SRec, 0);
       while ( !Trouve )
        {
         if ( SRec.NomFichier[0] != '.' )
      EmetFichier( SRec.NomFichier );              /*Fichier transmis */
         Trouve = FINDNEXT( &SRec );
        }
      }
    }
   EmetBloc( TOK_FIN, 0 , NULL );          /* Tous les fichiers ‚mis  */
   longjmp( Branchement, LJ_OKEMET );
  }
 else                                              /* Non, r‚cepteur  */
  {
   printf( "R‚ception sur LPT%d:\n\n", Numero );
   while ( RecFichier() != TOK_FIN )      /* R‚ceptionne les fichiers */
    ;                                         /* jusqu'au token final */
   longjmp( Branchement, LJ_OKRECEPT );
  }
}
