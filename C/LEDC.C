/**********************************************************************/
/*                               L E D C                              */
/*--------------------------------------------------------------------*/
/*    Fonction      : Fixe les bits de l'indicateur d'‚tat du clavier */
/*                    du BIOS en allumant ou ‚teignant les diodes     */
/*                    ‚lectroluminescentes                            */
/*--------------------------------------------------------------------*/
/*    Auteur                : MICHAEL TISCHER                         */
/*    D‚velopp‚ le          : 22.08.1988                              */
/*    DerniŠre modification : 03.01.1992                              */
/*--------------------------------------------------------------------*/
/*    ModŠle de m‚moire : SMALL                                       */
/**********************************************************************/

/*== Fichiers d'inclusion ============================================*/

#include <stdio.h>
#include <dos.h>
#include <bios.h>

/*== Macros ==========================================================*/

#ifndef MK_FP                                /* MK_FP est-il d‚fini ? */
  #define MK_FP(seg, ofs) \
		 ((void far *) ((unsigned long) (seg)<<16|(ofs)))
#endif

/*-- BIOS_KBF cr‚e un pointeur sur l'indicateur du clavier -----------*/

#define BIOS_KBF ((unsigned far *) MK_FP(0x40, 0x17))

#define TICKS(ms) ((ms*10+549) / 550 )
		      /*Convertit les millisecondes en tops d'horloge */

/*== Constantes ======================================================*/

#define SCRL  16                                   /* Bit Scroll Lock */
#define NUML  32                                      /* Bit Num-Lock */
#define CAPL  64                                     /* Bit Caps-Lock */
#define INS  128                                        /* Bit Insert */

#ifdef __TURBOC__                         /* D‚finitions pour TURBO C */
   #define GetBiosTime(x)    ( x = biostime( 0, NULL ) )
#else                   /* Definitions pour le compilateur Microsoft C*/
   #define GetBiosTime(x)    ( _bios_timeofday( _TIME_GETCLOCK, &x) )
#endif

/**********************************************************************/
/*  Delay  : Arrˆte l'ex‚cution du programme pendant un certain       */
/*           temps ind‚pendamment de la vitesse du systŠme            */
/*  Entr‚e : PAUSE = temps d'arrˆt d‚compt‚ en tops d'horloge         */
/*  Sortie : n‚ant                                                    */
/*  Info   : un top d'horloge = 1/18,2 secondes                       */
/**********************************************************************/

void delay( unsigned int pause )
{
 long temps,                                       /*Temps instantan‚ */
      tempslimite;                                      /* Temps fix‚ */

 if ( pause )                                          /* Pause # 0 ? */
  {                                                            /* Non */
   GetBiosTime( tempslimite );
   tempslimite += (long) pause;            /* Calcule le temps limite */

   do                    /* Boucle d'attente, lit le temps instantan‚ */
    GetBiosTime( temps );
   while ( temps < tempslimite );           /* Temps limite atteint ? */
  }                                                   /* Oui, termin‚ */
}

/***********************************************************************
*          : S E T _ F L A G                                           *
**--------------------------------------------------------------------**
*  Fonction : Met … 1 des bits de  l'indicateur d'‚tat du clavier      *
*  Entr‚e   : FLAG = Bits … mettre … 0                                 *
*  Sortie   : n‚ant                                                    *
***********************************************************************/

void set_flag( unsigned flag )
{
 union REGS regs;                /* M‚morise le contenu des registres */

 *BIOS_KBF |= flag;                      /* Met … 1 les bits indiqu‚s */
 regs.h.ah = 1;     /* Num‚ro de la fonction : caractŠre disponible ? */
 int86(0x16, &regs, &regs);        /* D‚clenche l'interruption du BIOS*/
}

/***********************************************************************
*                     C L R _ F L A G                                  *
**--------------------------------------------------------------------**
*  Fonction : Met … 0 des bits de l'indicateur du clavier              *
*  Entr‚e   : FLAG = Bits … mettre … 0.                                *
*  Sortie   : n‚ant                                                    *
***********************************************************************/

void clr_flag( unsigned flag )
{
 union REGS regs;                /* M‚morise le contenu des registres */

 *BIOS_KBF &= ~flag;                     /* Met … 0 les bits indiqu‚s */
 regs.h.ah = 1;     /* Num‚ro de la fonction : caractŠre disponible ? */
 int86(0x16, &regs, &regs);       /* D‚clenche l'interruption du BIOS */
}

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()
{
 unsigned i;                                 /* Compteur d'it‚rations */

 printf( "LEDC  -  (c) 1988, 1992 by Michael Tischer\n\n");
 printf( "Observez les LEDs de votre clavier !\n");

 for (i=0; i<10; ++i)                                /* 10 it‚rations */
  {
   set_flag( CAPL );                                   /* Allume CAPS */
   delay( TICKS(100) );                   /* Attend 100 millisecondes */
   clr_flag( CAPL );                                   /* Eteint CAPS */
   set_flag( NUML);                                     /* Allume NUM */
   delay( TICKS(100) );                    /* Attend 100 millisecodes */
   clr_flag( NUML );                                    /* Eteint NUM */
   set_flag( SCRL);                             /* Allume SCROLL-LOCK */
   delay( TICKS(100) );                   /* Attend 100 millisecondes */
   clr_flag( SCRL );                            /* Eteint SCROLL-LOCK */
  }

 for (i=0; i<10; ++i)                               /* 10 it‚rations */
  {
   set_flag(CAPL | SCRL | NUML);     /* Allume les trois indicateurs */
   delay( TICKS(500) );                             /* Attend 200 ms */
   clr_flag(CAPL | SCRL | NUML);     /* Eteint les trois indicateurs */
   delay( TICKS(500) );                             /* Attend 200 ms */
  }
}
