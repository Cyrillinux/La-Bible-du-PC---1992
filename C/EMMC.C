/***********************************************************************
*                               E M M C                                *
**--------------------------------------------------------------------**
*    Fonction       : Fournit quelques fonctions pour l'accŠs … la     *
*                     m‚moire EMS (Expanded Memory).                   *
**--------------------------------------------------------------------**
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 30/08/1988                                       *
*    DerniŠre modif.: 30/03/1992                                       *
**--------------------------------------------------------------------**
*    (MICROSOFT C)                                                     *
*    Cr‚ation       : CL /AC EMMC.C                                    *
*                   : LINK EMMC;                                       *
*    Appel          : EMMC                                             *
**--------------------------------------------------------------------**
*    (BORLAND TURBO C)                                                 *
*    Cr‚ation       : Avec l'instruction RUN dans la ligne de menu     *
*                     (sans fichier Project)                           *
*    Infos          : Notez bien que le modŠle de m‚moire Compact      *
*                     doit ˆtre s‚lectionn‚ avec l'instruction         *
*                     Option-Compiler-Model !                          *
***********************************************************************/

/*== Int‚grer les fichiers Include ===================================*/

#include <stdio.h>
#include <conio.h>
#include <dos.h>
#include <stdlib.h>
#include <string.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;           /* Nous nous bricolons un octet */
typedef unsigned int  WORD;
typedef BYTE          BOOL;                /* Comme BOOLEAN en Pascal */

/*== Macros ==========================================================*/

/*-- MK_FP compose un pointeur FAR sur un objet … partir d'une -------*/
/*-- adresse de segment et d'une adresse d'offset              -------*/

#ifdef MK_FP                             /* MK_FP … d‚j… ‚t‚ d‚fini ? */
  #undef MK_FP
#endif
#define MK_FP(seg, ofs) ((void far *)(((unsigned long)(seg)<<16)|(ofs)))

/*-- PAGE_ADR fournit un pointeur sur la page physique X -------------*/
/*-- … l'int‚rieur du Page Frame de la m‚moire EMS       -------------*/

#define PAGE_ADR(x) ((void *) (MK_FP(ems_frame_seg() + ((x)<<10), 0)))

/*== Constantes ======================================================*/

#define TRUE    ( 0 == 0 )    /* Constantes pour travailler avec BOOL */
#define FALSE   ( 1 == 0 )

#define EMS_INT 0x67        /* Nø d'interruption pour l'accŠs … l'EMM */
#define EMS_ERR -1                     /* Est renvoy‚ en cas d'erreur */

/*== Variables globales ==============================================*/

BYTE emm_ec;                /* Ici sont plac‚s les codes d'erreur EMM */

/***********************************************************************
*  Fonction         : E M S _ I N S T                                  *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine si une m‚moire EMS et un driver EMS    *
*                     correspondant (EMM) sont install‚s.              *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : TRUE si m‚moire EMS install‚e, sinon             *
*                     FALSE.                                           *
***********************************************************************/

BOOL ems_inst( void )
{
  static char   emm_name[] = { 'E', 'M', 'M', 'X', 'X', 'X', 'X', '0' };
  union REGS    regs; /* Registres processeur pour appel interruption */
  struct SREGS  sregs;  /* Registre segment pour l'appel interruption */

   /* Mettre en place pointeur sur noms dans en-tˆte driver de p‚riph.*/

  regs.x.ax = 0x3567;   /* Nø fct.: Rechercher vecteur interrupt 0x67 */
  intdosx( &regs, &regs, &sregs );   /* Appeler interruption DOS 0x21 */

  return (!memcmp( MK_FP(sregs.es, 10), emm_name, sizeof emm_name ));
                                                 /*TRUE si nom trouv‚ */
}

/***********************************************************************
*  Fonction         : E M S _ N U M _ P A G E                          *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine le nombre total de pages EMS.          *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : EMS_ERR en cas d'erreur, sinon le nombre de      *
*                     pages EMS.                                       *
***********************************************************************/

int ems_num_page( void )
{
  union REGS   regs;              /* Reg. proc. pour appel interrupt. */

  regs.h.ah = 0x42;            /* Nø fct.: D‚terminer nombre de pages */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  if( (int)(emm_ec = regs.h.ah) )    /* Une erreur est-elle apparue ? */
    return( EMS_ERR );                        /* OUI, afficher erreur */
  else                                                /* Pas d'erreur */
    return( regs.x.dx );         /* Renvoyer le nombre total de pages */
}

