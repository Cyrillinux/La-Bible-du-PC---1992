/***********************************************************************
*                               M C B C . C                            *
**--------------------------------------------------------------------**
*    Fonction       : Permet de suivre le chaŒnage des blocs de        *
*                     m‚moire allou‚s par DOS                          *
**--------------------------------------------------------------------**
*    Auteur         : MICHAEL TISCHER                                  *
*    D‚velopp‚ le   : 23.08.1988                                       *
*    DernjiŠre MAJ  : 20.03.1982                                       *
**--------------------------------------------------------------------**
*    ModŠle m‚moire : SMALL                                            *
***********************************************************************/

/*== Fichiers d'inclusion  ===========================================*/

#include <stdio.h>
#include <dos.h>
#include <stdlib.h>
#include <conio.h>

/*== Typedef =========================================================*/

typedef unsigned char BYTE;               /* Bricolage d'un type Byte */
typedef unsigned int  WORD;
typedef BYTE          BOOLEAN;
typedef BYTE far      *FB;               /* Pointeur FAR sur un octet */

/*== Constantes ======================================================*/

#define TRUE  ( 0 == 0 )              /* Utilis‚ avec le type BOOLEAN */
#define FALSE ( 1 == 0 )

/*== Structures et unions ============================================*/

struct MCB
      {                              /* D‚crit un bloc MCB en m‚moire */
        BYTE id_code; /* 'M' = il existe un bloc qui suit , 'Z' = Fin */
        WORD psp;                           /* Segment du PSP associ‚ */
        WORD distance;              /* Nombre de paragraphes r‚serv‚s */
      };

typedef struct MCB far *MCBPtr;            /* Pointeur FAR sur un MCB */

/*== Macros ==========================================================*/

#ifdef MK_FP                                   /* MK_FP d‚j… d‚fini ? */
  #undef MK_FP
#endif

#define MK_FP(s, o) ((void far *) (((unsigned long) (s)<<16)|(o)))

/***********************************************************************
*  Fonction         : F I R S T _ M C B                                *
**--------------------------------------------------------------------**
*                     Retourne un pointeur sur le premier MCB.         *
*  Entr‚e : n‚ant                                                      *
*  Sortie : Pointeur sur le premier MCB                                *
***********************************************************************/

MCBPtr first_mcb( void )
{
  union REGS   regs;        /* Registres pour g‚rer les interruptions */
  struct SREGS sregs;            /* M‚morise les registres de segment */

 regs.h.ah = 0x52;     /* Fonction: "Lire l'adresse du DOS-Info-Bloc" */
 intdosx( &regs, &regs, &sregs );            /* interruption DOS 0x21 */

    /*-- ES:(BX-4) pointe sur le premier MCB, forme le pointeur ------*/

 return( *((MCBPtr far *) MK_FP( sregs.es-1, regs.x.bx+11 )) );
}

/***********************************************************************
*  Foction          : D U M P                                          *
**--------------------------------------------------------------------**
*               Affiche le dump hexa et ASCII d'une zone de m‚moire    *
*  Entr‚es : BPTR = Pointeur sur la zone de m‚moire                    *
*            Nbr  = Nombre de lignes du dump (par 16 octets)           *
*  Valeur de retour : n‚ant                                            *
***********************************************************************/

void dump( FB bptr, BYTE nbr)
{
  FB    lptr;                   /* Pointeur courant sur ligne de dump */
  WORD  offset;                          /* Offset par rapport … BPTR */
  BYTE  i;                                                /* Compteur */

 printf("\nDUMP ³ 0123456789ABCDEF        00 01 02 03 04 05 06 07 08");
 printf(" 09 0A 0B 0C 0D 0E 0F\n");
 printf("ÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ");
 printf("ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ\n");

 for (offset=0;  nbr-- ; offset += 16, bptr += 16)
 {                                     /* Parcourt la boucle NBR fois */
   printf("%04x ³ ", offset);
   for (lptr=bptr, i=16; i-- ; ++lptr)     /* Affiche caractŠre ASCII */
     printf("%c", (*lptr<32) ? ' ' : *lptr);
   printf("        ");
   for (lptr=bptr, i=16; i-- ; )           /* Affiche ‚quivalent hexa */
     printf("%02X ", *lptr++);
   printf("\n");                         /* Passe … la ligne suivante */
 }
}

/***********************************************************************
*  Fonction         : T R A C E _ M C B                                *
**--------------------------------------------------------------------**
*                     Suit la chaŒne des blocs MCB.                    *
*  Entr‚e : n‚ant                                                      *
*  Valeur de retour : n‚ant                                            *
***********************************************************************/