/***********************************************************************
*  Fonction         : E M S _ F R E E _ P A G E                        *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine le nombre de pages EMS encore libres.  *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : EMS_ERR en cas d'erreur, sinon le nombre de      *
*                     pages EMS libres.                                *
***********************************************************************/

int ems_free_page( void )
{
  union REGS  regs;   /* Registres processeur pour appel interruption */

  regs.h.ah = 0x42;            /* Nø fct.: D‚terminer nombre de pages */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  if((int)(emm_ec = regs.h.ah))      /* Une erreur est-elle apparue ? */
    return( EMS_ERR );                        /* OUI, afficher erreur */
  else                                                /* Pas d'erreur */
    return( regs.x.bx );           /* Renvoyer nombre de pages libres */
}

/***********************************************************************
*  Fonction         : E M S _ F R A M E _ S E G                        *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine l'adresse de segment du Page Frame EMS *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : EMS_ERR en cas d'erreur, sinon adresse segment   *
*                     du Page Frame.                                   *
***********************************************************************/

WORD ems_frame_seg( void )
{
  union REGS  regs;

  regs.h.ah = 0x41;            /* Nø fct.: adresse segment Page Frame */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  if( (int)(emm_ec = regs.h.ah) )    /* Une erreur est-elle apparue ? */
    return( EMS_ERR );                        /* OUI, afficher erreur */
  else                                                /* Pas d'erreur */
    return( regs.x.bx );               /* Renvoyer adresse de segment */
}

/***********************************************************************
*  Fonction         : E M S _ A L L O C                                *
**--------------------------------------------------------------------**
*  Fonction         : Alloue le nombre de pages sp‚cifi‚ et renvoie un *
*                     Handle pour l'accŠs … ces pages.                 *
*  Param. en entr‚e : PAGES : Nombre de pages … allouer                *
*                             (de 16 Ko chacune)                       *
*  Valeur Return    : EMS_ERR en cas d'erreur, sinon le Handle EMS.    *
***********************************************************************/

int ems_alloc(int pages)
{
  union REGS  regs;

  regs.h.ah = 0x43;                         /* Nø fct.: Allouer pages */
  regs.x.bx = pages;               /* Fixer nombre de pages … allouer */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  if( (int)(emm_ec = regs.h.ah) )    /* Une erreur est-elle apparue ? */
    return(EMS_ERR);                          /* OUI, afficher erreur */
  else                                                /* Pas d'erreur */
    return( regs.x.dx );                       /* Renvoyer Handle EMS */
}

/***********************************************************************
*  Fonction         : E M S _ M A P                                    *
**--------------------------------------------------------------------**
*  Fonction         : Calque une des pages logiques allou‚es sous le   *
*                     handle transmis sur la page physique du          *
*                     Page Frame.                                      *
*  Param. en entr‚e : HANDLE: Le Handle renvoy‚ par EMS_ALLOC.         *
*                     LOGP  : La page logique (0 … n-1)                *
*                     PHYSP : La page physique (0 … 3)                 *
*  Valeur Return    : FALSE en cas d'erreur, sinon TRUE.               *
***********************************************************************/

BOOL ems_map(int handle, int logp, BYTE physp)
{
  union REGS  regs;

  regs.h.ah = 0x44;                         /* Nø fct.: Fixer Mapping */
  regs.h.al = physp;                           /* Fixer page physique */
  regs.x.bx = logp;                             /* Fixer page logique */
  regs.x.dx = handle;                             /* Fixer Handle EMS */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  return( !(emm_ec = regs.h.ah) );
}

/***********************************************************************
*  Fonction         : E M S _ F R E E                                  *
**--------------------------------------------------------------------**
*  Fonction         : LibŠre … nouveau la m‚moire allou‚e sous un      *
*                     Handle.                                          *
*  Param. en entr‚e : HANDLE: le Handle renvoy‚ par EMS_ALLOC.         *
*  Valeur Return    : FALSE en cas d'erreur, sinon TRUE.               *
***********************************************************************/

BOOL ems_free(int handle)
{
  union REGS  regs;

  regs.h.ah = 0x45;                         /* Nø fct.: Lib‚rer pages */
  regs.x.dx = handle;                             /* Fixer Handle EMS */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  return( !(emm_ec = regs.h.ah) ); /* Si AH contient 0, tout va bien. */
}

/***********************************************************************
*  Fonction         : E M S _ V E R S I O N                            *
**--------------------------------------------------------------------**
*  Fonction         : D‚termine le num‚ro de version EMM.              *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : EMS_ERR en cas d'erreur, sinon le num‚ro de      *
*                     version EMM.                                     *
*  Infos            : Pour le nø de version, 10 signifie 1.0, 11       *
*                     signifie 1.1, 34 signifie 3.4 etc.               *
***********************************************************************/

BYTE ems_version( void )
{
  union REGS  regs;

  regs.h.ah = 0x46;                /* Nø fct.: D‚terminer version EMM */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  if( (int)(emm_ec = regs.h.ah) )    /* Une erreur est-elle apparue ? */
    return( EMS_ERR );                        /* OUI, afficher erreur */
  else             /* Pas d'erreur, nø version … partir du nombre BCD */
    return( (regs.h.al & 15) + (regs.h.al >> 4) * 10 );
}

/***********************************************************************
*  Fonction         : E M S _ S A V E _ M A P                          *
**--------------------------------------------------------------------**
*  Fonction         : Sauvegarde le calquage (Mapping) entre pages     *
*                     logiques et physiques.                           *
*  Param. en entr‚e : HANDLE: le handle renvoy‚ par EMS_ALLOC.         *
*  Valeur Return    : FALSE en cas d'erreur, sinon TRUE.               *
***********************************************************************/

BOOL ems_save_map(int handle)
{
  union REGS  regs;

  regs.h.ah = 0x47;                   /* Nø fct.: Sauvegarder Mapping */
  regs.x.dx = handle;                             /* Fixer Handle EMS */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  return (!(emm_ec = regs.h.ah));  /* Si AH contient 0, tout va bien. */
}

/***********************************************************************
*  Fonction         : E M S _ R E S T O R E _ M A P                    *
**--------------------------------------------------------------------**
*  Fonction         : R‚tablit un calquage entre pages logiques et     *
*                     physiques sauvegard‚ pr‚alablement avec          *
*                     EMS_SAVE_MAP.                                    *
*  Param. en entr‚e : HANDLE: le handle renvoy‚ par EMS_ALLOC.         *
*  Valeur Return    : FALSE en cas d'erreur, sinon TRUE.               *
***********************************************************************/
BOOL ems_restore_map(int handle)
{
  union REGS  regs;

  regs.h.ah = 0x48;                      /* Nø fct.: R‚tablir Mapping */
  regs.x.dx = handle;                             /* Fixer Handle EMS */
  int86( EMS_INT, &regs, &regs );                      /* Appeler EMM */
  return( !(emm_ec = regs.h.ah) ); /* Si AH contient 0, tout va bien. */
}

/***********************************************************************
*  Fonction         : P R I N T _ E R R                                *
**--------------------------------------------------------------------**
*  Fonction         : Sort un message d'erreur EMS sur l'‚cran et      *
*                     termine le programme.                            *
*  Param. en entr‚e : Aucun                                            *
*  Valeur Return    : Aucune                                           *
*  Infos            : Cette fonction ne doit ˆtre appel‚e que si une   *
*                     erreur s'est produite lors d'un appel ant‚rieur  *
*                     d'une fonction de l'EMM.                         *
***********************************************************************/

void print_err( void )
{
  static char     nid[] = "non identifiable";
  static char     *err_vec[] =
  {
    "Erreur dans le driver EMS (EMM d‚truit)",                /* 0x80 */
    "Erreur dans l'‚lectronique EMS",                         /* 0x81 */
     nid,                                                     /* 0x82 */
    "Handle EMM incorrect",                                   /* 0x83 */
    "Fonction EMS appel‚e n'existe pas",                      /* 0x84 */
    "Plus de handles EMS disponibles",                        /* 0x85 */
    "Erreur de sauvegarde ou de reconstitution du Mapping",   /* 0x86 */
    "Plus de pages r‚clam‚es qu'il n'en existe physiquement", /* 0x87 */
    "Plus de pages r‚clam‚es qu'il n'en reste de libres",     /* 0x88 */
    "Z‚ro page r‚clam‚e",                                     /* 0x89 */
    "Page logique ne correspondant pas au Handle",            /* 0x8A */
    "Num‚ro de page physique incorrect",                      /* 0x8B */
    "Zone de m‚moire Mapping pleine",                         /* 0x8C */
    "Sauvegarde du Mapping d‚j… effectu‚e",                   /* 0x8D */
    "Reconstitution du Mapping sans sauvegarde ant‚rieure"
   };

  printf("\nATTENTION ! Erreur lors de l'accŠs … la m‚moire EMS\n");
  printf("         ... %s\n", (emm_ec<0x80 || emm_ec>0x8E)
                               ? nid
                               : err_vec[emm_ec-0x80]);
  exit( 1 );                 /* Terminer programme avec code d'erreur */
}