void trace_mcb( void )
{
 static char fenv[] =
             {                     /* PremiŠre chaŒne d'environnement */
               'C', 'O', 'M', 'S', 'P', 'E', 'C', '='
             };

 MCBPtr   act_mcb;                         /* Pointeur sur MCB actuel */
 BOOLEAN  fin;                   /* TRUE si le dernier MCB est trouv‚ */
 BYTE     nr_mcb,                /* Num‚ro du MCB pr‚sentement trait‚ */
          i;                                              /* Compteur */
 FB       lptr;                       /* Pointeur sur l'environnement */

 fin     = FALSE;                                          /* On y va */
 nr_mcb  = 1;                     /* Le premier MCB porte le num‚ro 1 */
 act_mcb = first_mcb();     /* Cherche un pointeur sur le premier MCB */

 do                                      /* Traite les diff‚rents MCB */
 {
   if( act_mcb->id_code == 'Z' )             /* Dernier MCB atteint ? */
     fin = TRUE;                                               /* Oui */
   printf("Num‚ro du MCB = %d\n", nr_mcb++);
   printf("Adresse du MCB= %Fp\n", act_mcb);
   printf("Adr. M‚moire  = %Np:0000\n", FP_SEG(act_mcb)+1);
   printf("ID            = %c\n", act_mcb->id_code);
   printf("Adresse du PSP= %Fp\n", (FB) MK_FP(act_mcb->psp, 0) );
   printf("Taille        = %u paragraphes ( %lu octets)\n",
          act_mcb->distance, (unsigned long) act_mcb->distance << 4);
   printf("Contenu       = ");

                /*-- Est-ce un environnement ?------------------------*/

   for (i=0, lptr=(FB)act_mcb+16;   /* Compare premiŠre chaŒne … FENV */
        ( i<sizeof fenv ) && ( *(lptr++) == fenv[i++] ) ; );

   if( i == sizeof fenv )                       /* ChaŒne d‚tect‚e  ? */
   {                             /* Oui, il s'agit d'un environnement */
     printf("Environnement\n");
     if( _osmajor >= 3 )        /* Version 3.0 de DOS ou ult‚rieure ? */
     {                              /* Oui, donne le nom du programme */
       printf("Nom du progr = ");
       for( ; !(*(lptr++)==0 && *lptr==0) ; );
                            /* Cherche la derniŠre chaŒne de l'envir. */
       if( *(int far *)(lptr + 1) == 1 )
                                         /* Voici un nom de programme */
         for( lptr += 3; *lptr ; )                  /* On le parcourt */
           printf( "%c", *(lptr++) );  /* car. par car. pour afficher */
       else                               /* Pas de programme d‚tect‚ */
           printf("inconnu  ");
       printf("\n");                     /* Passe … la ligne suivante */
     }

    /*-- Affiche les chaŒnes de l'environnement ----------------------*/

     printf("ChaŒnes de l'environnement\n");
     for (lptr=(FB) act_mcb +16; *lptr ; ++lptr)
     {                                          /* Affiche une chaŒne */
       printf("           ");
       for( ; *lptr ; )  /* Parcourt la chaŒne jusqu'au caractŠre NUL */
         printf( "%c", *(lptr++) );  /* Affiche un caractŠre … la fois*/
       printf("\n");                     /* Passe … la ligne suivante */
     }
   }
   else                                        /* Pas d'environnement */
   {

     /*-- S'agit-il d'un PSP? ----------------------------------------*/
     /*-- (introduit par la commande INT 20 (Code=0xCD 0x20) ) -------*/

     if (*((unsigned far *) MK_FP( act_mcb->psp, 0 )) == 0x20cd)
       printf("PSP (suivi d'un programme)\n");                 /* Oui */
     else            /* La commande INT 0x20 n'a pas pu ˆtre d‚tect‚e */
     {
       printf("non identifiable (Programme ou donn‚es)\n");
       dump( (FB) act_mcb + 16, 5);  /* dump des 5*16 premiers octets */
     }
   }

   printf("ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ");
   printf("ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ Appuyez sur une toucheÍ\n");
   if( !fin )                                          /* Autre MCB ? */
   {                                  /* Oui, fixe un pointeur dessus */
     act_mcb = (MCBPtr)
                MK_FP( FP_SEG(act_mcb) + act_mcb->distance + 1, 0 );
     getch();                          /* Attend une frappe de touche */
   }
 }
 while( !fin );                        /* R‚pŠte jusqu'au dernier MCB */
}

/***********************************************************************
**                           PROGRAMME PRINCIPAL                      **
***********************************************************************/

void main( void )
{
 printf("\nMCBC (c) 1988, 92 by Michael TISCHER\n\n");
 trace_mcb();                           /* Parcourt la chaŒne des MCB */
}