/***********************************************************************
*  Fonction        :   V R _ A D R                                     *
**--------------------------------------------------------------------**
*  Fonction      :   Fournit un pointeur sur la RAM vid‚o              *
*  Entr‚e        :   Aucune                                            *
*  Sortie        :   Pointeur sur la RAM vid‚o                         *
***********************************************************************/

void *vr_adr( void )
{
  union REGS  regs;

  regs.h.ah = 0x0f;                 /* Nø fct.: D‚terminer mode vid‚o */
  int86(0x10, &regs, &regs);    /* Appeler interruption vid‚o du BIOS */
  return( MK_FP(((regs.h.al==7) ? 0xb000 : 0xb800), 0) );
}

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()
{
 int  nmbpage,                                 /* Nombre de pages EMS */
      handle,                 /* Handle pour l'accŠs … la m‚moire EMS */
      i;                                        /* Compteur de boucle */
 WORD pageseg;                    /* Adresse de segment du Page Frame */
 BYTE emmver;                           /* Num‚ro de version de l'EMM */

 printf("EMMC  -  (c) 1988, 92 by MICHAEL TISCHER\n\n");
 if( ems_inst() )                          /* M‚moire EMS install‚e ? */
 {                                                             /* Oui */
    /*-- Sortir des informations sur la m‚moire EMS ------------------*/
   if( (int)(emmver = ems_version()) == EMS_ERR)     /* nø de version */
     print_err();     /* Erreur : Sortir message d'erreur et terminer */
   else                                               /* Pas d'erreur */
     printf("Num‚ro de version EMM        : %d.%d\n",
           emmver/10, emmver%10);

   if( (nmbpage = ems_num_page()) == EMS_ERR)        /* nmb. de pages */
     print_err();            /* Erreur : message d'erreur et terminer */
   else
     printf("Nombre de pages EMS          : %d (%d Ko)\n",
          nmbpage, nmbpage << 4);

   if( (nmbpage = ems_free_page()) == EMS_ERR )
     print_err();            /* Erreur : message d'erreur et terminer */
   else
     printf("... dont libres              : %d (%d Ko)\n",
          nmbpage, nmbpage << 4);

   if( (int) (pageseg = ems_frame_seg()) == EMS_ERR )
     print_err();            /* Erreur : message d'erreur et terminer */
   else
     printf("Adresse de segment du Page Frame : %X\n", pageseg);

   printf("\nUne page de la m‚moire EMS va maintenant ˆtre\n");
   printf("allou‚e et le contenu de l'‚cran va ˆtre copi‚ de la\n");
   printf("RAM vid‚o dans cette page.\n");
   printf("                    ... Veuillez frapper une touche\n");
   getch();                                    /* Attendre une touche */

   /*-- Allouer une page et la calquer sur la premiŠre page ----------*/
   /*-- logique dans le Page Frame                          ----------*/
   if( (handle = ems_alloc(1)) == EMS_ERR )
     print_err();            /* Erreur : message d'erreur et terminer */
   if( !ems_map(handle, 0, 0) )                      /* Fixer Mapping */
     print_err();            /* Erreur : message d'erreur et terminer */

   /*-- Copier 4000 octets de la RAM vid‚o dans la m‚moire EMS -------*/

   memcpy( PAGE_ADR(0), vr_adr(), 4000 );

   for( i = 0; i < 24; ++i )                         /* Vider l'‚cran */
     printf("\n");

   printf("L'ancien contenu de l'‚cran a maintenant ‚t‚ effac‚ et\n");
   printf("est donc perdu. Cependant, comme il avait\n");
   printf("‚t‚ sauvegard‚ dans la m‚moire EMS, il peut ˆtre recopi‚\n");
   printf("dans la RAM vid‚o … partir de l….\n");
   printf("                   ... Veuillez frapper une touche\n");
   getch();                                    /* Attendre une touche */

   /*-- Recopier le contenu de la RAM vid‚o d'aprŠs la m‚moire EMS ---*/
   /*-- et lib‚rer … nouveau la m‚moire EMS allou‚e                ---*/

   memcpy( vr_adr(), PAGE_ADR(0), 4000 );           /* Recopier V-RAM */
   if( !ems_free(handle) )                         /* Lib‚rer m‚moire */
     print_err();            /* Erreur : message d'erreur et terminer */
   printf("FIN");
 }
 else                          /* Le driver EMS n'a pu ˆtre identifi‚ */
   printf("ATTENTION ! Pas de m‚moire EMS install‚e\n");
}
